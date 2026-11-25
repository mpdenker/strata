// swift-tools-version: 6.0
// LessonKit: the app's pure logic (content models, loader, validator; later Leitner + streak).
// No UI and no third-party dependencies, so it builds and tests with `swift test` on a Mac in seconds.
import PackageDescription

let package = Package(
    name: "LessonKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LessonKit", targets: ["LessonKit"]),
        .executable(name: "validate-lessons", targets: ["validate-lessons"]),
    ],
    targets: [
        .target(name: "LessonKit"),
        .executableTarget(name: "validate-lessons", dependencies: ["LessonKit"]),
        .testTarget(
            name: "LessonKitTests",
            dependencies: ["LessonKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
