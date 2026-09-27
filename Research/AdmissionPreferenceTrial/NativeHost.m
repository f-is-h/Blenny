// Debug-only native Settings contrast. This host never writes system preferences.
#if !DEBUG
#error Research only
#endif
#import <AppKit/AppKit.h>
@interface NativeHost : NSObject <NSApplicationDelegate>
@property NSStatusItem *item;
@property NSWindow *window;
@property NSString *output;
@end
@implementation NativeHost
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    NSString *bundle = NSRunningApplication.currentApplication.bundleIdentifier;
    NSDictionary *identity = @{@"runningApplicationBundleID":bundle ?: @"missing",
        @"mainBundleID":NSBundle.mainBundle.bundleIdentifier ?: @"missing", @"pid":@(NSProcessInfo.processInfo.processIdentifier), @"preferenceWrites":@0};
    NSData *json = [NSJSONSerialization dataWithJSONObject:identity options:NSJSONWritingPrettyPrinted error:nil];
    [json writeToFile:self.output atomically:YES];
    if (![bundle isEqual:@"xyz.fi5h.blenny.admission-trial"]) { [NSApp terminate:nil]; return; }
    self.item = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.item.button.title = @"BT";
    self.item.button.toolTip = @"Blenny native Settings contrast";
    self.item.autosaveName = @"AdmissionTrial";
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,510,170) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"Blenny Admission Host — Native Settings Test";
    NSTextField *label = [NSTextField wrappingLabelWithString:@"No private preference writer is present. With Blenny stopped, use macOS Menu Bar settings for Blenny Admission Host. Observe the original BT icon, then restore the switch to its starting state."];
    label.frame=NSMakeRect(20,55,470,95);[self.window.contentView addSubview:label];
    NSButton *quit=[NSButton buttonWithTitle:@"Quit host" target:NSApp action:@selector(terminate:)];
    quit.frame=NSMakeRect(350,15,140,32);[self.window.contentView addSubview:quit];
    [self.window center];[self.window makeKeyAndOrderFront:nil];[NSApp activate];
}
@end
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if(argc!=2 || NSProcessInfo.processInfo.operatingSystemVersion.majorVersion!=27) return 2;
        NSApplication *app=NSApplication.sharedApplication;
        NativeHost *delegate=NativeHost.new;delegate.output=[NSString stringWithUTF8String:argv[1]];
        app.delegate=delegate;[app setActivationPolicy:NSApplicationActivationPolicyRegular];[app run];
    } return 0;
}
