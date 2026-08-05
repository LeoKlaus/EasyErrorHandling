//
//  CrashReporterShims.c
//  CrashReporterShims
//
//  Every function this target exposes is `static inline`, defined entirely in
//  include/CrashReporterShims.h — there's nothing left to compile here. Swift Package Manager's
//  build system still expects at least one translation unit per C target to produce a linkable
//  object file, so this file exists purely to satisfy that.
//
