#if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
.text
.align 2
.globl _blenny_swift_call_shared
_blenny_swift_call_shared:
    pacibsp
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x16, x0
    blr x16
    ldp x29, x30, [sp], #16
    retab

.align 2
.globl _blenny_swift_call_bool_getter
_blenny_swift_call_bool_getter:
    pacibsp
    stp x20, x19, [sp, #-32]!
    stp x29, x30, [sp, #16]
    add x29, sp, #16
    mov x16, x0
    mov x20, x1
    blr x16
    ldp x29, x30, [sp, #16]
    ldp x20, x19, [sp], #32
    retab

.align 2
.globl _blenny_swift_call_bool_setter
_blenny_swift_call_bool_setter:
    pacibsp
    stp x20, x19, [sp, #-32]!
    stp x29, x30, [sp, #16]
    add x29, sp, #16
    mov x16, x0
    mov x20, x1
    mov x0, x2
    blr x16
    ldp x29, x30, [sp, #16]
    ldp x20, x19, [sp], #32
    retab
#endif
