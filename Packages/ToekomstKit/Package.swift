// swift-tools-version: 5.9
import PackageDescription

// ToekomstKit holds everything in Toekomst that does not depend on UIKit or
// SwiftUI: the domain models (shaped like the back-end API), the repository
// protocol with its fixture-backed implementation, and the pure training logic
// (week planning, readiness, the workout engine, session results).
//
// It builds on Linux too, so `swift test` runs the logic tests without Xcode.
let package = Package(
    name: "ToekomstKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ToekomstKit", targets: ["ToekomstKit"])
    ],
    targets: [
        .target(
            name: "ToekomstKit",
            resources: [.process("Fixtures")]
        ),
        .testTarget(
            name: "ToekomstKitTests",
            dependencies: ["ToekomstKit"]
        )
    ]
)
