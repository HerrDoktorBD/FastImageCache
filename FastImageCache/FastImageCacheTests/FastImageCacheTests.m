//
//  FastImageCacheTests.m
//  FastImageCacheTests
//
//  Created by Rui Peres on 17/06/2015.
//  Copyright (c) 2015 Path. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import "FICUtilities.h"

#import <CommonCrypto/CommonDigest.h>

@interface FastImageCacheTests : XCTestCase

@end

@implementation FastImageCacheTests

- (void) setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void) tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void) testExample {
    // This is an example of a functional test case.
    XCTAssert(YES, @"Pass");
}

/*
- (void) testFICUUIDFromMD5HashOfString {

    NSString* imageName = @"dummy image name";
    NSString* _UUID = FICUUIDFromMD5HashOfString(imageName);
    XCTAssertEqualObjects(_UUID, @"E8E12683-09C1-3192-F85D-E3B30253C040");
}

- (void) testFICUUIDFromSha256HashOfString {

    NSString* imageName = @"dummy image name";
    NSString* _UUID = FICUUIDFromSHA256HashOfString(imageName);
    //XCTAssertEqualObjects(_UUID, @"AMdh9FrmgsQcrRMcJ9cBzgJAveg6/Ge26ckZ8ZgzxAQ=");
    XCTAssertEqualObjects(_UUID, @"AMdh9FrmgsQcrRMcJ9cBzg==");
}
*/
- (void) testCFUUIDCreate {

    for (int i = 0; i < 10; i++) {
        NSString* _UUID = FICCFUUIDCreate();
        NSLog(@"_UUID: %@", _UUID);
    }
}

@end
