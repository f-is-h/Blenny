// Read-only contract inventory. Never creates an assertion or an XPC connection.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sys/sysctl.h>

static BOOL printClass(const char *name) {
    Class cls = objc_getClass(name);
    if (cls == Nil) { fprintf(stderr, "Missing class: %s\n", name); return NO; }
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    for (unsigned int i = 0; i < count; i++) {
        printf("class %s %s %s\n", name, sel_getName(method_getName(methods[i])),
               method_getTypeEncoding(methods[i]));
    }
    free(methods);
    return YES;
}

static BOOL printProtocol(const char *name) {
    Protocol *protocol = objc_getProtocol(name);
    if (protocol == nil) { fprintf(stderr, "Missing protocol: %s\n", name); return NO; }
    for (int required = 0; required < 2; required++) {
        unsigned int count = 0;
        struct objc_method_description *methods = protocol_copyMethodDescriptionList(
            protocol, required != 0, YES, &count);
        for (unsigned int i = 0; i < count; i++) {
            printf("protocol %s %s %s\n", name, sel_getName(methods[i].name),
                   methods[i].types);
        }
        free(methods);
    }
    return YES;
}

int main(void) {
    @autoreleasepool {
        if (NSProcessInfo.processInfo.operatingSystemVersion.majorVersion != 27) {
            fprintf(stderr, "This read-only investigation targets macOS 27.\n");
            return 2;
        }
        char build[128] = {0};
        size_t size = sizeof(build);
        if (sysctlbyname("kern.osversion", build, &size, NULL, 0) != 0) return 2;
        printf("OS build: %s\n", build);
        void *framework = dlopen(
            "/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore",
            RTLD_NOW | RTLD_LOCAL);
        if (!framework) { fprintf(stderr, "%s\n", dlerror()); return 2; }
        BOOL complete = YES;
        complete &= printClass("MBAssessmentModeConfiguration");
        complete &= printClass("MBAssessmentModeAssertion");
        complete &= printClass("MBUserSessionTransitionAssertion");
        complete &= printProtocol("MBVisibilityRestrictionXPCClient");
        complete &= printProtocol("MBVisibilityRestrictionXPCServer");
        // Keep runtime metadata mapped through process exit; no objects are instantiated.
        return complete ? 0 : 2;
    }
}
