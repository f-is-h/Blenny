// Manager-free, read-only Sparkle information check against the public feed.
// Never launch the Blenny executable or perform an installation from this probe.
#import <AppKit/AppKit.h>
#import <Sparkle/Sparkle.h>

@interface BlennyFeedProbe : NSObject <SPUUpdaterDelegate>
@property(nonatomic, copy) NSString *build;
@property(nonatomic, copy) NSString *version;
@property(nonatomic, copy) NSString *downloadURL;
@property(nonatomic) unsigned long long length;
@property(nonatomic) BOOL matched;
@end

@implementation BlennyFeedProbe
- (BOOL)updaterShouldPromptForPermissionToCheckForUpdates:(SPUUpdater *)updater { return NO; }
- (void)updater:(SPUUpdater *)updater didFinishLoadingAppcast:(SUAppcast *)appcast {
    NSUInteger matches = 0;
    for (SUAppcastItem *item in appcast.items) {
        if ([item.versionString isEqualToString:self.build] &&
            [item.displayVersionString isEqualToString:self.version] &&
            [item.fileURL.absoluteString isEqualToString:self.downloadURL] &&
            item.contentLength == self.length) {
            matches++;
        }
    }
    self.matched = matches == 1;
}
- (void)updaterDidNotFindUpdate:(SPUUpdater *)updater {
    if (!self.matched) { fprintf(stderr, "Public Sparkle metadata mismatch\n"); exit(65); }
    puts("Public Sparkle information check: PASS (current version; no installation)");
    exit(0);
}
- (void)updater:(SPUUpdater *)updater didFindValidUpdate:(SUAppcastItem *)item {
    fprintf(stderr, "Unexpected newer release during the serialized check\n"); exit(65);
}
- (void)updater:(SPUUpdater *)updater didFinishUpdateCycleForUpdateCheck:(SPUUpdateCheck)check error:(NSError *)error {
    if (error) { fprintf(stderr, "Sparkle information check failed\n"); exit(65); }
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 6 || strcmp(getenv("GITHUB_ACTIONS") ?: "", "true") != 0) { return 64; }
        [NSApplication sharedApplication];
        NSBundle *host = [NSBundle bundleWithPath:@(argv[1])];
        if (!host || ![host.bundleIdentifier isEqualToString:@"xyz.fi5h.blenny"]) { return 65; }
        BlennyFeedProbe *probe = [BlennyFeedProbe new];
        probe.build = @(argv[2]); probe.version = @(argv[3]);
        probe.downloadURL = @(argv[4]); probe.length = strtoull(argv[5], NULL, 10);
        SPUStandardUserDriver *driver = [[SPUStandardUserDriver alloc] initWithHostBundle:host delegate:nil];
        SPUUpdater *updater = [[SPUUpdater alloc] initWithHostBundle:host applicationBundle:host userDriver:driver delegate:probe];
        NSError *error = nil;
        if (![updater startUpdater:&error]) { return 65; }
        updater.automaticallyChecksForUpdates = NO;
        updater.automaticallyDownloadsUpdates = NO;
        [updater checkForUpdateInformation];
        [NSTimer scheduledTimerWithTimeInterval:55 repeats:NO block:^(NSTimer *timer) {
            fprintf(stderr, "Sparkle information check timed out\n"); exit(75);
        }];
        [NSRunLoop.currentRunLoop run];
    }
    return 65;
}
