#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <signal.h>

// UNSUPPORTED RESEARCH PROBE. Not part of a Blenny product target.

@interface MBAssessmentModeConfiguration : NSObject
- (instancetype)initWithAllowedSystemItems:(NSArray<NSNumber *> *)systemItems
                  allowedBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers;
@end

@interface MBAssessmentModeAssertion : NSObject
- (void)activateWithConfiguration:(MBAssessmentModeConfiguration *)configuration
                completionHandler:(void (^)(NSError *error))completionHandler;
- (void)invalidate;
@end

static NSNotificationName const CommandNotification = @"com.example.BlennyToggleProbe.command";
static NSNotificationName const StateNotification = @"com.example.BlennyToggleProbe.state";
static NSString *const DefaultBlennyBundleIdentifier = @"com.example.BlennyProbe";

@interface TogglePolicyController : NSObject
@property(nonatomic, strong) MBAssessmentModeAssertion *activeAssertion;
@property(nonatomic) Class assertionClass;
@property(nonatomic) Class configurationClass;
@property(nonatomic, copy) NSString *targetBundleIdentifier;
@property(nonatomic, copy) NSString *blennyBundleIdentifier;
@property(nonatomic) BOOL collapsed;
@property(nonatomic) BOOL hasActiveState;
@property(nonatomic) BOOL transitioning;
@property(nonatomic) BOOL stopped;
@property(nonatomic, strong) NSTimer *timeoutTimer;
@end

@implementation TogglePolicyController

- (BOOL)loadPrivateRuntime {
    const char *frameworkPath =
        "/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore";
    void *framework = dlopen(frameworkPath, RTLD_NOW | RTLD_LOCAL);
    self.assertionClass = NSClassFromString(@"MBAssessmentModeAssertion");
    self.configurationClass = NSClassFromString(@"MBAssessmentModeConfiguration");
    return framework != NULL
        && self.assertionClass != Nil
        && self.configurationClass != Nil
        && class_getInstanceMethod(
            self.assertionClass,
            @selector(activateWithConfiguration:completionHandler:)
        ) != NULL
        && class_getInstanceMethod(self.assertionClass, @selector(invalidate)) != NULL
        && class_getInstanceMethod(
            self.configurationClass,
            @selector(initWithAllowedSystemItems:allowedBundleIdentifiers:)
        ) != NULL;
}

- (BOOL)targetIsRunning {
    for (NSRunningApplication *application in NSWorkspace.sharedWorkspace.runningApplications) {
        if ([application.bundleIdentifier isEqualToString:self.targetBundleIdentifier]) {
            return YES;
        }
    }
    return NO;
}

- (void)start {
    [NSDistributedNotificationCenter.defaultCenter
        addObserver:self
           selector:@selector(receiveCommand:)
               name:CommandNotification
             object:nil
 suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
    self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:3600.0
                                                         target:self
                                                       selector:@selector(timeout:)
                                                       userInfo:nil
                                                        repeats:NO];
    [self applyCollapsed:YES requestID:nil sentTime:0.0];
}

- (NSArray<NSString *> *)allowedBundlesForCollapsedState:(BOOL)collapsed {
    NSMutableOrderedSet<NSString *> *bundles = [NSMutableOrderedSet orderedSet];
    for (NSRunningApplication *application in NSWorkspace.sharedWorkspace.runningApplications) {
        NSString *bundleIdentifier = application.bundleIdentifier;
        if (bundleIdentifier.length == 0) continue;
        if (collapsed && [bundleIdentifier isEqualToString:self.targetBundleIdentifier]) continue;
        [bundles addObject:bundleIdentifier];
    }
    [bundles addObject:self.blennyBundleIdentifier];
    if (!collapsed) [bundles addObject:self.targetBundleIdentifier];
    return bundles.array;
}

- (NSArray<NSNumber *> *)allSystemItems {
    NSMutableArray<NSNumber *> *items = [NSMutableArray arrayWithCapacity:9];
    for (NSInteger rawValue = 0; rawValue < 9; rawValue += 1) {
        [items addObject:@(rawValue)];
    }
    return items;
}

- (void)applyCollapsed:(BOOL)collapsed
             requestID:(NSString *)requestID
              sentTime:(double)sentTime {
    if (self.stopped || self.transitioning) return;
    if (self.hasActiveState && self.collapsed == collapsed) {
        [self postStateWithRequestID:requestID sentTime:sentTime policyMilliseconds:0.0];
        return;
    }

    self.transitioning = YES;
    MBAssessmentModeConfiguration *configuration =
        [[self.configurationClass alloc]
            initWithAllowedSystemItems:self.allSystemItems
              allowedBundleIdentifiers:[self allowedBundlesForCollapsedState:collapsed]];
    MBAssessmentModeAssertion *replacement = [[self.assertionClass alloc] init];
    if (configuration == nil || replacement == nil) {
        self.transitioning = NO;
        [self postError];
        return;
    }

    CFAbsoluteTime policyStart = CFAbsoluteTimeGetCurrent();
    [replacement activateWithConfiguration:configuration
                         completionHandler:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            double policyMilliseconds =
                (CFAbsoluteTimeGetCurrent() - policyStart) * 1000.0;
            self.transitioning = NO;
            if (error != nil || self.stopped) {
                [replacement invalidate];
                [self postError];
                return;
            }

            MBAssessmentModeAssertion *preceding = self.activeAssertion;
            self.activeAssertion = replacement;
            self.collapsed = collapsed;
            self.hasActiveState = YES;
            [preceding invalidate];
            [self postStateWithRequestID:requestID
                                sentTime:sentTime
                      policyMilliseconds:policyMilliseconds];
            fprintf(stdout, "STATE %s policy_ms=%.3f\n",
                    collapsed ? "collapsed" : "expanded",
                    policyMilliseconds);
            fflush(stdout);
        });
    }];
}

