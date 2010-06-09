//
//  CCouchDBDatabase.m
//  CouchTest
//
//  Created by Jonathan Wight on 02/16/10.
//  Copyright 2010 toxicsoftware.com. All rights reserved.
//

#import "CCouchDBDatabase.h"

#import "CCouchDBServer.h"
#import "CJSONDataSerializer.h"
#import "CouchDBClientConstants.h"
#import "CCouchDBDocument.h"
#import "CCouchDBURLOperation.h"

@implementation CCouchDBDatabase

@synthesize server;
@synthesize name;
@synthesize cachedDocuments;

- (id)initWithServer:(CCouchDBServer *)inServer name:(NSString *)inName
{
if ((self = [self init]) != NULL)
	{
	server = inServer;
	name = [inName copy];
	}
return(self);
}

- (void)dealloc
{
#warning TODO
//
[super dealloc];
}

- (NSString *)description
{
return([NSString stringWithFormat:@"%@ (%@)", [super description], self.name]);
}

#pragma mark -

- (NSString *)encodedName
{
@synchronized(self)
	{
	if (encodedName == NULL)
		{
		encodedName = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)self.name, NULL, CFSTR("/"), kCFStringEncodingUTF8);
		}
	return([[encodedName retain] autorelease]);
	}
}

- (NSURL *)URL
{
@synchronized(self)
	{
	if (URL == NULL)
		{
		URL = [[NSURL URLWithString:[NSString stringWithFormat:@"%@/", self.encodedName] relativeToURL:self.server.URL] retain];
		}
	return([[URL retain] autorelease]);
	}
}

- (NSCache *)cachedDocuments
{
@synchronized(self)
	{
	if (cachedDocuments == NULL)
		{
		cachedDocuments = [[NSCache alloc] init];
		}
	return([[cachedDocuments retain] autorelease]);
	}
}

#pragma mark -

- (void)createDocument:(NSDictionary *)inDocument successHandler:(CouchDBSuccessHandler)inSuccessHandler failureHandler:(CouchDBFailureHandler)inFailureHandler
{
NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:self.URL];
theRequest.HTTPMethod = @"POST";

NSData *theData = [[CJSONDataSerializer serializer] serializeDictionary:inDocument];
[theRequest setValue:kContentTypeJSON forHTTPHeaderField:@"Content-Type"];
[theRequest setHTTPBody:theData];

CCouchDBURLOperation *theOperation = [[[CCouchDBURLOperation alloc] initWithRequest:theRequest] autorelease];
theOperation.completionBlock = ^(void) {
	if (theOperation.error)
		{
		if (inFailureHandler)
			inFailureHandler(theOperation.error);
		return;
		}
	
	if ([[theOperation.JSON objectForKey:@"ok"] boolValue] == NO)
		{
		NSError *theError = [NSError errorWithDomain:kCouchErrorDomain code:-3 userInfo:NULL];
		if (inFailureHandler)
			inFailureHandler(theError);
		return;
		}
		
	NSString *theIdentifier = [theOperation.JSON objectForKey:@"id"];
	NSString *theRevision = [theOperation.JSON objectForKey:@"rev"];
	
	CCouchDBDocument *theDocument = [[[CCouchDBDocument alloc] initWithDatabase:self identifier:theIdentifier revision:theRevision] autorelease];
	[theDocument populateWithJSONDictionary:inDocument];
	[self.cachedDocuments setObject:theDocument forKey:theIdentifier];

	if (inSuccessHandler)
		inSuccessHandler(theDocument);
	};

[self.server.operationQueue addOperation:theOperation];
}

- (void)createDocument:(NSDictionary *)inDocument identifier:(NSString *)inIdentifier successHandler:(CouchDBSuccessHandler)inSuccessHandler failureHandler:(CouchDBFailureHandler)inFailureHandler
{
NSURL *theURL = [NSURL URLWithString:inIdentifier relativeToURL:self.URL];
NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:theURL];
theRequest.HTTPMethod = @"PUT";
NSData *theData = [[CJSONDataSerializer serializer] serializeDictionary:inDocument];
[theRequest setValue:kContentTypeJSON forHTTPHeaderField:@"Content-Type"];
[theRequest setHTTPBody:theData];

CCouchDBURLOperation *theOperation = [[[CCouchDBURLOperation alloc] initWithRequest:theRequest] autorelease];
theOperation.completionBlock = ^(void) {
	if (theOperation.error)
		{
		if (inFailureHandler)
			inFailureHandler(theOperation.error);
		return;
		}
	
	if ([[theOperation.JSON objectForKey:@"ok"] boolValue] == NO)
		{
		NSError *theError = [NSError errorWithDomain:kCouchErrorDomain code:-3 userInfo:NULL];
		if (inFailureHandler)
			inFailureHandler(theError);
		return;
		}

	NSString *theRevision = [theOperation.JSON objectForKey:@"rev"];
	
	CCouchDBDocument *theDocument = [[[CCouchDBDocument alloc] initWithDatabase:self identifier:inIdentifier revision:theRevision] autorelease];
	[theDocument populateWithJSONDictionary:inDocument];
	[self.cachedDocuments setObject:theDocument forKey:inIdentifier];

	if (inSuccessHandler)
		inSuccessHandler(theDocument);
	};

[self.server.operationQueue addOperation:theOperation];
}

