// Unsupported macOS 27 Debug research. Only this disposable application's row may change.
#if !DEBUG
#error This research executable must never be built without DEBUG.
#endif
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

static NSString *const owner = @"xyz.fi5h.blenny.admission-trial";
static NSString *const key = @"trackedApplications";
@interface NSUserDefaults (TrialContainer)
- (instancetype)_initWithSuiteName:(NSString *)name container:(NSURL *)url;
@end

static void require(BOOL condition, NSString *reason) {
    if (!condition) @throw [NSException exceptionWithName:@"TrialStopped" reason:reason userInfo:nil];
}
static NSData *encode(id value) {
    NSError *error = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:value format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
    require(data != nil, error.description ?: @"Encoding failed"); return data;
}
static id decode(NSData *data) {
    require([data isKindOfClass:NSData.class] && data.length <= 16 * 1024 * 1024, @"Invalid or oversized data");
    NSError *error = nil;
    id result = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:&error];
    require(result != nil, error.description ?: @"Decoding failed"); return result;
}
static NSUInteger targetIndex(NSArray *rows) {
    require([rows isKindOfClass:NSArray.class] && rows.count > 0 && rows.count <= 512 && rows.count % 2 == 0, @"Unknown row-list schema");
    NSMutableArray *locations = NSMutableArray.array;
    NSUInteger target = NSNotFound;
    for (NSUInteger i = 0; i < rows.count; i += 2) {
        NSDictionary *location = rows[i], *row = rows[i + 1];
        require([location isKindOfClass:NSDictionary.class] && [row isKindOfClass:NSDictionary.class], @"Invalid row");
        require([row[@"location"] isEqual:location] && [row[@"menuItemLocations"] isKindOfClass:NSArray.class], @"Location schema differs");
        id allowed = row[@"isAllowed"];
        require(allowed && CFGetTypeID((__bridge CFTypeRef)allowed) == CFBooleanGetTypeID(), @"Admission is not a Boolean");
        require(![locations containsObject:location], @"Duplicate location");
        [locations addObject:location];
        if ([location isEqual:@{@"bundle": @{@"_0": owner}}]) target = i + 1;
    }
    return target;
}
static NSData *hideProposal(NSData *baseline) {
    NSArray *rows = decode(baseline); NSUInteger index = targetIndex(rows);
    if (index == NSNotFound) {
        NSDictionary *location = @{@"bundle":@{@"_0":owner}};
        NSMutableArray *next = rows.mutableCopy;
        [next addObjectsFromArray:@[location, @{@"location":location,
            @"menuItemLocations":@[location], @"isAllowed":@NO}]];
        return encode(next);
    }
    require([rows[index][@"isAllowed"] boolValue], @"Helper was already denied; preserve its baseline");
    NSMutableArray *next = rows.mutableCopy;
    NSMutableDictionary *row = [rows[index] mutableCopy]; row[@"isAllowed"] = @NO;
    next[index] = row; return encode(next);
}
static NSData *restoration(NSData *current, NSData *before, NSData *after) {
    NSArray *c = decode(current), *b = decode(before), *a = decode(after);
    NSUInteger ci = targetIndex(c), bi = targetIndex(b), ai = targetIndex(a);
    require(ai != NSNotFound, @"Receipt has no proposed target");
    if ([current isEqual:before]) return current;
    if (bi == NSNotFound) {
        if (ci == NSNotFound) return current;
        require([c[ci] isEqual:a[ai]], @"Inserted target changed externally; retain receipt");
        if ([current isEqual:after]) return before;
        NSMutableArray *next = c.mutableCopy;
        [next removeObjectsInRange:NSMakeRange(ci - 1, 2)];
        return encode(next);
    }
    require(ci != NSNotFound, @"Existing target was removed externally; retain receipt");
    require([c[ci] isEqual:a[ai]] || [c[ci] isEqual:b[bi]], @"Target changed externally; retain receipt and stop");
    if ([current isEqual:after]) return before; // Preserve original encoded bytes on the normal inverse.
    NSMutableArray *next = c.mutableCopy; next[ci] = b[bi];
    return encode(next); // Preserve all current unrelated rows on an external change.
}
static void save(NSData *data, NSURL *url) {
    NSError *error = nil;
    require([data writeToURL:url options:NSDataWritingAtomic error:&error], error.description ?: @"Evidence write failed");
    require([NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:url.path error:&error], @"Cannot secure local evidence");
}

