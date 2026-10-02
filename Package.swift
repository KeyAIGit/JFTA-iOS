// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "JFTACore", platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "JFTACore", targets: ["JFTACore"])],
    targets: [.target(name: "JFTACore", path: "Core"),
              .testTarget(name: "JFTACoreTests", dependencies: ["JFTACore"], path: "Tests/JFTACoreTests")]
)
