//
//  CCouchDBChangeSet.h
//  trundle
//
//  Created by Jonathan Wight on 11/03/10.
//  Copyright 2010 toxicsoftware.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CCouchDBDatabase;

@interface CCouchDBChangeSet : NSObject {
}

@property (readonly, nonatomic, weak) CCouchDBDatabase *database;
@property (readonly, nonatomic, assign) NSInteger lastSequence;
@property (readonly, nonatomic, retain) NSSet *changedDocuments;
@property (readonly, nonatomic, retain) NSSet *changedDocumentIdentifiers;
@property (readonly, nonatomic, retain) NSSet *deletedDocumentsIdentifiers;

- (id)initWithDatabase:(CCouchDBDatabase *)inDatabase JSON:(id)inJSON;

@end