- (void)receiveCommand:(NSNotification *)notification {
    NSString *command = [notification.object isKindOfClass:NSString.class]
        ? notification.object
        : @"";
    NSDictionary *userInfo = notification.userInfo ?: @{};
    NSString *requestID = [userInfo[@"requestID"] isKindOfClass:NSString.class]
        ? userInfo[@"requestID"]
        : nil;
    double sentTime = [userInfo[@"sentTime"] doubleValue];

    if ([command isEqualToString:@"query"]) {
        if (self.hasActiveState && !self.transitioning) {
            [self postStateWithRequestID:nil sentTime:0.0 policyMilliseconds:0.0];
        }
    } else if ([command isEqualToString:@"collapsed"]) {
        [self applyCollapsed:YES requestID:requestID sentTime:sentTime];
    } else if ([command isEqualToString:@"expanded"]) {
        [self applyCollapsed:NO requestID:requestID sentTime:sentTime];
    }
}

- (void)postStateWithRequestID:(NSString *)requestID
                      sentTime:(double)sentTime
            policyMilliseconds:(double)policyMilliseconds {
    NSMutableDictionary *userInfo = [@{
        @"sentTime": @(sentTime),
        @"policyMilliseconds": @(policyMilliseconds),
    } mutableCopy];
    if (requestID != nil) userInfo[@"requestID"] = requestID;
    NSString *state = self.collapsed ? @"collapsed" : @"expanded";
    [NSDistributedNotificationCenter.defaultCenter
        postNotificationName:StateNotification
                      object:state
                    userInfo:userInfo
          deliverImmediately:YES];
}

- (void)postError {
    [NSDistributedNotificationCenter.defaultCenter
        postNotificationName:StateNotification
                      object:@"error"
                    userInfo:nil
          deliverImmediately:YES];
}

- (void)timeout:(NSTimer *)timer {
    (void)timer;
    [self shutdown];
}

- (void)shutdown {
    if (self.stopped) return;
    self.stopped = YES;
    [self.timeoutTimer invalidate];
    [NSDistributedNotificationCenter.defaultCenter removeObserver:self];
    [self.activeAssertion invalidate];
    self.activeAssertion = nil;
    [NSDistributedNotificationCenter.defaultCenter
        postNotificationName:StateNotification
                      object:@"shutdown"
                    userInfo:nil
          deliverImmediately:YES];
    fprintf(stdout, "RESTORED assertion_invalidated=yes\n");
    fflush(stdout);
    CFRunLoopStop(CFRunLoopGetMain());
}

@end

int main(void) {
    @autoreleasepool {
        NSDictionary<NSString *, NSString *> *environment = NSProcessInfo.processInfo.environment;
        NSString *targetBundleIdentifier = environment[@"BLENNY_TEST_TARGET_BUNDLE_ID"];
        if (targetBundleIdentifier.length == 0) {
            fprintf(stderr, "FAIL_CLOSED BLENNY_TEST_TARGET_BUNDLE_ID is required\n");
            return 19;
        }

        TogglePolicyController *controller = [[TogglePolicyController alloc] init];
        controller.targetBundleIdentifier = targetBundleIdentifier;
        controller.blennyBundleIdentifier =
            environment[@"BLENNY_PROBE_BUNDLE_ID"] ?: DefaultBlennyBundleIdentifier;
        if (![controller loadPrivateRuntime]) {
            fprintf(stderr, "FAIL_CLOSED private runtime surface unavailable\n");
            return 20;
        }
        if (![controller targetIsRunning]) {
            fprintf(stderr, "FAIL_CLOSED approved target is not running\n");
            return 21;
        }

        signal(SIGINT, SIG_IGN);
        signal(SIGTERM, SIG_IGN);
        dispatch_source_t interruptSource = dispatch_source_create(
            DISPATCH_SOURCE_TYPE_SIGNAL, SIGINT, 0, dispatch_get_main_queue()
        );
        dispatch_source_t terminateSource = dispatch_source_create(
            DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, dispatch_get_main_queue()
        );
        dispatch_source_set_event_handler(interruptSource, ^{ [controller shutdown]; });
        dispatch_source_set_event_handler(terminateSource, ^{ [controller shutdown]; });
        dispatch_resume(interruptSource);
        dispatch_resume(terminateSource);

        [controller start];
        [NSRunLoop.currentRunLoop run];
        (void)interruptSource;
        (void)terminateSource;
    }
    return 0;
}
