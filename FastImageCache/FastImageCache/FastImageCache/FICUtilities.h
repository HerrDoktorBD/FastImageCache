//
//  FICUtilities.h
//  FastImageCache
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICImports.h"

NS_ASSUME_NONNULL_BEGIN

size_t FICByteAlign(size_t bytesPerRow, size_t alignment);
size_t FICByteAlignForCoreAnimation(size_t bytesPerRow);

NSString * _Nullable FICStringWithUUIDBytes(CFUUIDBytes UUIDBytes);
CFUUIDBytes FICUUIDBytesWithString(NSString* _Nonnull string);

NSString* FICUUIDFromMD5HashOfString(NSString* _Nonnull string);
CFUUIDBytes FICUUIDBytesFromMD5HashOfString(NSString* _Nonnull string); // Useful for computing an entity's UUID from a URL, for example

NSString* FICUUIDFromSHA256HashOfString(NSString* _Nonnull string);

NS_ASSUME_NONNULL_END
