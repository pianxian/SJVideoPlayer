//
//  HLSContentProvider.m
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/11/25.
//

#import "HLSContentProvider.h"
#import "MCSConsts.h"
#import "NSFileManager+MCS.h"

#define HLS_PREFIX_FILENAME   @"hls"
#define HLS_PREFIX_FILENAME1  HLS_PREFIX_FILENAME
#define HLS_PREFIX_FILENAME2 @"hlsr"

@implementation HLSContentProvider {
    NSString *_directory;
}

- (instancetype)initWithDirectory:(NSString *)directory {
    self = [super init];
    if ( self ) {
        _directory = directory;
        if ( ![NSFileManager.defaultManager fileExistsAtPath:_directory] ) {
            [NSFileManager.defaultManager createDirectoryAtPath:_directory withIntermediateDirectories:YES attributes:nil error:NULL];
        }
    }
    return self;
}

- (NSString *)indexFilePath {
    return [_directory stringByAppendingPathComponent:[NSString stringWithFormat:@"index%@", HLS_SUFFIX_INDEX]];
}

- (NSString *)AESKeyFilePathWithName:(NSString *)AESKeyName {
    return [_directory stringByAppendingPathComponent:AESKeyName];
}

- (nullable NSArray<HLSContentTs *> *)TsContents {
    NSMutableArray<HLSContentTs *> *m = nil;
    for ( NSString *filename in [NSFileManager.defaultManager contentsOfDirectoryAtPath:_directory error:NULL] ) {
        if ( ![filename hasPrefix:HLS_PREFIX_FILENAME] )
            continue;
        if ( m == nil )
            m = NSMutableArray.array;
        NSString *filePath = [self TsContentFilePathForFilename:filename];
        NSString *name = [self _TsNameForFilename:filename];
        HLSContentTs *ts = nil;
        long long totalLength = [self _TsTotalLengthForFilename:filename];
        if      ( [filename hasPrefix:HLS_PREFIX_FILENAME2] ) {
            long long length = (long long)[NSFileManager.defaultManager mcs_fileSizeAtPath:filePath];
            NSRange range = [self _TsRangeForFilename:filename];
            ts = [HLSContentTs TsWithName:name filename:filename totalLength:totalLength inRange:range length:length];
        }
        else if ( [filename hasPrefix:HLS_PREFIX_FILENAME1] ) {
            long long length = (long long)[NSFileManager.defaultManager mcs_fileSizeAtPath:filePath];
            ts = [HLSContentTs.alloc initWithName:name filename:filename totalLength:totalLength length:length];
        }
        
        if ( ts != nil )
            [m addObject:ts];
    }
    return m;
}

- (nullable HLSContentTs *)createTsContentWithName:(NSString *)name totalLength:(NSUInteger)totalLength {
    NSUInteger number = 0;
    do {
        NSString *filename = [self _TsFilenameWithName:name totalLength:totalLength number:number];
        NSString *filePath = [self TsContentFilePathForFilename:filename];
        if ( ![NSFileManager.defaultManager fileExistsAtPath:filePath] ) {
            [NSFileManager.defaultManager createFileAtPath:filePath contents:nil attributes:nil];
            return [HLSContentTs.alloc initWithName:name filename:filename totalLength:totalLength];
        }
        number += 1;
    } while (true);
    return nil;
}

/// #EXTINF:3.951478,
/// #EXT-X-BYTERANGE:1544984@1007868
///
/// range
- (nullable HLSContentTs *)createTsContentWithName:(NSString *)name totalLength:(NSUInteger)totalLength inRange:(NSRange)range {
    NSUInteger number = 0;
    do {
        NSString *filename = [self _TsFilenameWithName:name totalLength:totalLength inRange:range number:number];
        NSString *filePath = [self TsContentFilePathForFilename:filename];
        if ( ![NSFileManager.defaultManager fileExistsAtPath:filePath] ) {
            [NSFileManager.defaultManager createFileAtPath:filePath contents:nil attributes:nil];
            return [HLSContentTs TsWithName:name filename:filename totalLength:totalLength inRange:range];
        }
        number += 1;
    } while (true);
    return nil;
}

- (nullable NSString *)TsContentFilePathForFilename:(NSString *)filename {
    return [_directory stringByAppendingPathComponent:filename];
}

- (void)removeTsContentForFilename:(NSString *)filename {
    NSString *filePath = [self TsContentFilePathForFilename:filename];
    [NSFileManager.defaultManager removeItemAtPath:filePath error:NULL];
}

#pragma mark - mark

- (NSString *)_TsFilenameWithName:(NSString *)name totalLength:(long long)totalLength number:(NSInteger)number {
    // _FILE_NAME1(__prefix__, __totalLength__, __number__, __TsName__)
    return [NSString stringWithFormat:@"%@_%lld_%ld_%@", HLS_PREFIX_FILENAME1, totalLength, (long)number, name];
}

- (NSString *)_TsFilenameWithName:(NSString *)name totalLength:(long long)totalLength inRange:(NSRange)range number:(NSInteger)number {
    // _FILE_NAME2(__prefix__, __totalLength__, __offset__, __number__, __TsName__)
    return [NSString stringWithFormat:@"%@_%lld_%lu_%lu_%ld_%@", HLS_PREFIX_FILENAME2, totalLength, (unsigned long)range.location, (unsigned long)range.length, (long)number, name];
}

#pragma mark -

- (NSString *)_TsNameForFilename:(NSString *)filename {
    return [filename componentsSeparatedByString:@"_"].lastObject;
}

- (long long)_TsTotalLengthForFilename:(NSString *)filename {
    return [[filename componentsSeparatedByString:@"_"][1] longLongValue];;
}

- (NSRange)_TsRangeForFilename:(NSString *)filename {
    NSArray<NSString *> *contents = [filename componentsSeparatedByString:@"_"];
    return NSMakeRange(contents[2].longLongValue, contents[3].longLongValue);
}
@end
