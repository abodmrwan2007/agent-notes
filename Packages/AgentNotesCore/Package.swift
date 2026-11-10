// swift-tools-version: 5.9
import PackageDescription

// Platform-neutral core: document model, package format, geometry, search normalization.
// Depends on Foundation only so it can be unit-tested with `swift test` on any Swift toolchain
// and so the same contracts can be mirrored by a future Android client.
let package = Package(
    name: "AgentNotesCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "AgentNotesCore", targets: ["AgentNotesCore"])
    ],
    targets: [
        .target(name: "AgentNotesCore"),
        .testTarget(name: "AgentNotesCoreTests", dependencies: ["AgentNotesCore"])
    ]
)
