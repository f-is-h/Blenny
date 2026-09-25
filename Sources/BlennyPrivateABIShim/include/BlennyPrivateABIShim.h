#ifndef BLENNY_PRIVATE_ABI_SHIM_H
#define BLENNY_PRIVATE_ABI_SHIM_H

#include <stdbool.h>
#include <CoreFoundation/CoreFoundation.h>

CF_ASSUME_NONNULL_BEGIN

void * _Nullable blenny_swift_call_shared(void *function);
bool blenny_swift_call_bool_getter(void *function, void *object);
void blenny_swift_call_bool_setter(void *function, void *object, bool value);

#if DEBUG
bool blenny_menu_bar_ordering_supports_system_version(CFStringRef version);
bool blenny_write_menu_bar_ordering_table(
    CFDictionaryRef table,
    CFStringRef container_path,
    CFErrorRef _Nullable * _Nullable error_out
);
#endif

CF_ASSUME_NONNULL_END

#endif
