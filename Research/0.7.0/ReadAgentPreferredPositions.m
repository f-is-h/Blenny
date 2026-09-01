// Unsupported macOS 27 research; excluded from every package/product target.
// One read-only request, no private entitlement, no retry, no status items.
// Redirect stdout/stderr to ignored LocalData: returned identities are raw data.
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <unistd.h>

@interface NSObject (BlennyReadOnlyServiceTransport)
+ (id)endpointForMachName:(NSString *)machName service:(NSString *)service instance:(id)instance;
+ (NSXPCConnection *)NSXPCConnectionWithEndpoint:(id)endpoint
    configurator:(void (^)(id))configurator;
- (void)setActivateOnResume;
@end

// Independently declared from local protocol metadata and callback inspection.
// Deliberately excludes the service's clear/reset/performance-test operations.
@protocol BlennyPositionReadOnly
- (void)getPreferredTrailingItemPositions:
    (void (^)(NSDictionary<NSString *, NSNumber *> *, NSError *))reply;
@end

static void emit(id value) {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:value
        options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];
    if (!data) {
        fprintf(stderr, "JSON serialization failed\n");
        exit(5);
    }
    fwrite(data.bytes, 1, data.length, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        alarm(10); // Also bounds framework loading and synchronous transport setup.
        fprintf(stderr, "WARNING: unsupported read-only macOS 27 research; mutations=0\n");
        BOOL exactPreference = argc == 4 && !strcmp(argv[1], "--preference-key")
            && strlen(argv[2]) > 0 && strlen(argv[2]) <= 256
            && strlen(argv[3]) > 0 && strlen(argv[3]) <= 256;
        BOOL fixedMode = argc == 2 && (!strcmp(argv[1], "--preferences")
            || !strcmp(argv[1], "--xpc-mach") || !strcmp(argv[1], "--xpc-bs"));
        if (!exactPreference && !fixedMode) {
            fprintf(stderr, "Usage: reader --preferences | --preference-key DOMAIN KEY | --xpc-mach | --xpc-bs\n");
            return 2;
        }
        char build[128] = {0};
        size_t size = sizeof(build);
        if (sysctlbyname("kern.osversion", build, &size, NULL, 0) != 0
            || strcmp(build, "26A5416b") != 0) {
            fprintf(stderr, "Runtime differs from inspected contract; refusing\n");
            return 3;
        }
        if (exactPreference || !strcmp(argv[1], "--preferences")) {
            NSMutableArray *rows = [NSMutableArray array];
            NSString *keyName = exactPreference ? [NSString stringWithUTF8String:argv[3]]
                : @"TrailingItemPreferredPositions";
            NSString *exactDomain = exactPreference ? [NSString stringWithUTF8String:argv[2]] : nil;
            if (!keyName || (exactPreference && !exactDomain)) return 2;
            NSArray *domains = exactPreference ? @[exactDomain]
                : @[@"com.apple.MenuBarAgent", @"com.apple.menubaragent"];
            for (NSString *domain in domains) {
                CFStringRef key = (__bridge CFStringRef)keyName;
                id effective = CFBridgingRelease(CFPreferencesCopyAppValue(
                    key, (__bridge CFStringRef)domain));
                [rows addObject:@{@"domain": domain, @"key": keyName, @"scope": @"effective",
                    @"value": effective ?: NSNull.null}];
                for (NSNumber *currentUser in @[@YES, @NO]) {
                    for (NSNumber *currentHost in @[@YES, @NO]) {
                        id value = CFBridgingRelease(CFPreferencesCopyValue(key,
                            (__bridge CFStringRef)domain,
                            currentUser.boolValue ? kCFPreferencesCurrentUser : kCFPreferencesAnyUser,
                            currentHost.boolValue ? kCFPreferencesCurrentHost : kCFPreferencesAnyHost));
                        [rows addObject:@{@"domain": domain, @"key": keyName, @"currentUser": currentUser,
                            @"currentHost": currentHost, @"value": value ?: NSNull.null}];
                    }
                }
            }
            emit(@{@"runtime": @(build), @"operation": @"copy-only", @"rows": rows});
            return 0;
        }
        if (!dlopen("/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore",
                    RTLD_LAZY | RTLD_LOCAL)) {
            fprintf(stderr, "Metadata framework unavailable\n");
            return 3;
        }
        Protocol *contract = objc_getProtocol("MBUtilitiesXPCServer");
        SEL selector = @selector(getPreferredTrailingItemPositions:);
        struct objc_method_description method = contract
            ? protocol_getMethodDescription(contract, selector, YES, YES)
            : (struct objc_method_description){0};
        if (!method.types || strcmp(method.types, "Vv24@0:8@?16")) {
            fprintf(stderr, "Getter signature differs from inspected contract; refusing\n");
            return 3;
        }
        NSXPCInterface *interface = [NSXPCInterface interfaceWithProtocol:@protocol(BlennyPositionReadOnly)];
        [interface setClasses:[NSSet setWithObjects:NSDictionary.class, NSString.class,
            NSNumber.class, nil] forSelector:selector argumentIndex:0 ofReply:YES];
        NSXPCConnection *connection = nil;
        if (!strcmp(argv[1], "--xpc-bs")) {
            Class endpointClass = NSClassFromString(@"BSServiceConnectionEndpoint");
            Class connectionClass = NSClassFromString(@"BSServiceConnection");
            Method endpointMethod = class_getClassMethod(endpointClass,
                @selector(endpointForMachName:service:instance:));
            Method connectionMethod = class_getClassMethod(connectionClass,
                @selector(NSXPCConnectionWithEndpoint:configurator:));
            if (!endpointMethod || !connectionMethod
                || strcmp(method_getTypeEncoding(endpointMethod), "@40@0:8@16@24@32")
                || strcmp(method_getTypeEncoding(connectionMethod), "@32@0:8@16@?24")) {
                fprintf(stderr, "Service transport signature differs; refusing\n");
                return 3;
            }
            // Info.plist publishes this service through the systemservices domain,
            // not a standalone Mach service. Normal endpoint routing retains all
            // service-side authorization checks; no injector or entitlement is used.
            id endpoint = [endpointClass endpointForMachName:@"com.apple.MenuBarAgent.systemservices"
                service:@"com.apple.MenuBarAgent.utilities" instance:nil];
            connection = [connectionClass NSXPCConnectionWithEndpoint:endpoint
                configurator:^(id transport) {
                    // BoardServices passes its transport, not the NSXPC connection.
                    Method activate = class_getInstanceMethod(object_getClass(transport),
                        @selector(setActivateOnResume));
                    if (![NSStringFromClass(object_getClass(transport)) isEqualToString:@"BSNSXPCTransport"]
                        || !activate || strcmp(method_getTypeEncoding(activate), "v16@0:8")) {
                        fprintf(stderr, "Transport configuration contract differs; refusing\n");
                        exit(3);
                    }
                    [transport setActivateOnResume];
                }];
        } else {
            // Retained to reproduce the initial, unsuccessful transport hypothesis.
            connection = [[NSXPCConnection alloc]
                initWithMachServiceName:@"com.apple.MenuBarAgent.utilities" options:0];
        }
        if (![connection isKindOfClass:NSXPCConnection.class]) {
            fprintf(stderr, "No NSXPC connection returned\n");
            return 3;
        }
        connection.remoteObjectInterface = interface;
        // All completion paths serialize on the main queue, including the deadline.
        __block BOOL finished = NO;
        void (^finish)(NSDictionary *, int) = ^(NSDictionary *result, int code) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (finished) return;
                finished = YES;
                emit(result);
                [connection invalidate];
                exit(code);
            });
        };
        connection.invalidationHandler = ^{
            finish(@{@"status": @"invalidated", @"requests": @1}, 4);
        };
        connection.interruptionHandler = ^{
            finish(@{@"status": @"interrupted", @"requests": @1}, 4);
        };
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
            dispatch_get_main_queue(), ^{
                finish(@{@"status": @"timeout", @"requests": @1}, 4);
            });
        [connection resume];
        id<BlennyPositionReadOnly> proxy = [connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
            finish(@{@"status": @"transport-error", @"domain": error.domain,
                @"code": @(error.code), @"description": error.localizedDescription,
                @"requests": @1}, 4);
        }];
        [proxy getPreferredTrailingItemPositions:^(NSDictionary *positions, NSError *error) {
            if (error) {
                finish(@{@"status": @"service-error", @"domain": error.domain,
                    @"code": @(error.code), @"description": error.localizedDescription,
                    @"requests": @1}, 4);
                return;
            }
            if (![positions isKindOfClass:NSDictionary.class]) {
                finish(@{@"status": @"invalid-result", @"requests": @1}, 3);
                return;
            }
            for (id key in positions) {
                if (![key isKindOfClass:NSString.class]
                    || ![positions[key] isKindOfClass:NSNumber.class]) {
                    finish(@{@"status": @"invalid-result", @"requests": @1}, 3);
                    return;
                }
            }
            finish(@{@"status": @"read", @"positions": positions, @"requests": @1}, 0);
        }];
        dispatch_main();
    }
}
