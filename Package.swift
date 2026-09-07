// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "LinePrinter",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_14)
    ],
    products: [
        .library(
            name: "LinePrinter",
            targets: ["LinePrinter"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LinePrinter",
            dependencies: [],
            path: "LinePrinter/Sources"
        )
    ]
)
