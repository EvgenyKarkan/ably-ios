//
//  ARTFallbackTest.m
//  ably
//
//  Created by vic on 19/06/2015.
//  Copyright (c) 2015 Ably. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ARTFallback.h"
#import "ARTDefault.h"
@interface ARTFallbackTest : XCTestCase
@end

@implementation ARTFallbackTest

- (void)testAllHostsIncludedOnce {
    ARTFallback *f = [[ARTFallback alloc] init];
    NSArray *defaultHosts = [ARTDefault fallbackHosts];
    NSSet *defaultSet = [NSSet setWithArray:defaultHosts];
    NSMutableArray *hostsRandomised = [NSMutableArray array];
    for(int i=0;i < [defaultHosts count]; i++) {
        [hostsRandomised addObject:[f popFallbackHost]];
    }
    //popping after all hosts are exhausted returns nil
    XCTAssertTrue([f popFallbackHost] == nil);
    
    // all fallback hosts are used in artfallback
    XCTAssertEqual([hostsRandomised count], [defaultHosts count]);
    bool inOrder = true;
    for(int i=0;i < [defaultHosts count]; i++) {
        if(![[defaultHosts objectAtIndex:i] isEqualToString:[hostsRandomised objectAtIndex:i]]) {
            inOrder = false;
            break;
        }
    }
    //check artfallback randomises the order.
    XCTAssertFalse(inOrder);
    
    //every member of fallbacks hosts are in the list of default hosts
    for(int i=0;i < [hostsRandomised count]; i++) {
        XCTAssertTrue([defaultSet containsObject:[hostsRandomised objectAtIndex:i]]);
    }    
}

@end