@interface Trial : NSObject <NSApplicationDelegate>
@property NSURL *output;
@property NSURL *bookmark;
@property NSURL *file;
@property NSUserDefaults *defaults;
@property NSStatusItem *item;
@property NSWindow *window;
@property NSTextField *label;
@property NSButton *runButton;
@property NSMutableDictionary *receipt;
@property BOOL pending;
@property BOOL attempted;
@property BOOL recoveryOnly;
@property BOOL scoped;
@end

@implementation Trial
- (NSURL *)receiptURL { return [self.output URLByAppendingPathComponent:@"receipt.plist"]; }
- (void)record:(NSString *)status {
    self.receipt[@"status"] = status;
    self.receipt[@"updatedAt"] = NSDate.date;
    save(encode(self.receipt), self.receiptURL);
    NSLog(@"Admission trial: %@", status);
    self.label.stringValue = status;
}
- (NSData *)readAgreed {
    NSURL *result = [self.output URLByAppendingPathComponent:
        [NSString stringWithFormat:@"read-%@.plist", NSUUID.UUID.UUIDString]];
    NSTask *reader = NSTask.new;
    reader.executableURL = NSBundle.mainBundle.executableURL;
    reader.arguments = @[@"--read-state", self.file.path, result.path];
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    reader.terminationHandler = ^(NSTask *task) { (void)task; dispatch_semaphore_signal(finished); };
    NSError *error = nil;
    require([reader launchAndReturnError:&error], error.description ?: @"Cannot launch fresh reader");
    if (dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) != 0) {
        [reader terminate];
        require(NO, @"Fresh reader exceeded five-second bound");
    }
    require(reader.terminationStatus == 0, @"Fresh reader rejected file/API agreement");
    NSDictionary *snapshot = decode([NSData dataWithContentsOfURL:result]);
    NSData *blob = snapshot[@"trackedData"];
    require([blob isKindOfClass:NSData.class], @"Fresh reader produced no data");
    NSDictionary *current = decode([NSData dataWithContentsOfURL:self.file]);
    require([current[key] isEqual:blob], @"File changed after fresh read");
    (void)targetIndex(decode(blob));
    return blob;
}
- (void)writeOnce:(NSData *)data expecting:(NSData *)expected {
    require([[self readAgreed] isEqual:expected], @"Pre-write state changed");
    [self.defaults setObject:data forKey:key];
    BOOL synchronized = [self.defaults synchronize];
    // A single bounded settlement read, never polling or retrying the write.
    [NSThread sleepForTimeInterval:1.5];
    NSData *readback = [self readAgreed];
    require(synchronized && [readback isEqual:data], @"Write readback failed");
}
- (void)restore:(id)sender {
    (void)sender;
    if (!self.pending) return;
    @try {
        NSData *current = [self readAgreed];
        NSData *inverse = restoration(current, self.receipt[@"before"], self.receipt[@"after"]);
        NSUInteger attempts = [self.receipt[@"restoreWriteAttempts"] unsignedIntegerValue];
        require([current isEqual:inverse] || attempts < 2, @"Restore write limit reached; keep receipt");
        if (![current isEqual:inverse]) self.receipt[@"restoreWriteAttempts"] = @(attempts + 1);
        [self record:@"restoring"];
        if (![current isEqual:inverse]) [self writeOnce:inverse expecting:current];
        require([[self readAgreed] isEqual:inverse], @"Restoration readback differs");
        self.receipt[@"restoredData"] = inverse;
        self.receipt[@"exactBaselineBytesRestored"] = @([inverse isEqual:self.receipt[@"before"]]);
        [self record:@"restored — observe whether BT returned"];
        self.pending = NO;
    } @catch (NSException *exception) {
        self.receipt[@"failure"] = exception.reason ?: exception.name;
        [self record:@"RESTORATION REQUIRED — do not discard receipt"];
    }
}
- (void)runTrial:(id)sender {
    (void)sender;
    if (self.attempted || self.pending) return;
    self.attempted = YES; self.runButton.enabled = NO;
    @try {
        require([NSBundle.mainBundle.bundleIdentifier isEqual:owner], @"Unexpected helper identity");
        require(![NSFileManager.defaultManager fileExistsAtPath:self.receiptURL.path], @"Existing receipt: use recovery mode");
        NSData *before = [self readAgreed];
        NSData *after = hideProposal(before);
        save([NSData dataWithContentsOfURL:self.file], [self.output URLByAppendingPathComponent:@"before.plist"]);
        self.receipt = [@{@"version":@1, @"owner":owner, @"before":before, @"after":after} mutableCopy];
        [self record:@"prepared"];
        self.pending = YES;
        [self writeOnce:after expecting:before];
        [self record:@"deny verified — observe BT; automatic restore in 12 seconds"];
        [NSTimer scheduledTimerWithTimeInterval:12 target:self selector:@selector(restore:) userInfo:nil repeats:NO];
    } @catch (NSException *exception) {
        NSLog(@"Trial stopped: %@", exception.reason);
        self.label.stringValue = exception.reason ?: exception.name;
        if (self.pending) {
            self.receipt[@"applyFailure"] = exception.reason ?: exception.name;
            [self restore:nil];
        }
    }
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    @try {
        BOOL stale = NO; NSError *error = nil;
        NSData *bookmark = [NSData dataWithContentsOfURL:self.bookmark];
        require(bookmark != nil, @"Missing exact-file bookmark");
        self.file = [NSURL URLByResolvingBookmarkData:bookmark options:NSURLBookmarkResolutionWithSecurityScope | NSURLBookmarkResolutionWithoutUI relativeToURL:nil bookmarkDataIsStale:&stale error:&error];
        NSString *expected = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Group Containers/group.com.apple.controlcenter/Library/Preferences/group.com.apple.controlcenter.plist"];
        BOOL correct = [self.file.URLByStandardizingPath.URLByResolvingSymlinksInPath.path isEqual:expected];
        if (stale && correct && [self.file startAccessingSecurityScopedResource]) {
            NSData *renewed = [self.file bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
            [self.file stopAccessingSecurityScopedResource];
            if (renewed) {
                save(renewed, [self.output URLByAppendingPathComponent:@"exact-file.bookmark"]);
                self.file = [NSURL URLByResolvingBookmarkData:renewed options:NSURLBookmarkResolutionWithSecurityScope | NSURLBookmarkResolutionWithoutUI relativeToURL:nil bookmarkDataIsStale:&stale error:&error];
                correct = [self.file.URLByStandardizingPath.URLByResolvingSymlinksInPath.path isEqual:expected];
            }
        }
        if (stale || !correct) {
            NSLog(@"Exact-file bookmark needs renewal: stale=%d expectedTarget=%d", stale, correct);
            NSOpenPanel *panel = NSOpenPanel.openPanel;
            panel.title = @"Blenny Admission Trial — Exact File Access";
            panel.message = @"Select group.com.apple.controlcenter.plist for this independent trial. No write occurs until Run once is pressed.";
            panel.prompt = @"Grant File Access";
            panel.canChooseDirectories = NO; panel.canChooseFiles = YES;
            panel.allowsMultipleSelection = NO; panel.canCreateDirectories = NO;
            panel.directoryURL = [NSURL fileURLWithPath:expected].URLByDeletingLastPathComponent;
            panel.nameFieldStringValue = @"group.com.apple.controlcenter.plist";
            [NSApp activate];
            require([panel runModal] == NSModalResponseOK, @"Exact-file selection cancelled");
            self.file = panel.URL;
            require([self.file.URLByStandardizingPath.URLByResolvingSymlinksInPath.path isEqual:expected], @"Wrong file selected");
            NSData *renewed = [self.file bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
            require(renewed != nil, @"Cannot save exact-file permission");
            save(renewed, [self.output URLByAppendingPathComponent:@"exact-file.bookmark"]);
        }
        self.scoped = [self.file startAccessingSecurityScopedResource];
        require(self.scoped, @"Exact-file scope unavailable");
        Method m = class_getInstanceMethod(NSUserDefaults.class, @selector(_initWithSuiteName:container:));
        require(m && strcmp(method_getTypeEncoding(m), "@32@0:8@16@24") == 0, @"Container ABI differs");
        self.defaults = [[NSUserDefaults alloc] _initWithSuiteName:@"group.com.apple.controlcenter" container:self.file.URLByDeletingLastPathComponent.URLByDeletingLastPathComponent.URLByDeletingLastPathComponent];
        require([NSData dataWithContentsOfURL:self.file] != nil, @"Scoped file read unavailable");
        if (self.recoveryOnly) {
            self.receipt = [decode([NSData dataWithContentsOfURL:self.receiptURL]) mutableCopy];
            require([self.receipt[@"owner"] isEqual:owner] && [self.receipt[@"version"] isEqual:@1], @"Receipt identity differs");
            require([decode(hideProposal(self.receipt[@"before"])) isEqual:decode(self.receipt[@"after"])], @"Receipt proposal differs");
            self.pending = YES; [self restore:nil];
            if (!self.pending) [NSApp terminate:nil];
            return;
        }
        self.item = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
        self.item.button.title = @"BT";
        self.item.button.toolTip = @"Blenny disposable admission trial";
        self.item.autosaveName = @"AdmissionTrial";
        self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,590,210) styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
        self.window.title = @"Blenny — Unsupported Admission Trial";
        self.window.releasedWhenClosed = NO;
        NSTextField *intro = [NSTextField wrappingLabelWithString:@"Stop Blenny management first. Confirm the BT menu-bar icon is visible. This trial changes only its own isAllowed flag, then restores it automatically. No Gaming or Wine setting is written."];
        intro.frame = NSMakeRect(20,125,550,65); [self.window.contentView addSubview:intro];
        self.label = [NSTextField wrappingLabelWithString:@"Ready — one attempt only; keep this window open."];
        self.label.frame = NSMakeRect(20,65,550,50); [self.window.contentView addSubview:self.label];
        self.runButton = [NSButton buttonWithTitle:@"Run once — restore after 12 seconds" target:self action:@selector(runTrial:)];
        self.runButton.frame = NSMakeRect(20,20,325,32); [self.window.contentView addSubview:self.runButton];
        NSButton *restore = [NSButton buttonWithTitle:@"Restore now" target:self action:@selector(restore:)];
        restore.frame = NSMakeRect(370,20,180,32); [self.window.contentView addSubview:restore];
        [self.window center]; [self.window makeKeyAndOrderFront:nil]; [NSApp activate];
        NSLog(@"Ready: helper started; system preference writes=0");
    } @catch (NSException *exception) {
        NSLog(@"Preflight stopped: %@", exception.reason);
        [NSApp terminate:nil];
    }
}
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    (void)sender;
    if (self.pending) [self restore:nil];
    return self.pending ? NSTerminateCancel : NSTerminateNow;
}
- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    if (self.scoped) [self.file stopAccessingSecurityScopedResource];
}
@end

