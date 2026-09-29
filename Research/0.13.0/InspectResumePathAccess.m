#if !DEBUG
#error This unsupported research probe must only be compiled with DEBUG=1.
#endif

#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <errno.h>
#import <inttypes.h>
#import <libproc.h>
#import <sys/sysctl.h>

typedef int (*SandboxCheck)(pid_t, const char *, int, ...);

static int emitJSON(NSDictionary *value) {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:value
                                                  options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                    error:&error];
    if (!data) {
        fprintf(stderr, "Cannot serialize result.\n");
        return 2;
    }
    fwrite(data.bytes, 1, data.length, stdout);
    fputc('\n', stdout);
    return 0;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        fprintf(stderr, "Unsupported read-only research; no system writes. Keep raw output in LocalData.\n");
        char build[64] = {0};
        size_t buildSize = sizeof(build);
        if (NSProcessInfo.processInfo.operatingSystemVersion.majorVersion != 27 ||
            sysctlbyname("kern.osversion", build, &buildSize, NULL, 0) != 0 ||
            strcmp(build, "26A428") != 0) {
            fprintf(stderr, "Refusing an uninspected macOS build.\n");
            return 2;
        }

        if (argc == 2 && strcmp(argv[1], "--own-bundle") == 0) {
            NSBundle *bundle = NSBundle.mainBundle;
            NSString *identifier = bundle.bundleIdentifier;
            if (identifier.length == 0) {
                fprintf(stderr, "Run this mode from the disposable probe bundle executable.\n");
                return 2;
            }
            return emitJSON(@{@"osBuild": @(build),
                              @"ownBundleIdentifier": identifier,
                              @"ownBundlePath": bundle.bundlePath,
                              @"createsStatusItem": @NO});
        }

        if (argc < 4 || argc > 19 || strcmp(argv[1], "--reader-pid") != 0) {
            fprintf(stderr, "Usage: probe --reader-pid MENU_BAR_AGENT_PID ABSOLUTE_DIRECTORY...\n");
            return 2;
        }
        char *end = NULL;
        errno = 0;
        intmax_t parsedPID = strtoimax(argv[2], &end, 10);
        if (errno != 0 || end == argv[2] || *end != '\0' || parsedPID <= 0 || parsedPID > INT32_MAX) {
            fprintf(stderr, "Invalid reader PID.\n");
            return 2;
        }
        pid_t readerPID = (pid_t)parsedPID;
        char readerPath[PROC_PIDPATHINFO_MAXSIZE] = {0};
        if (proc_pidpath(readerPID, readerPath, sizeof(readerPath)) <= 0 ||
            strcmp(readerPath, "/System/Library/CoreServices/MenuBarAgent.app/Contents/MacOS/MenuBarAgent") != 0) {
            fprintf(stderr, "Reader is not the inspected MenuBarAgent executable.\n");
            return 2;
        }
        for (int index = 3; index < argc; index++) {
            if (argv[index][0] != '/' || ![NSString stringWithUTF8String:argv[index]]) {
                fprintf(stderr, "Every directory must be an absolute UTF-8 path.\n");
                return 2;
            }
        }

        SandboxCheck check = (SandboxCheck)dlsym(RTLD_DEFAULT, "sandbox_check");
        const int *noReport = dlsym(RTLD_DEFAULT, "SANDBOX_CHECK_NO_REPORT");
        if (!check || !noReport || *noReport != (1 << 30)) {
            fprintf(stderr, "Refusing a changed sandbox query contract.\n");
            return 2;
        }
        // The inspected BaseBoard helper uses path filter 1 and file-read-data.
        // This queries the reader's access, not this probe's file permissions.
        const int inspectedPathFilter = 1;
        NSMutableArray *results = [NSMutableArray array];
        for (int index = 3; index < argc; index++) {
            errno = 0;
            int result = check(readerPID, "file-read-data", *noReport | inspectedPathFilter, argv[index]);
            int queryError = errno;
            if ((result != 0 && result != 1) || queryError != 0) {
                fprintf(stderr, "Sandbox query failed; no permission conclusion emitted.\n");
                return 2;
            }
            [results addObject:@{@"directory": @(argv[index]),
                                 @"sandboxResult": @(result),
                                 @"readerMayRead": result == 0 ? @YES : @NO}];
        }
        return emitJSON(@{@"osBuild": @(build),
                          @"readerPID": @(readerPID),
                          @"readerExecutable": @(readerPath),
                          @"operation": @"file-read-data",
                          @"pathFilter": @(inspectedPathFilter),
                          @"noReport": @(*noReport),
                          @"results": results});
    }
}
