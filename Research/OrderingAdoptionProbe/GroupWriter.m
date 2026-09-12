// Original unsupported research. Exact test keys only; excluded from product.
#if !DEBUG
#error DEBUG required
#endif
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sys/file.h>
#import <fcntl.h>
#import <unistd.h>
#import <sys/stat.h>

@interface NSUserDefaults (ResearchContainer)
- (instancetype)_initWithSuiteName:(NSString *)name container:(NSURL *)container;
@end

static NSString *const tableKey = @"TrailingItemPreferredPositions";
static NSArray *keys(void) {
    return @[@"status:OrderingAdoptionA::AdoptionProbeA", @"status:OrderingAdoptionB::AdoptionProbeB"];
}
static void require(BOOL condition, NSString *message) {
    if (!condition) @throw [NSException exceptionWithName:@"Rejected" reason:message userInfo:nil];
}
static NSDictionary *readPlist(NSString *path) {
    id value = [NSDictionary dictionaryWithContentsOfFile:path];
    require([value isKindOfClass:NSDictionary.class], @"missing dictionary");
    return value;
}
static NSDictionary *overlay(NSDictionary *base) {
    NSMutableDictionary *value = [base mutableCopy];
    value[keys()[0]] = @1000;
    value[keys()[1]] = @120;
    return value;
}
static NSDictionary *inverse(NSDictionary *current, NSDictionary *original) {
    // Preserve unrelated changes. Never overwrite a changed target value.
    if (!current[keys()[0]] && !current[keys()[1]]) return current;
    require([current[keys()[0]] isEqual:@1000] && [current[keys()[1]] isEqual:@120], @"target drift prevents inverse");
    require(!original[keys()[0]] && !original[keys()[1]], @"baseline target occupied");
    NSMutableDictionary *value = [current mutableCopy];
    [value removeObjectsForKeys:keys()];
    return value;
}
static void record(NSDictionary *value, NSString *path) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:nil];
    require(data && [data writeToFile:path options:NSDataWritingAtomic error:nil], @"receipt write failed");
    chmod(path.fileSystemRepresentation, 0600);
}
static NSDictionary *readTable(NSString *container) {
    typedef CFPropertyListRef (*Read)(CFStringRef, CFStringRef, CFStringRef, CFStringRef, CFStringRef);
    Read read = (Read)dlsym(RTLD_DEFAULT, "_CFPreferencesCopyValueWithContainer");
    require(read != NULL, @"container read symbol missing");
    id value = CFBridgingRelease(read((__bridge CFStringRef)tableKey, CFSTR("com.apple.MenuBar"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost, (__bridge CFStringRef)container));
    require([value isKindOfClass:NSDictionary.class], @"container read failed");
    return value;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        umask(0077);
        fprintf(stderr, "WARNING: unsupported DEBUG external writer; two original research keys only.\n");
        @try {
            if (argc == 2 && !strcmp(argv[1], "--self-test")) {
                NSDictionary *base = @{@"untouched": @42};
                require([inverse(overlay(base), base) isEqual:base], @"inverse mismatch");
                NSMutableDictionary *drift = [overlay(base) mutableCopy]; drift[@"untouched"] = @43;
                require([inverse(drift, base)[@"untouched"] isEqual:@43], @"foreign drift overwritten");
                drift[keys()[0]] = @777;
                BOOL rejected = NO;
                @try { inverse(drift, base); } @catch (NSException *e) { rejected = YES; }
                require(rejected, @"target drift accepted");
                require([inverse(base, base) isEqual:base], @"idempotent inverse mismatch");
                puts("4 inverse and preservation checks passed; writes=0"); return 0;
            }
            NSDictionary *version = readPlist(@"/System/Library/CoreServices/SystemVersion.plist");
            require([version[@"ProductBuildVersion"] isEqual:@"26A5425a"], @"OS build differs");
            Method method = class_getInstanceMethod(NSUserDefaults.class, @selector(_initWithSuiteName:container:));
            require(method != NULL, @"container initializer missing");
            const char *encoding = method_getTypeEncoding(method);
            if (argc == 2 && !strcmp(argv[1], "--contract")) {
                printf("initializer=%s; writes=0\n", encoding); return 0;
            }
            require(!strcmp(encoding, "@32@0:8@16@24"), @"container initializer encoding differs");
            require(argc == 3, @"expected evidence directory and apply/restore");
            NSString *root = [NSString stringWithUTF8String:argv[1]];
            NSString *phase = [NSString stringWithUTF8String:argv[2]];
            require([@[@"apply", @"restore"] containsObject:phase], @"unknown phase");
            int lock = open([[root stringByAppendingPathComponent:@"external-writer.lock"] fileSystemRepresentation], O_CREAT | O_RDWR, 0600);
            require(lock >= 0 && flock(lock, LOCK_EX | LOCK_NB) == 0, @"serial writer occupied");
            NSDictionary *before = readPlist([root stringByAppendingPathComponent:@"control-group-before.plist"]);
            NSDictionary *base = before[tableKey];
            require([base isKindOfClass:NSDictionary.class] && base.count > 0, @"baseline missing");
            require(!base[keys()[0]] && !base[keys()[1]], @"test keys already occupied");
            NSString *container = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Group Containers/com.apple.MenuBar"];
            NSString *file = [container stringByAppendingPathComponent:@"Library/Preferences/com.apple.MenuBar.plist"];
            NSDictionary *current = readTable(container);
            require([readPlist(file)[tableKey] isEqual:current], @"container/file disagreement");
            NSDictionary *next;
            NSString *receipt = [root stringByAppendingPathComponent:[NSString stringWithFormat:@"external-%@.json", phase]];
            require(![NSFileManager.defaultManager fileExistsAtPath:receipt], @"phase already attempted");
            if ([phase isEqual:@"apply"]) {
                require([readPlist(file) isEqual:before] && [current isEqual:base], @"baseline drift before apply");
                for (NSString *suffix in @[@"a", @"b"]) {
                    NSString *identity = [@"xyz.fi5h.blenny.research.adoption20260908" stringByAppendingString:suffix];
                    NSString *path = [root stringByAppendingPathComponent:[identity stringByAppendingString:@"-initial.json"]];
                    NSDictionary *owner = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path] options:0 error:nil];
                    NSArray<NSRunningApplication *> *running = [NSRunningApplication runningApplicationsWithBundleIdentifier:identity];
                    require([owner[@"bundle"] isEqual:identity] && running.count == 1 && running[0].processIdentifier == [owner[@"pid"] intValue], @"test owner changed");
                }
                // Require the controller's observed system identities, not inferred keys.
                NSDictionary *control = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"control-result.json"]] options:0 error:nil];
                require([control[@"adoption"][@"initial"][@"AdoptionProbeA"][@"key"] isEqual:keys()[0]] && [control[@"adoption"][@"initial"][@"AdoptionProbeB"][@"key"] isEqual:keys()[1]], @"system identity not verified");
                next = overlay(base);
            } else {
                require([NSFileManager.defaultManager fileExistsAtPath:[root stringByAppendingPathComponent:@"external-apply.json"]], @"no apply intent to restore");
                next = inverse(current, base);
            }
            record(@{@"phase": phase, @"intent": @YES, @"keys": keys()}, receipt);
            if (![next isEqual:current]) {
                NSUserDefaults *defaults = [[NSUserDefaults alloc] _initWithSuiteName:@"com.apple.MenuBar" container:[NSURL fileURLWithPath:container isDirectory:YES]];
                require(defaults != nil, @"container initialization failed");
                [defaults setObject:next forKey:tableKey];
                require([defaults synchronize], @"container synchronization failed");
                require([readTable(container) isEqual:next], @"readback failed");
            }
            record(@{@"phase": phase, @"completed": @YES, @"keys": keys(), @"writes": @(![next isEqual:current])}, receipt);
            printf("%s verified\n", argv[2]);
            close(lock); return 0;
        } @catch (NSException *error) {
            fprintf(stderr, "REJECTED: %s\n", error.reason.UTF8String); return 2;
        }
    }
}
