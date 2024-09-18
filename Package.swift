// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FalClient",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .macCatalyst(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
    ],
    products: [
        .library(
            name: "FalClient",
            targets: ["FalClient"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.71.0"),
        .package(url: "https://github.com/nnabeyang/swift-msgpack.git", from: "0.3.3"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.9.0")
    ],
    targets: [
        .target(
            name: "FalClient",
            dependencies: [
				.product(name: "NIOCore", package: "swift-nio"),
				.product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "SwiftMsgpack", package: "swift-msgpack"),
            ],
            path: "Sources/FalClient"
        )
    ]
)
