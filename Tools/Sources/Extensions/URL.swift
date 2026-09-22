import ArgumentParser
import Foundation

extension URL {
    static var projectDirectory: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    static var parentDirectory: URL {
        .projectDirectory.deletingLastPathComponent()
    }

    // PG_CHANGED
    static var sdkDirectory: URL {
        .parentDirectory.appendingPathComponent("rust-sdk/pg-rust-sdk")
    }
}
