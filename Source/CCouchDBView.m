//
//  CCouchDBView.m
//  trundle
//
//  Created by Marty Schoch on 6/18/11.
//  Copyright 2011 Marty Schoch. All rights reserved.
//

#import "CCouchDBView.h"


@implementation CCouchDBView

@synthesize totalRows;
@synthesize offset;
@synthesize rows;

-(void)dealloc {
    [rows release];
    rows = NULL;
    [super dealloc];
}

- (NSString *)description
{
    return([NSString stringWithFormat:@"%@ (totalRows:%d offset:%d rows:%@ )", [super description], self.totalRows, self.offset, self.rows]);
}

@end
