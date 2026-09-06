#ifndef BLENNY_PRIVATE_ABI_SHIM_H
#define BLENNY_PRIVATE_ABI_SHIM_H

#include <stdbool.h>

void *blenny_swift_call_shared(void *function);
bool blenny_swift_call_bool_getter(void *function, void *object);
void blenny_swift_call_bool_setter(void *function, void *object, bool value);

#endif
