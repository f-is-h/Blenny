#if BLENNY_PRODUCT || DEBUG
#import "BlennyPrivateABIShim.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <string.h>

@interface NSUserDefaults (BlennyOrderingContainer)
- (instancetype)_initWithSuiteName:(NSString *)name container:(NSURL *)container;
@end

static NSString *const BlennyOrderingErrorDomain = @"xyz.fi5h.blenny.ordering-private-abi";
static NSString *const BlennyOrderingSuite = @"com.apple.MenuBar";
static NSString *const BlennyOrderingTableKey = @"TrailingItemPreferredPositions";

bool blenny_menu_bar_ordering_supports_system_version(CFStringRef version) {
    if (version == NULL) return false;
    NSString *value = (__bridge NSString *)version;
    NSString *major = [value componentsSeparatedByString:@"."].firstObject;
    if (major.length == 0
        || [major rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location
            != NSNotFound) {
        return false;
    }
    return major.integerValue == 27;
}

static bool BlennyOrderingReject(
    NSInteger code,
    NSString *description,
    CFErrorRef _Nullable * _Nullable errorOut
) {
    if (errorOut != NULL) {
        NSError *error = [NSError errorWithDomain:BlennyOrderingErrorDomain
                                             code:code
                                         userInfo:@{NSLocalizedDescriptionKey: description}];
        *errorOut = (__bridge_retained CFErrorRef)error;
    }
    return false;
}

bool blenny_write_menu_bar_ordering_table(
    CFDictionaryRef table,
    CFStringRef containerPath,
    CFErrorRef _Nullable * _Nullable errorOut
) {
    @autoreleasepool {
        if (errorOut != NULL) *errorOut = NULL;
        @try {
#if !defined(__arm64__)
            return BlennyOrderingReject(1, @"Architecture differs", errorOut);
#endif
            NSDictionary *version = [NSDictionary dictionaryWithContentsOfFile:
                @"/System/Library/CoreServices/SystemVersion.plist"];
            if (!blenny_menu_bar_ordering_supports_system_version(
                    (__bridge CFStringRef)version[@"ProductVersion"])) {
                return BlennyOrderingReject(2, @"OS major version differs", errorOut);
            }
            SEL selector = @selector(_initWithSuiteName:container:);
            Method method = class_getInstanceMethod(NSUserDefaults.class, selector);
            const char *encoding = method == NULL ? NULL : method_getTypeEncoding(method);
            if (encoding == NULL || strcmp(encoding, "@32@0:8@16@24") != 0) {
                return BlennyOrderingReject(3, @"Container initializer contract differs", errorOut);
            }
            if (table == NULL || containerPath == NULL
                || CFDictionaryGetCount(table) <= 0 || CFDictionaryGetCount(table) > 256
                || !CFPropertyListIsValid(table, kCFPropertyListBinaryFormat_v1_0)) {
                return BlennyOrderingReject(4, @"Ordering table is not a property list", errorOut);
            }
            NSDictionary *positions = (__bridge NSDictionary *)table;
            NSURL *container = [NSURL fileURLWithPath:(__bridge NSString *)containerPath
                                          isDirectory:YES];
            NSUserDefaults *defaults = [[NSUserDefaults alloc]
                _initWithSuiteName:BlennyOrderingSuite container:container];
            if (defaults == nil) {
                return BlennyOrderingReject(5, @"Container initialization failed", errorOut);
            }
            [defaults setObject:positions forKey:BlennyOrderingTableKey];
            if (![defaults synchronize]) {
                return BlennyOrderingReject(6, @"Container synchronization failed", errorOut);
            }
            return true;
        } @catch (NSException *exception) {
            NSString *description = exception.reason ?: @"Private defaults operation raised an exception";
            return BlennyOrderingReject(7, description, errorOut);
        }
    }
}
#endif
