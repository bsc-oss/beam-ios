//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import XCTest

final class FileTypeBlocklistTests: XCTestCase {
    // MARK: - MIME Type Blocking

    func testBlockedMIMETypes() {
        let blockedMIMETypes = [
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

        for mimeType in blockedMIMETypes {
            XCTAssertTrue(FileTypeBlocklist.isBlocked(mimeType: mimeType, filename: nil),
                          "MIME type \(mimeType) should be blocked")
        }
    }

    func testBlockedMIMETypesAreCaseInsensitive() {
        XCTAssertTrue(FileTypeBlocklist.isBlocked(mimeType: "Application/X-MsDownload", filename: nil))
        XCTAssertTrue(FileTypeBlocklist.isBlocked(mimeType: "APPLICATION/VND.ANDROID.PACKAGE-ARCHIVE", filename: nil))
    }

    func testSafeMIMETypesAreNotBlocked() {
        let safeMIMETypes = [
            "image/jpeg",
            "image/png",
            "application/pdf",
            "text/plain",
            "audio/mpeg",
            "video/mp4",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document" // .docx
        ]

        for mimeType in safeMIMETypes {
            XCTAssertFalse(FileTypeBlocklist.isBlocked(mimeType: mimeType, filename: nil),
                           "MIME type \(mimeType) should NOT be blocked")
        }
    }

    // MARK: - Extension Blocking

    func testBlockedWindowsExecutables() {
        let extensions = ["malware.exe", "script.bat", "script.cmd", "file.com", "installer.msi",
                          "patch.msp", "transform.mst", "library.dll", "screensaver.scr"]
        for filename in extensions {
            XCTAssertTrue(FileTypeBlocklist.isBlocked(mimeType: nil, filename: filename),
                          "\(filename) should be blocked")
        }
    }

    func testBlockedWindowsScripts() {
        let extensions = ["file.pif", "file.cpl", "file.gadget", "script.ps1", "script.ps1xml",
                          "script.ps2", "script.psc1", "script.psc2", "script.vbs", "script.vbe",
                          "script.js", "script.jse", "script.ws", "script.wsf", "script.wsc",
                          "script.wsh", "file.reg"]
        for filename in extensions {
            XCTAssertTrue(FileTypeBlocklist.isBlocked(mimeType: nil, filename: filename),
                          "\(filename) should be blocked")
        }
    }

    func testBlockedMacLinuxExecutables() {
        let extensions = ["script.sh", "script.bash", "script.zsh", "script.csh", "script.ksh",
                          "My.app", "script.command", "file.osx", "installer.pkg", "image.dmg",
                          "file.bin", "file.run", "file.elf", "file.out", "package.deb", "package.rpm"]
        for filename in extensions {
            XCTAssertTrue(FileTypeBlocklist.isBlocked(mimeType: nil, filename: filename),
                          "\(filename) should be blocked")
        }
    }

    func testBlockedMobileFiles() {
        let extensions = ["app.apk", "bundle.aab", "app.ipa", "app.xapk", "app.apks"]
        for filename in extensions {
            XCTAssertTrue(FileTypeBlocklist.isBlocked(mimeType: nil, filename: filename),
                          "\(filename) should be blocked")
        }
    }

    func testBlockedMacroFiles() {
        let extensions = ["doc.docm", "sheet.xlsm", "pres.pptm", "template.dotm",
                          "template.xltm", "template.potm", "addin.xlam", "addin.ppam"]
        for filename in extensions {
            XCTAssertTrue(FileTypeBlocklist.isBlocked(mimeType: nil, filename: filename),
                          "\(filename) should be blocked")
        }
    }

    func testBlockedOtherDangerousFormats() {
        let extensions = ["file.jar", "file.jnlp", "file.hta", "shortcut.lnk", "file.inf",
                          "disc.iso", "disc.img", "disk.vhd", "disk.vhdx", "archive.cab",
                          "help.chm", "ref.appref-ms", "app.application"]
        for filename in extensions {
            XCTAssertTrue(FileTypeBlocklist.isBlocked(mimeType: nil, filename: filename),
                          "\(filename) should be blocked")
        }
    }

    func testExtensionsAreCaseInsensitive() {
        XCTAssertTrue(FileTypeBlocklist.isBlocked(mimeType: nil, filename: "malware.EXE"))
        XCTAssertTrue(FileTypeBlocklist.isBlocked(mimeType: nil, filename: "image.DMG"))
        XCTAssertTrue(FileTypeBlocklist.isBlocked(mimeType: nil, filename: "script.Sh"))
        XCTAssertTrue(FileTypeBlocklist.isBlocked(mimeType: nil, filename: "app.APK"))
    }

    func testSafeExtensionsAreNotBlocked() {
        let safeFiles = ["document.pdf", "photo.jpg", "photo.png", "report.docx",
                         "spreadsheet.xlsx", "presentation.pptx", "music.mp3",
                         "video.mp4", "archive.zip", "data.json", "page.html",
                         "style.css", "readme.txt"]
        for filename in safeFiles {
            XCTAssertFalse(FileTypeBlocklist.isBlocked(mimeType: nil, filename: filename),
                           "\(filename) should NOT be blocked")
        }
    }

    // MARK: - Edge Cases

    func testNilInputsAreNotBlocked() {
        XCTAssertFalse(FileTypeBlocklist.isBlocked(mimeType: nil, filename: nil))
    }

    func testFilenameWithoutExtensionIsNotBlocked() {
        XCTAssertFalse(FileTypeBlocklist.isBlocked(mimeType: nil, filename: "noextension"))
    }

    func testFilenameWithDotOnlyIsNotBlocked() {
        XCTAssertFalse(FileTypeBlocklist.isBlocked(mimeType: nil, filename: "file."))
    }

    func testMIMETypeBlocksEvenWithSafeExtension() {
        // If mime type is blocked, the file should be blocked regardless of extension
        XCTAssertTrue(FileTypeBlocklist.isBlocked(mimeType: "application/x-msdownload", filename: "file.txt"))
    }

    func testExtensionBlocksEvenWithSafeMIMEType() {
        // If extension is blocked, the file should be blocked regardless of MIME type
        XCTAssertTrue(FileTypeBlocklist.isBlocked(mimeType: "text/plain", filename: "script.exe"))
    }

    func testFilenameWithMultipleDots() {
        XCTAssertTrue(FileTypeBlocklist.isBlocked(mimeType: nil, filename: "archive.tar.exe"))
        XCTAssertFalse(FileTypeBlocklist.isBlocked(mimeType: nil, filename: "my.file.pdf"))
    }

    // MARK: - File Extension Extraction

    func testFileExtensionExtraction() {
        XCTAssertEqual(FileTypeBlocklist.fileExtension(from: "test.exe"), ".exe")
        XCTAssertEqual(FileTypeBlocklist.fileExtension(from: "test.PDF"), ".pdf")
        XCTAssertEqual(FileTypeBlocklist.fileExtension(from: "archive.tar.gz"), ".gz")
        XCTAssertNil(FileTypeBlocklist.fileExtension(from: "noextension"))
        XCTAssertNil(FileTypeBlocklist.fileExtension(from: nil))
        XCTAssertNil(FileTypeBlocklist.fileExtension(from: "file."))
    }
}
