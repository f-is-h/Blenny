// Debug research only. Exact-file permission and reads; no system setter.
#import <AppKit/AppKit.h>
#import <CommonCrypto/CommonDigest.h>
#import <objc/runtime.h>

@interface NSUserDefaults (AdmissionContainerRead)
- (instancetype)_initWithSuiteName:(NSString *)name container:(NSURL *)container;
@end

static NSString *digest(NSData *data) {
    unsigned char bytes[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, bytes);
    NSMutableString *result = NSMutableString.string;
    for (NSUInteger i = 0; i < sizeof(bytes); ++i) [result appendFormat:@"%02x", bytes[i]];
    return result;
}

@interface SnapshotDelegate : NSObject <NSApplicationDelegate>
@property NSURL *output;
@end

@implementation SnapshotDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    NSOpenPanel *panel = NSOpenPanel.openPanel;
    NSURL *container = [NSURL fileURLWithPath:[NSHomeDirectory()
        stringByAppendingPathComponent:@"Library/Group Containers/group.com.apple.controlcenter"]
        isDirectory:YES];
    NSURL *expected = [container URLByAppendingPathComponent:
        @"Library/Preferences/group.com.apple.controlcenter.plist"];
    panel.title = @"Blenny Admission Research — Exact File Access";
    panel.message = @"Choose group.com.apple.controlcenter.plist. This step only saves a private snapshot; it does not change menu bar settings.";
    panel.prompt = @"Grant File Access";
    panel.canChooseDirectories = NO;
    panel.canChooseFiles = YES;
    panel.canCreateDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.directoryURL = expected.URLByDeletingLastPathComponent;
    panel.nameFieldStringValue = expected.lastPathComponent;
    [NSApp activate];
    NSModalResponse response = [panel runModal];
    NSMutableDictionary *report = [@{@"systemWrites": @0, @"snapshotComplete": @NO} mutableCopy];
    NSURL *selected = panel.URL;
    BOOL scoped = NO;
    @try {
        if (response != NSModalResponseOK || !selected) {
            report[@"status"] = @"cancelled";
        } else if (![selected.URLByStandardizingPath.URLByResolvingSymlinksInPath.path
            isEqual:expected.URLByStandardizingPath.URLByResolvingSymlinksInPath.path]) {
            report[@"status"] = @"rejectedUnexpectedFile";
        } else {
            scoped = [selected startAccessingSecurityScopedResource];
            NSError *error = nil;
            NSData *before = [NSData dataWithContentsOfURL:selected options:0 error:&error];
            if (!before) @throw [NSException exceptionWithName:@"ReadFailed" reason:error.description userInfo:nil];
            if (before.length > 16 * 1024 * 1024) @throw [NSException exceptionWithName:@"Oversize" reason:@"Preference file exceeds research bound" userInfo:nil];
            id plist = [NSPropertyListSerialization propertyListWithData:before options:NSPropertyListImmutable format:nil error:&error];
            if (![plist isKindOfClass:NSDictionary.class]) @throw [NSException exceptionWithName:@"Schema" reason:@"Expected a preference dictionary" userInfo:nil];
            Method method = class_getInstanceMethod(NSUserDefaults.class, @selector(_initWithSuiteName:container:));
            if (!method || strcmp(method_getTypeEncoding(method), "@32@0:8@16@24") != 0)
                @throw [NSException exceptionWithName:@"ABI" reason:@"Container initializer differs" userInfo:nil];
            NSUserDefaults *defaults = [[NSUserDefaults alloc] _initWithSuiteName:@"group.com.apple.controlcenter" container:container];
            id api = [defaults objectForKey:@"trackedApplications"];
            id value = plist[@"trackedApplications"];
            NSData *after = [NSData dataWithContentsOfURL:selected options:0 error:&error];
            BOOL stable = [before isEqual:after];
            BOOL agreement = value != nil && [value isEqual:api];
            NSURL *snapshot = [self.output URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
            if (![NSFileManager.defaultManager createDirectoryAtURL:snapshot withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error])
                @throw [NSException exceptionWithName:@"LocalEvidence" reason:error.description userInfo:nil];
            if (![before writeToURL:[snapshot URLByAppendingPathComponent:@"baseline.plist"] options:NSDataWritingAtomic error:&error])
                @throw [NSException exceptionWithName:@"LocalEvidence" reason:error.description userInfo:nil];
            NSData *bookmark = [selected bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
            BOOL savedBookmark = bookmark && [bookmark writeToURL:[snapshot URLByAppendingPathComponent:@"exact-file.bookmark"] options:NSDataWritingAtomic error:&error];
            report[@"status"] = @"readCompleted";
            report[@"snapshotDirectory"] = snapshot.path;
            report[@"fileSHA256"] = digest(before);
            report[@"fileStable"] = @(stable);
            report[@"keyPresent"] = @(value != nil);
            report[@"keyType"] = value ? NSStringFromClass([value class]) : @"absent";
            report[@"apiAgreement"] = @(agreement);
            report[@"bookmarkSaved"] = @(savedBookmark);
            report[@"securityScopeStarted"] = @(scoped);
            report[@"snapshotComplete"] = @(stable && agreement && savedBookmark);
        }
    } @catch (NSException *exception) {
        report[@"status"] = @"failedClosed";
        report[@"error"] = exception.reason ?: exception.name;
    } @finally {
        if (scoped) [selected stopAccessingSecurityScopedResource];
    }
    NSData *json = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
    [json writeToURL:[self.output URLByAppendingPathComponent:@"latest.json"] options:NSDataWritingAtomic error:nil];
    fwrite(json.bytes, 1, json.length, stdout); puts(""); fflush(stdout);
    [NSApp terminate:nil];
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2 || NSProcessInfo.processInfo.operatingSystemVersion.majorVersion != 27) return 2;
        NSURL *output = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]] isDirectory:YES];
        NSError *error = nil;
        if (![NSFileManager.defaultManager createDirectoryAtURL:output withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error]) return 2;
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        SnapshotDelegate *delegate = SnapshotDelegate.new;
        delegate.output = output;
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
