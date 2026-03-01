// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "DJIMetadataFixer",
  platforms: [
    .macOS(.v12)
  ],
  products: [
    .library(name: "DJIMetadataCore", targets: ["DJIMetadataCore"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.4.0"),
    .package(url: "https://github.com/apple/swift-testing.git", branch: "main"),
    .package(url: "https://github.com/matiaskorhonen/bamf.git", branch: "main"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "DJIMetadataCore",
      path: "Sources/Core"
    ),
    .executableTarget(
      name: "DJIMetadataFixer",
      dependencies: [
        "DJIMetadataCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Bamf", package: "bamf"),
      ],
      path: "Sources",
      exclude: ["Core"]
    ),
    .testTarget(
      name: "DJIMetadataFixerTests",
      dependencies: [
        "DJIMetadataCore",
        "DJIMetadataFixer",
        .product(name: "Testing", package: "swift-testing"),
      ],
      resources: [
        .copy("Resources")
      ]
    ),

  ],
  swiftLanguageModes: [
    .v6
  ]
)
