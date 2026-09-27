// Unsupported, read-only macOS 27 research. No assertion or mutation is created.
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Security/Security.h>

static id attribute(AXUIElementRef item, CFStringRef name) {
    CFTypeRef value = NULL;
    AXError error = AXUIElementCopyAttributeValue(item, name, &value);
    if (error != kAXErrorSuccess) return @{ @"error": @(error) };
    return CFBridgingRelease(value) ?: NSNull.null;
}

static NSDictionary *signature(pid_t pid) {
    SecCodeRef code = NULL;
    NSDictionary *attributes = @{ (__bridge NSString *)kSecGuestAttributePid: @(pid) };
    OSStatus lookup = SecCodeCopyGuestWithAttributes(NULL,
        (__bridge CFDictionaryRef)attributes, kSecCSDefaultFlags, &code);
    if (lookup != errSecSuccess) return @{ @"lookupError": @(lookup) };
    OSStatus validity = SecCodeCheckValidity(code, kSecCSStrictValidate, NULL);
    CFDictionaryRef information = NULL;
    OSStatus read = SecCodeCopySigningInformation(code, kSecCSSigningInformation, &information);
    NSDictionary *info = CFBridgingRelease(information);
    id identifier = info[(__bridge NSString *)kSecCodeInfoIdentifier] ?: NSNull.null;
    CFRelease(code);
    return @{ @"validity": @(validity), @"readError": @(read), @"identifier": identifier };
}

int main(void) {
    @autoreleasepool {
        fprintf(stderr, "Unsupported read-only probe; AX observations do not prove physical visibility.\n");
        if (NSProcessInfo.processInfo.operatingSystemVersion.majorVersion != 27) return 2;
        BOOL trusted = AXIsProcessTrusted(); // Never prompt or alter TCC.
        NSMutableArray *results = NSMutableArray.array;
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
        NSArray<NSRunningApplication *> *apps = NSWorkspace.sharedWorkspace.runningApplications;
        for (NSRunningApplication *app in apps) {
            NSString *path = app.executableURL.path;
            NSString *leaf = path.lastPathComponent.lowercaseString;
            BOOL game = [path isEqualToString:@"/usr/libexec/GamePolicyAgent"];
            BOOL wine = [@[@"wine", @"wine64", @"wine-preloader", @"wine64-preloader"] containsObject:leaf];
            if (!game && !wine) continue;
            if (results.count >= 16 || deadline.timeIntervalSinceNow <= 0) break;
            NSDictionary *code = signature(app.processIdentifier);
            NSMutableDictionary *row = [@{
                @"host": game ? @"GamePolicyAgent" : @"Wine candidate",
                @"pid": @(app.processIdentifier), @"executableName": leaf ?: @"",
                @"bundleIdentifier": app.bundleIdentifier ?: (id)NSNull.null,
                @"activationPolicy": @(app.activationPolicy), @"signature": code,
                @"launchDate": app.launchDate.description ?: @"unavailable"
            } mutableCopy];
            [results addObject:row];
            NSString *expected = game ? @"com.apple.GamePolicyAgent" : @"com.codeweavers.CrossOver.wineloader";
            if (!trusted || ![code[@"identifier"] isEqual:expected] ||
                [code[@"validity"] integerValue] != errSecSuccess) {
                row[@"axSkipped"] = @YES;
                continue;
            }
            AXUIElementRef element = AXUIElementCreateApplication(app.processIdentifier);
            AXUIElementSetMessagingTimeout(element, 0.2);
            id root = attribute(element, CFSTR("AXExtrasMenuBar"));
            NSMutableArray *items = NSMutableArray.array;
            if (CFGetTypeID((__bridge CFTypeRef)root) == AXUIElementGetTypeID()) {
                id children = attribute((__bridge AXUIElementRef)root, kAXChildrenAttribute);
                if ([children isKindOfClass:NSArray.class]) {
                    for (id child in children) {
                        if (items.count >= 8 || deadline.timeIntervalSinceNow <= 0) break;
                        if (CFGetTypeID((__bridge CFTypeRef)child) != AXUIElementGetTypeID()) {
                            row[@"unexpectedChildType"] = @YES;
                            break;
                        }
                        AXUIElementRef item = (__bridge AXUIElementRef)child;
                        NSMutableDictionary *detail = NSMutableDictionary.dictionary;
                        for (NSString *name in @[@"AXRole", @"AXSubrole", @"AXIdentifier", @"AXTitle", @"AXHelp"]) {
                            id value = attribute(item, (__bridge CFStringRef)name);
                            detail[name] = ([value isKindOfClass:NSString.class] ||
                                [value isKindOfClass:NSDictionary.class] || value == NSNull.null)
                                ? value : @{ @"unexpectedValueType": @YES };
                        }
                        for (NSString *name in @[@"AXHidden", @"AXVisible", @"AXPosition", @"AXSize"]) {
                            Boolean settable = false;
                            AXError error = AXUIElementIsAttributeSettable(item,
                                (__bridge CFStringRef)name, &settable);
                            detail[[name stringByAppendingString:@"Settable"]] =
                                @{ @"error": @(error), @"settable": @(settable) };
                        }
                        [items addObject:detail];
                    }
                    row[@"extrasScanTruncated"] = @(items.count < [children count]);
                } else row[@"childrenError"] = children;
            } else row[@"rootError"] = root;
            row[@"menuExtras"] = items;
            row[@"terminatedDuringRead"] = @(app.terminated);
            CFRelease(element);
        }
        NSDictionary *report = @{ @"os": NSProcessInfo.processInfo.operatingSystemVersionString,
            @"axTrusted": @(trusted), @"hosts": results,
            @"boundedScanStopped": @(deadline.timeIntervalSinceNow <= 0 || results.count >= 16),
            @"physicalVisibilityVerified": @NO };
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:report
            options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];
        if (!data) { fprintf(stderr, "%s\n", error.description.UTF8String); return 2; }
        fwrite(data.bytes, 1, data.length, stdout);
        puts("");
        return 0;
    }
}
