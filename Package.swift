// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickRightMenu",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "QuickRightMenu", targets: ["QuickRightMenu"]),
        .executable(name: "QuickRightMenuExtension", targets: ["QuickRightMenuExtension"]),
    ],
    targets: [
        .target(
            name: "QuickRightMenuShared",
            path: "Sources/Shared"
        ),
        .executableTarget(
            name: "QuickRightMenu",
            dependencies: [
                "QuickRightMenuShared"
            ],
            path: "Sources/App"
        ),
        .executableTarget(
            name: "QuickRightMenuExtension",
            dependencies: [
                "QuickRightMenuShared"
            ],
            path: "Sources/FinderExtension"
        ),
    ]
)
