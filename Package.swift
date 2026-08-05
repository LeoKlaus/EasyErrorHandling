// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EasyErrorHandling",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .watchOS(.v9),
        .tvOS(.v16)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        // CrashReporter/CrashReporterShims are bundled into this same product (rather than
        // getting their own) so a consuming Xcode target only ever needs to add one package
        // product dependency and can then `import` whichever of the three modules it needs.
        .library(
            name: "EasyErrorHandling",
            targets: ["EasyErrorHandling", "CrashReporter", "CrashReporterShims"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "EasyErrorHandling"
        ),
        .testTarget(
            name: "EasyErrorHandlingTests",
            dependencies: ["EasyErrorHandling"]
        ),
        // CrashReporterExtension's PC/LR/FP/SP accessors (mach/arm/thread_status.h) are C
        // macros, which Swift can't call directly — arm64e strips pointer-authentication bits
        // via a different macro implementation per platform. A plain C target with `static
        // inline` wrappers gives Swift real, callable functions without every consuming app
        // needing to configure a bridging header (a bridging header is per-Xcode-target, manual
        // config; a package target is just `import`-able).
        .target(
            name: "CrashReporterShims"
        ),
        // Everything portable for iOS 27's CrashReportExtension: stack walking, the on-disk
        // report format, and the SwiftUI display component. Gated `@available(iOS 27, ...)`
        // internally rather than raising the package's platform minimums, which would break
        // every other app depending on this package at an older deployment target.
        .target(
            name: "CrashReporter",
            dependencies: ["CrashReporterShims"]
        ),
    ]
)
