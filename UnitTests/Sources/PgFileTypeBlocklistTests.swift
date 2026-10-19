//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Testing

struct FileTypeBlocklistTests {
    // MARK: - MIME Type Blocking
    
    @Test
    func blockedMIMETypes() {
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
            #expect(FileTypeBlocklist.isBlocked(mimeType: mimeType, filename: nil),
                    "MIME type \(mimeType) should be blocked")
        }
    }
    
    @Test
    func blockedMIMETypesAreCaseInsensitive() {
        #expect(FileTypeBlocklist.isBlocked(mimeType: "Application/X-MsDownload", filename: nil))
        #expect(FileTypeBlocklist.isBlocked(mimeType: "APPLICATION/VND.ANDROID.PACKAGE-ARCHIVE", filename: nil))
    }
    
    @Test
    func safeMIMETypesAreNotBlocked() {
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
            #expect(!FileTypeBlocklist.isBlocked(mimeType: mimeType, filename: nil),
                    "MIME type \(mimeType) should NOT be blocked")
        }
    }
    
    // MARK: - Extension Blocking
    
    @Test
    func blockedWindowsExecutables() {
        let extensions = ["malware.exe", "script.bat", "script.cmd", "file.com", "installer.msi",
                          "patch.msp", "transform.mst", "library.dll", "screensaver.scr"]
        for filename in extensions {
            #expect(FileTypeBlocklist.isBlocked(mimeType: nil, filename: filename),
                    "\(filename) should be blocked")
        }
    }
    
    @Test
    func blockedWindowsScripts() {
        let extensions = ["file.pif", "file.cpl", "file.gadget", "script.ps1", "script.ps1xml",
                          "script.ps2", "script.psc1", "script.psc2", "script.vbs", "script.vbe",
                          "script.js", "script.jse", "script.ws", "script.wsf", "script.wsc",
                          "script.wsh", "file.reg"]
        for filename in extensions {
            #expect(FileTypeBlocklist.isBlocked(mimeType: nil, filename: filename),
                    "\(filename) should be blocked")
        }
    }
    
    @Test
    func blockedMacLinuxExecutables() {
        let extensions = ["script.sh", "script.bash", "script.zsh", "script.csh", "script.ksh",
                          "My.app", "script.command", "file.osx", "installer.pkg", "image.dmg",
                          "file.bin", "file.run", "file.elf", "file.out", "package.deb", "package.rpm"]
        for filename in extensions {
            #expect(FileTypeBlocklist.isBlocked(mimeType: nil, filename: filename),
                    "\(filename) should be blocked")
        }
    }
    
    @Test
    func blockedMobileFiles() {
        let extensions = ["app.apk", "bundle.aab", "app.ipa", "app.xapk", "app.apks"]
        for filename in extensions {
            #expect(FileTypeBlocklist.isBlocked(mimeType: nil, filename: filename),
                    "\(filename) should be blocked")
        }
    }
    
    @Test
    func blockedMacroFiles() {
        let extensions = ["doc.docm", "sheet.xlsm", "pres.pptm", "template.dotm",
                          "template.xltm", "template.potm", "addin.xlam", "addin.ppam"]
        for filename in extensions {
            #expect(FileTypeBlocklist.isBlocked(mimeType: nil, filename: filename),
                    "\(filename) should be blocked")
        }
    }
    
    @Test
    func blockedOtherDangerousFormats() {
        let extensions = ["file.jar", "file.jnlp", "file.hta", "shortcut.lnk", "file.inf",
                          "disc.iso", "disc.img", "disk.vhd", "disk.vhdx", "archive.cab",
                          "help.chm", "ref.appref-ms", "app.application"]
        for filename in extensions {
            #expect(FileTypeBlocklist.isBlocked(mimeType: nil, filename: filename),
                    "\(filename) should be blocked")
        }
    }
    
    @Test
    func extensionsAreCaseInsensitive() {
        #expect(FileTypeBlocklist.isBlocked(mimeType: nil, filename: "malware.EXE"))
        #expect(FileTypeBlocklist.isBlocked(mimeType: nil, filename: "image.DMG"))
        #expect(FileTypeBlocklist.isBlocked(mimeType: nil, filename: "script.Sh"))
        #expect(FileTypeBlocklist.isBlocked(mimeType: nil, filename: "app.APK"))
    }
    
    @Test
    func safeExtensionsAreNotBlocked() {
        let safeFiles = ["document.pdf", "photo.jpg", "photo.png", "report.docx",
                         "spreadsheet.xlsx", "presentation.pptx", "music.mp3",
                         "video.mp4", "archive.zip", "data.json", "page.html",
                         "style.css", "readme.txt"]
        for filename in safeFiles {
            #expect(!FileTypeBlocklist.isBlocked(mimeType: nil, filename: filename),
                    "\(filename) should NOT be blocked")
        }
    }
    
    // MARK: - Edge Cases
    
    @Test
    func nilInputsAreNotBlocked() {
        #expect(!FileTypeBlocklist.isBlocked(mimeType: nil, filename: nil))
    }
    
    @Test
    func filenameWithoutExtensionIsNotBlocked() {
        #expect(!FileTypeBlocklist.isBlocked(mimeType: nil, filename: "noextension"))
    }
    
    @Test
    func filenameWithDotOnlyIsNotBlocked() {
        #expect(!FileTypeBlocklist.isBlocked(mimeType: nil, filename: "file."))
    }
    
    @Test
    func mimeTypeBlocksEvenWithSafeExtension() {
        // If mime type is blocked, the file should be blocked regardless of extension
        #expect(FileTypeBlocklist.isBlocked(mimeType: "application/x-msdownload", filename: "file.txt"))
    }
    
    @Test
    func extensionBlocksEvenWithSafeMIMEType() {
        // If extension is blocked, the file should be blocked regardless of MIME type
        #expect(FileTypeBlocklist.isBlocked(mimeType: "text/plain", filename: "script.exe"))
    }
    
    @Test
    func filenameWithMultipleDots() {
        #expect(FileTypeBlocklist.isBlocked(mimeType: nil, filename: "archive.tar.exe"))
        #expect(!FileTypeBlocklist.isBlocked(mimeType: nil, filename: "my.file.pdf"))
    }
    
    // MARK: - File Extension Extraction
    
    @Test
    func fileExtensionExtraction() {
        #expect(FileTypeBlocklist.fileExtension(from: "test.exe") == ".exe")
        #expect(FileTypeBlocklist.fileExtension(from: "test.PDF") == ".pdf")
        #expect(FileTypeBlocklist.fileExtension(from: "archive.tar.gz") == ".gz")
        #expect(FileTypeBlocklist.fileExtension(from: "noextension") == nil)
        #expect(FileTypeBlocklist.fileExtension(from: nil) == nil)
        #expect(FileTypeBlocklist.fileExtension(from: "file.") == nil)
    }
}
