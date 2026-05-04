// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SlapBook",
    platforms: [
        .macOS(.v13)  // macOS 13.0 Ventura 及以上
    ],
    products: [
        .executable(
            name: "SlapBook",
            targets: ["SlapBook"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SlapBook",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("../../Resources")  // 包含音效资源
            ],
            swiftSettings: [
                .define("SWIFT_PACKAGE")
            ],
            linkerSettings: [
                .linkedFramework("CoreMotion"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("Foundation")
            ]
        )
    ]
)
