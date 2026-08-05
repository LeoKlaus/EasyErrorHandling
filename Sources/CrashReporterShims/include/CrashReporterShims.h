//
//  CrashReporterShims.h
//  CrashReporterShims
//
//  `arm_thread_state64_get_pc`/`_get_lr`/`_get_fp`/`_get_sp` (in <mach/arm/thread_status.h>) are
//  C macros, not functions — Swift's ClangImporter never imports function-like macros as callable
//  Swift symbols. On arm64e devices, the raw `__pc`/`__lr`/`__fp`/`__sp` struct fields returned by
//  `thread_get_state` carry pointer-authentication signature bits mixed into the address; these
//  macros exist specifically to strip them correctly, with different `#if`-guarded
//  implementations depending on platform/config. These `static inline` wrappers give Swift real,
//  callable functions that still expand to the same macros, compiled with whichever branch the
//  target platform selects.
//

#ifndef CrashReporterShims_h
#define CrashReporterShims_h

#include <mach/arm/thread_status.h>
#include <stdint.h>

static inline uint64_t CrashReporterGetPC(arm_thread_state64_t state) {
    return (uint64_t)arm_thread_state64_get_pc(state);
}

static inline uint64_t CrashReporterGetLR(arm_thread_state64_t state) {
    return (uint64_t)arm_thread_state64_get_lr(state);
}

static inline uint64_t CrashReporterGetFP(arm_thread_state64_t state) {
    return (uint64_t)arm_thread_state64_get_fp(state);
}

static inline uint64_t CrashReporterGetSP(arm_thread_state64_t state) {
    return (uint64_t)arm_thread_state64_get_sp(state);
}

#endif /* CrashReporterShims_h */