- (void)fetchAllDocumentsWithSuccessHandler:(CouchDBSuccessHandler)inSuccessHandler failureHandler:(CouchDBFailureHandler)inFailureHandler
{
NSURL *theURL = [NSURL URLWithString:@"_all_docs" relativeToURL:self.URL];
NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:theURL];
theRequest.HTTPMethod = @"GET";
CCouchDBURLOperation *theOperation = [[[CCouchDBURLOperation alloc] initWithRequest:theRequest] autorelease];
theOperation.completionBlock = ^(void) {
	if (theOperation.error)
		{
		if (inFailureHandler)
			inFailureHandler(theOperation.error);
		return;
		}
		
	NSMutableArray *theDocuments = [NSMutableArray array];
	for (NSDictionary *theRow in [theOperation.JSON objectForKey:@"rows"])
		{
		NSString *theIdentifier = [theRow objectForKey:@"id"];
		
		CCouchDBDocument *theDocument = [self.cachedDocuments objectForKey:theIdentifier];
		if (theDocument == NULL)
			{
			theDocument = [[[CCouchDBDocument alloc] initWithDatabase:self identifier:theIdentifier] autorelease];
			[self.cachedDocuments setObject:theDocument forKey:theIdentifier];
			}

		theDocument.revision = [theRow valueForKeyPath:@"value.rev"];
			
		[theDocuments addObject:theDocument];
		}

	if (inSuccessHandler)
		inSuccessHandler(theDocuments);
	};

[self.server.operationQueue addOperation:theOperation];
}

- (void)fetchDocumentForIdentifier:(NSString *)inIdentifier successHandler:(CouchDBSuccessHandler)inSuccessHandler failureHandler:(CouchDBFailureHandler)inFailureHandler;
{
NSURL *theURL = [NSURL URLWithString:inIdentifier relativeToURL:self.URL];
NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:theURL];
theRequest.HTTPMethod = @"GET";
CCouchDBURLOperation *theOperation = [[[CCouchDBURLOperation alloc] initWithRequest:theRequest] autorelease];
theOperation.completionBlock = ^(void) {
	if (theOperation.error)
		{
		if (inFailureHandler)
			inFailureHandler(theOperation.error);
		return;
		}
	
	CCouchDBDocument *theDocument = [self.cachedDocuments objectForKey:inIdentifier];
	if (theDocument == NULL)
		{
		theDocument = [[[CCouchDBDocument alloc] initWithDatabase:self] autorelease];
		[self.cachedDocuments setObject:theDocument forKey:inIdentifier];
		}
	
	[theDocument populateWithJSONDictionary:theOperation.JSON];

	if (inSuccessHandler)
		inSuccessHandler(theDocument);
	};

[self.server.operationQueue addOperation:theOperation];
}

- (void)fetchDocument:(CCouchDBDocument *)inDocument successHandler:(CouchDBSuccessHandler)inSuccessHandler failureHandler:(CouchDBFailureHandler)inFailureHandler;
{
#warning TODO -- this only fetches the latest document (i.e. _rev is ignored). What if we don't want the latest document?
NSURL *theURL = inDocument.URL;
NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:theURL];
theRequest.HTTPMethod = @"GET";
CCouchDBURLOperation *theOperation = [[[CCouchDBURLOperation alloc] initWithRequest:theRequest] autorelease];
theOperation.completionBlock = ^(void) {
	if (theOperation.error)
		{
		if (inFailureHandler)
			inFailureHandler(theOperation.error);
		return;
		}
		
	[inDocument populateWithJSONDictionary:theOperation.JSON];

	if (inSuccessHandler)
		inSuccessHandler(inDocument);
	};

[self.server.operationQueue addOperation:theOperation];
}

- (void)updateDocument:(CCouchDBDocument *)inDocument successHandler:(CouchDBSuccessHandler)inSuccessHandler failureHandler:(CouchDBFailureHandler)inFailureHandler
{
NSURL *theURL = inDocument.URL;
NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:theURL];
theRequest.HTTPMethod = @"PUT";
NSData *theData = [[CJSONDataSerializer serializer] serializeDictionary:inDocument.content];
[theRequest setValue:kContentTypeJSON forHTTPHeaderField:@"Content-Type"];
[theRequest setHTTPBody:theData];

CCouchDBURLOperation *theOperation = [[[CCouchDBURLOperation alloc] initWithRequest:theRequest] autorelease];
theOperation.completionBlock = ^(void) {
	if (theOperation.error)
		{
		if (inFailureHandler)
			inFailureHandler(theOperation.error);
		return;
		}
	
	[inDocument populateWithJSONDictionary:theOperation.JSON];

	if (inSuccessHandler)
		inSuccessHandler(inDocument);
	};

[self.server.operationQueue addOperation:theOperation];
}

- (void)deleteDocument:(CCouchDBDocument *)inDocument successHandler:(CouchDBSuccessHandler)inSuccessHandler failureHandler:(CouchDBFailureHandler)inFailureHandler
{
NSURL *theURL = [NSURL URLWithString:[NSString stringWithFormat:@"?rev=%@", inDocument.revision] relativeToURL:inDocument.URL];
NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:theURL];
theRequest.HTTPMethod = @"DELETE";

CCouchDBURLOperation *theOperation = [[[CCouchDBURLOperation alloc] initWithRequest:theRequest] autorelease];
theOperation.completionBlock = ^(void) {
	if (theOperation.error)
		{
		if (inFailureHandler)
			inFailureHandler(theOperation.error);
		return;
		}
		
	[self.cachedDocuments removeObjectForKey:inDocument];
	
	if (inSuccessHandler)
		inSuccessHandler(inDocument);
	};

[self.server.operationQueue addOperation:theOperation];
}

@end