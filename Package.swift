// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SMPFrameworkRGS",
    platforms: [
        // Add support for all platforms starting from a specific version.
        .iOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "SMPFrameworkRGS",
            targets: ["SMPFrameworkRGSSwift", "SMPFrameworkRGSObjective"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
//        .package(url: "https://github.com/ReactiveX/RxSwift.git", .exact("6.2.0")),
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.2.0")),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "4.0.0"),
//        .package(url: "https://github.com/alexpiezo/WebRTC.git", from: "1.0.0"),
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "3.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SMPFrameworkRGSSwift",
            dependencies: ["SMPFrameworkRGSObjective", "Alamofire", "SwiftyJSON", "WebRTCLocal", "Starscream"],
            linkerSettings: [
              .linkedFramework("Foundation"),
              .linkedFramework("CoreTelephony"),
              .linkedFramework("SystemConfiguration"),
            ]),
        .target(
            name: "SMPFrameworkRGSObjective",
            dependencies: ["WebRTCLocal"],
//            path: "Sources/SMPFrameworkRGSObjective"
            publicHeadersPath: "Frameworks/"
            ),
        .binaryTarget(
            name: "WebRTCLocal",
            path: "frame/WebRTC.xcframework"
        ),
    ]
)
