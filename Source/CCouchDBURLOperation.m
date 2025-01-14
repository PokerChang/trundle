//
//  CCouchDBURLOperation.m
//  trundle
//
//  Created by Jonathan Wight on 04/14/10.
//  Copyright 2010 toxicsoftware.com. All rights reserved.
//

#import "CCouchDBURLOperation.h"

#import "CJSONDeserializer.h"
#import "CouchDBClientConstants.h"
#import "NSError_CouchDBExtensions.h"
#import "CCouchDBSession.h"

@interface CCouchDBURLOperation ()
@property (readwrite, nonatomic, assign) CCouchDBSession *session;
@end

#pragma mark -

@implementation CCouchDBURLOperation

@synthesize session;
@synthesize successHandler;
@synthesize failureHandler;
@synthesize JSON;

- (id)initWithSession:(CCouchDBSession *)inSession request:(NSURLRequest *)inRequest
	{
	if ((self = [super initWithRequest:inRequest]) != NULL)
		{
		session = inSession;
		}
	return(self);
	}

- (void)dealloc
	{
	session = NULL;

	[successHandler release];
	successHandler = NULL;

	[failureHandler release];
	failureHandler = NULL;

	[JSON release];
	JSON = NULL;
	//
	[super dealloc];
	}

#pragma mark -

- (void)start
	{
	[super start];
	//
	}

- (void)didFinish
	{
	NSHTTPURLResponse *theHTTPResponse = (NSHTTPURLResponse *)self.response;

	NSError *theError = NULL;

	NSString *theContentType = [theHTTPResponse.allHeaderFields objectForKey:@"Content-Type"];
    NSInteger theStatusCode = theHTTPResponse.statusCode;

	if ([theContentType isEqualToString:kContentTypeJSON] == NO)
    {
        //don't check content type in order to fetch attachment
		//theError = [NSError errorWithDomain:kCouchErrorDomain code:CouchDBErrorCode_ContentTypeNotJSON userInfo:NULL];
        if (theStatusCode < 200 || theStatusCode >= 300)
        {
            theError = [NSError couchDBErrorWithURLResponse:self.response JSONDictionary:nil];
        }

        if (self.successHandler)
        {
            self.successHandler(self.data);
        }
        
        [super didFinish];
	}
    else{
        id theJSON = NULL;
        if (theError == NULL)
            {
            theJSON = [[self.session deserializer] deserialize:self.data error:&theError];
            if (theJSON == NULL || theStatusCode < 200 || theStatusCode >= 300)
                {
                theError = [NSError couchDBErrorWithURLResponse:self.response JSONDictionary:theJSON];
                }
            }

        if (theError != NULL)
            {
            [self didFailWithError:theError];
            }
        else
            {
            self.JSON = theJSON;
            
            if (self.successHandler)
                {
                self.successHandler(theJSON);
                }

            [super didFinish];
            }
        }
    }

- (void)didFailWithError:(NSError *)inError
    {
    id theJSON = [[CJSONDeserializer deserializer] deserialize:self.data error:NULL];
    NSError *theError = [NSError couchDBErrorWithError:inError JSONDictionary:theJSON];
    if (theError == NULL)
        {
        theError = inError;
        }

    if (self.failureHandler != NULL)
        {
        self.failureHandler(theError);
        }

    [super didFailWithError:inError];
    }

@end
