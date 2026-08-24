#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

// UNSUPPORTED RESEARCH PROBE. Not part of a Blenny product target.

static NSNotificationName const CommandNotification = @"com.example.BlennyToggleProbe.command";
static NSNotificationName const StateNotification = @"com.example.BlennyToggleProbe.state";

static NSString *eventLogPath(void) {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"BlennyToggleProbe-events.log"];
}

static void appendEvent(NSString *line) {
    NSString *path = eventLogPath();
    NSData *data = [[line stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
    NSFileManager *files = NSFileManager.defaultManager;
    if (![files fileExistsAtPath:path]) {
        [files createFileAtPath:path contents:nil attributes:nil];
    }
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
    [handle seekToEndOfFile];
    [handle writeData:data];
    [handle closeFile];
}

@interface InstalledToggleDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic) BOOL ready;
@property(nonatomic) BOOL collapsed;
@property(nonatomic) BOOL transitionPending;
@property(nonatomic) CFAbsoluteTime pendingSentTime;
@property(nonatomic, copy) NSString *pendingRequestID;
@end

@implementation InstalledToggleDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    NSStatusBarButton *button = self.statusItem.button;
    button.target = self;
    button.action = @selector(toggle:);
    button.imagePosition = NSImageLeft;
    button.title = @"BLENNY";
    button.enabled = NO;
    button.toolTip = @"Waiting for bounded unsupported policy probe";
    [button setAccessibilityLabel:@"Blenny research control, waiting for policy state"];

    [NSDistributedNotificationCenter.defaultCenter
        addObserver:self
           selector:@selector(receiveState:)
               name:StateNotification
             object:nil
 suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];

    [NSTimer scheduledTimerWithTimeInterval:3600.0
                                     target:self
                                   selector:@selector(timeout:)
                                   userInfo:nil
                                    repeats:NO];
    [self performSelector:@selector(queryState) withObject:nil afterDelay:0.2];
}

- (void)queryState {
    [NSDistributedNotificationCenter.defaultCenter
        postNotificationName:CommandNotification
                      object:@"query"
                    userInfo:nil
          deliverImmediately:YES];
}

- (void)toggle:(id)sender {
    (void)sender;
    if (!self.ready || self.transitionPending) return;

    NSString *desiredState = self.collapsed ? @"expanded" : @"collapsed";
    self.transitionPending = YES;
    self.pendingSentTime = CFAbsoluteTimeGetCurrent();
    self.pendingRequestID = NSUUID.UUID.UUIDString;
    self.statusItem.button.enabled = NO;
    self.statusItem.button.title = @"BLENNY …";

    NSDictionary *userInfo = @{
        @"requestID": self.pendingRequestID,
        @"sentTime": @(self.pendingSentTime),
    };
    [NSDistributedNotificationCenter.defaultCenter
        postNotificationName:CommandNotification
                      object:desiredState
                    userInfo:userInfo
          deliverImmediately:YES];
}

- (void)receiveState:(NSNotification *)notification {
    NSString *state = [notification.object isKindOfClass:NSString.class]
        ? notification.object
        : @"error";
    NSDictionary *userInfo = notification.userInfo ?: @{};

    if ([state isEqualToString:@"shutdown"] || [state isEqualToString:@"error"]) {
        self.ready = NO;
        self.transitionPending = NO;
        self.statusItem.button.enabled = NO;
        self.statusItem.button.title = @"BLENNY OFF";
        self.statusItem.button.toolTip = @"Unsupported policy probe is not active";
        appendEvent([NSString stringWithFormat:@"state=%@", state]);
        return;
    }

    if (![state isEqualToString:@"collapsed"] && ![state isEqualToString:@"expanded"]) {
        return;
    }

    NSString *requestID = [userInfo[@"requestID"] isKindOfClass:NSString.class]
        ? userInfo[@"requestID"]
        : nil;
    BOOL matchesPending = requestID != nil && [requestID isEqualToString:self.pendingRequestID];
    double sentTime = [userInfo[@"sentTime"] doubleValue];
    double policyMilliseconds = [userInfo[@"policyMilliseconds"] doubleValue];
    double endToEndMilliseconds = sentTime > 0
        ? (CFAbsoluteTimeGetCurrent() - sentTime) * 1000.0
        : 0.0;

    self.collapsed = [state isEqualToString:@"collapsed"];
    self.ready = YES;
    if (matchesPending || requestID == nil) {
        self.transitionPending = NO;
        self.pendingRequestID = nil;
    }

    NSString *symbolName = self.collapsed ? @"chevron.right.2" : @"chevron.left.2";
    NSString *actionName = self.collapsed ? @"Reveal" : @"Conceal";
    NSImage *image = [NSImage imageWithSystemSymbolName:symbolName
                              accessibilityDescription:actionName];
    image.template = YES;
    self.statusItem.button.image = image;
    self.statusItem.button.title = @"BLENNY";
    self.statusItem.button.enabled = !self.transitionPending;
    self.statusItem.button.toolTip = [NSString stringWithFormat:
        @"Unsupported %@ probe — policy %.1f ms, end-to-end %.1f ms",
        actionName,
        policyMilliseconds,
        endToEndMilliseconds
    ];
    [self.statusItem.button setAccessibilityLabel:
        [NSString stringWithFormat:@"Blenny research control: %@", actionName]];

    appendEvent([NSString stringWithFormat:
        @"state=%@ policy_ms=%.3f e2e_ms=%.3f requested=%@",
        state,
        policyMilliseconds,
        endToEndMilliseconds,
        requestID == nil ? @"no" : @"yes"
    ]);
}

- (void)timeout:(NSTimer *)timer {
    (void)timer;
    [NSApp terminate:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    [NSDistributedNotificationCenter.defaultCenter removeObserver:self];
}

@end

int main(void) {
    @autoreleasepool {
        NSApplication *application = NSApplication.sharedApplication;
        InstalledToggleDelegate *delegate = [[InstalledToggleDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
