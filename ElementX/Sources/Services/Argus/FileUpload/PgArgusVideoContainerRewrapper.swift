//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import Foundation

/// `AVCaptureMovieFileOutput` only ever writes QuickTime containers, whatever extension the
/// file carries, so an Argus camera capture declared as `video/mp4` arrives as a `.mp4`-named
/// `.mov`. Windows browsers need a real MP4, so the streams are rewrapped without re-encoding.
enum PgArgusVideoContainerRewrapper {
    /// Returns a temporary MP4 copy when the file is a QuickTime container declared as MP4,
    /// or `nil` when the file can be uploaded as is. The caller owns the returned file.
    static func mp4Copy(of url: URL, declaredMimeType: String) async throws -> URL? {
        guard declaredMimeType == "video/mp4", isQuickTimeContainer(url) else {
            return nil
        }
        
        let asset = AVURLAsset(url: url)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw PgArgusBridgeError.videoRewrapFailed
        }
        
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        do {
            try await session.export(to: output, as: .mp4)
        } catch {
            MXLog.error("Argus uploadFile failed to rewrap QuickTime recording as MP4: \(error)")
            try? FileManager.default.removeItem(at: output)
            throw PgArgusBridgeError.videoRewrapFailed
        }
        
        MXLog.info("Argus uploadFile rewrapped QuickTime recording as MP4")
        return output
    }
    
    /// Reads the leading `ftyp` box: a QuickTime file carries the `qt  ` major brand, whereas
    /// MP4 files carry an ISO brand such as `mp42` or `isom`.
    static func isQuickTimeContainer(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return false
        }
        defer { try? handle.close() }
        
        guard let header = try? handle.read(upToCount: 12), header.count == 12 else {
            return false
        }
        
        return header[4..<8] == Data("ftyp".utf8) && header[8..<12] == Data("qt  ".utf8)
    }
}
