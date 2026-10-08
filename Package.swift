// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Baeuja",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Baeuja", targets: ["Baeuja"]),
        .executable(name: "PackageApp", targets: ["PackageApp"]),
        .executable(name: "StudyQA", targets: ["StudyQA"]),
        .executable(name: "RunTests", targets: ["RunTests"]),
    ],
    targets: [
        .target(name: "StudyCore", resources: [.copy("Resources")]),
        .executableTarget(name: "Baeuja", dependencies: ["StudyCore"]),
        .executableTarget(name: "PackageApp"),
        .executableTarget(name: "StudyQA", dependencies: ["StudyCore"]),
        .executableTarget(name: "RunTests"),
        .testTarget(name: "StudyCoreTests", dependencies: ["StudyCore"]),
    ],
    swiftLanguageModes: [.v5]
)
