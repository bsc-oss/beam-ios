//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Foundation

// PG_CHANGED
/// Checks whether a file type is blocked based on MIME type or file extension.
/// Blocked file types cannot be shared or downloaded for security reasons.
enum FileTypeBlocklist {
    // MARK: - Blocked MIME Types

    private static let blockedMIMETypes: Set = [
        "application/x-msdownload",
        "application/x-executable",
        "application/x-msdos-program",
        "application/x-msi",
        "application/x-sh",
        "application/x-bash",
        "application/java-archive",
        "application/vnd.android.package-archive",
        "application/x-apple-diskimage",
        "application/x-iso9660-image",
        "application/hta",
        "application/x-ms-shortcut",
        "application/vnd.ms-cab-compressed"
    ]

    // MARK: - Blocked Extensions

    private static let blockedExtensions: Set = [
        // Windows executables
        ".exe", ".bat", ".cmd", ".com", ".msi", ".msp", ".mst", ".dll", ".scr",

        // Windows script files
        ".pif", ".cpl", ".gadget", ".ps1", ".ps1xml", ".ps2", ".psc1", ".psc2",
        ".vbs", ".vbe", ".js", ".jse", ".ws", ".wsf", ".wsc", ".wsh", ".reg",

        // macOS/Linux executables & script files
        ".sh", ".bash", ".zsh", ".csh", ".ksh", ".app", ".command", ".osx",
        ".pkg", ".dmg", ".bin", ".run", ".elf", ".out", ".deb", ".rpm",

        // Mobile specific
        ".apk", ".aab", ".ipa", ".xapk", ".apks",

        // Microsoft Office Macro-Enabled Files
        ".docm", ".xlsm", ".pptm", ".dotm", ".xltm", ".potm", ".xlam", ".ppam",

        // Other dangerous formats
        ".jar", ".jnlp", ".hta", ".lnk", ".inf", ".iso", ".img", ".vhd", ".vhdx",
        ".cab", ".chm", ".appref-ms", ".application"
    ]

    // MARK: - Public API

    /// Returns `true` if the file is blocked based on its MIME type or filename extension.
    /// - Parameters:
    ///   - mimeType: The MIME type of the file (e.g. `"application/x-msdownload"`).
    ///   - filename: The filename including extension (e.g. `"malware.exe"`).
    /// - Returns: `true` if the file type is blocked.
    static func isBlocked(mimeType: String?, filename: String?) -> Bool {
        if let mimeType, blockedMIMETypes.contains(mimeType.lowercased()) {
            return true
        }

        if let ext = fileExtension(from: filename), blockedExtensions.contains(ext) {
            return true
        }

        return false
    }

    /// Extracts the lowercased file extension (including the leading dot) from a filename.
    /// - Parameter filename: The filename (e.g. `"document.exe"`).
    /// - Returns: The extension with leading dot (e.g. `".exe"`), or `nil` if none found.
    static func fileExtension(from filename: String?) -> String? {
        guard let filename, let dotIndex = filename.lastIndex(of: ".") else { return nil }
        let ext = String(filename[dotIndex...]).lowercased()
        guard ext.count > 1 else { return nil } // Just a dot
        return ext
    }
}
