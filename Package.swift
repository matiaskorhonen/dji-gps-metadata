// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "DJIMetadataFixer",
  platforms: [
    .macOS(.v12)
  ],
  products: [],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.4.0"),
    .package(url: "https://github.com/apple/swift-testing.git", branch: "main"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .executableTarget(
      name: "DJIMetadataFixer",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ],
      path: "Sources"
    ),
    .testTarget(
      name: "DJIMetadataFixerTests",
      dependencies: [
        "DJIMetadataFixer",
        .product(name: "Testing", package: "swift-testing"),
      ]),
  ]
)
