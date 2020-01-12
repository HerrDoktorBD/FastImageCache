//
//  FICUtilities.m
//  FastImageCache
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICUtilities.h"

#import <CommonCrypto/CommonDigest.h>

#pragma mark Internal Definitions

// Core Animation will make a copy of any image that a client application provides whose backing store isn't properly byte-aligned.
// This copy operation can be prohibitively expensive, so we want to avoid this by properly aligning any UIImages we're working with.
// To produce a UIImage that is properly aligned, we need to ensure that the backing store's bytes per row is a multiple of 64.

#pragma mark - Byte Alignment

inline size_t FICByteAlign(size_t width, size_t alignment) {
    return ((width + (alignment - 1)) / alignment) * alignment;
}

inline size_t FICByteAlignForCoreAnimation(size_t bytesPerRow) {
    return FICByteAlign(bytesPerRow, 64);
}

#pragma mark - Strings and UUIDs

NSString * FICStringWithUUIDBytes(CFUUIDBytes UUIDBytes) {
    NSString *UUIDString = nil;
    CFUUIDRef UUIDRef = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault, UUIDBytes);

    if (UUIDRef != NULL) {
        UUIDString = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, UUIDRef);
        CFRelease(UUIDRef);
    }

    return UUIDString;
}

CFUUIDBytes FICUUIDBytesWithString(NSString* string) {
    CFUUIDBytes UUIDBytes = {};
    CFUUIDRef UUIDRef = CFUUIDCreateFromString(kCFAllocatorDefault, (CFStringRef)string);

    if (UUIDRef != NULL) {
        UUIDBytes = CFUUIDGetUUIDBytes(UUIDRef);
        CFRelease(UUIDRef);
    }

    return UUIDBytes;
}

NSString* FICCFUUIDCreate(void) {
    CFUUIDRef cfuuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString* _UUID = (NSString*)CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, cfuuid));
    return _UUID;
}

/*
NSString* FICUUIDFromMD5HashOfString(NSString* md5Hash) {
    const char *UTF8String = [md5Hash UTF8String];
    CFUUIDBytes UUIDBytes;

    CC_MD5(UTF8String, (CC_LONG)strlen(UTF8String), (unsigned char*)&UUIDBytes);

    NSString* _UUID = FICStringWithUUIDBytes(UUIDBytes);
    return _UUID;
}

NSString* FICUUIDFromSHA256HashOfString(NSString* sha256Hash) {
    NSData* data = [sha256Hash dataUsingEncoding: NSUTF8StringEncoding];
    NSMutableData* sha256Data = [NSMutableData dataWithLength: CC_SHA256_DIGEST_LENGTH];

    CC_SHA256([data bytes], (CC_LONG)[data length], [sha256Data mutableBytes]);

    NSString* _UUID = [sha256Data base64EncodedStringWithOptions: 0];
    return _UUID;
}
*/