static void tests(void) {
    NSDictionary *(^row)(NSString *, BOOL) = ^NSDictionary *(NSString *identity, BOOL allowed) {
        NSDictionary *location = @{@"bundle":@{@"_0":identity}};
        return @{@"location":location, @"menuItemLocations":@[location], @"isAllowed":@(allowed)};
    };
    NSDictionary *own = row(owner, YES), *other = row(@"example.unrelated", YES);
    NSData *before = encode(@[own[@"location"],own,other[@"location"],other]);
    NSData *after = hideProposal(before);
    require([restoration(after,before,after) isEqual:before], @"Exact inverse test");
    require([restoration(before,before,after) isEqual:before], @"Already restored test");
    NSMutableArray *changed = [decode(after) mutableCopy]; changed[3] = row(@"example.unrelated", NO);
    NSArray *merged = decode(restoration(encode(changed),before,after));
    require([merged[1] isEqual:own] && ![merged[3][@"isAllowed"] boolValue], @"Unrelated edit preservation test");
    BOOL rejected = NO;
    @try { (void)hideProposal(after); } @catch (NSException *e) { (void)e; rejected = YES; }
    require(rejected, @"Previously denied target test"); rejected = NO;
    changed = [decode(after) mutableCopy]; NSMutableDictionary *conflict = [changed[1] mutableCopy]; conflict[@"newField"] = @YES; changed[1] = conflict;
    @try { (void)restoration(encode(changed),before,after); } @catch (NSException *e) { (void)e; rejected = YES; }
    require(rejected, @"Target conflict test"); rejected = NO;
    @try { (void)hideProposal(encode(@[own[@"location"],own,own[@"location"],own])); } @catch (NSException *e) { (void)e; rejected = YES; }
    require(rejected, @"Duplicate owner test");
    NSData *absent = encode(@[other[@"location"],other]);
    NSData *inserted = hideProposal(absent);
    require([restoration(inserted,absent,inserted) isEqual:absent], @"Absent row exact inverse test");
    changed = [decode(inserted) mutableCopy]; changed[1] = row(@"example.unrelated", NO);
    NSArray *removed = decode(restoration(encode(changed),absent,inserted));
    require(removed.count == 2 && ![removed[1][@"isAllowed"] boolValue], @"Absent row preserves other edits test");
    require([restoration(absent,absent,inserted) isEqual:absent], @"Already removed test");
    puts("PASS: 9 checks including absent-row insertion and exact removal");
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc == 2 && strcmp(argv[1], "--self-test") == 0) { tests(); return 0; }
        if (argc == 4 && strcmp(argv[1], "--read-state") == 0) {
            @try {
                require(NSProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27, @"OS differs");
                NSURL *file = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[2]]];
                NSString *expected = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Group Containers/group.com.apple.controlcenter/Library/Preferences/group.com.apple.controlcenter.plist"];
                require([file.URLByStandardizingPath.URLByResolvingSymlinksInPath.path isEqual:expected], @"Unexpected read target");
                Method m = class_getInstanceMethod(NSUserDefaults.class, @selector(_initWithSuiteName:container:));
                require(m && strcmp(method_getTypeEncoding(m), "@32@0:8@16@24") == 0, @"Container ABI differs");
                NSData *before = [NSData dataWithContentsOfURL:file];
                NSDictionary *plist = decode(before);
                require([plist isKindOfClass:NSDictionary.class], @"Expected preference dictionary");
                NSUserDefaults *defaults = [[NSUserDefaults alloc] _initWithSuiteName:@"group.com.apple.controlcenter" container:file.URLByDeletingLastPathComponent.URLByDeletingLastPathComponent.URLByDeletingLastPathComponent];
                id value = plist[key];
                require([value isKindOfClass:NSData.class] && [value isEqual:[defaults objectForKey:key]], @"Fresh API/file disagreement");
                require([before isEqual:[NSData dataWithContentsOfURL:file]], @"File changed during fresh read");
                save(encode(@{@"trackedData":value}), [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[3]]]);
                return 0;
            } @catch (NSException *exception) { NSLog(@"Read-only verifier: %@", exception.reason); return 3; }
        }
        if (argc < 3 || argc > 4 || NSProcessInfo.processInfo.operatingSystemVersion.majorVersion != 27) return 2;
        Trial *delegate = Trial.new;
        delegate.output = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]] isDirectory:YES];
        delegate.bookmark = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[2]]];
        delegate.recoveryOnly = argc == 4 && strcmp(argv[3], "--restore") == 0;
        if (argc == 4 && !delegate.recoveryOnly) return 2;
        require([NSFileManager.defaultManager createDirectoryAtURL:delegate.output withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:nil], @"Cannot create private evidence directory");
        NSApplication *app = NSApplication.sharedApplication; app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular]; [app run];
    }
    return 0;
}
