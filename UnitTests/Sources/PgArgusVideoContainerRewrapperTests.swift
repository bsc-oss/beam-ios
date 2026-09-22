//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
@testable import ElementX
import Foundation
import Testing

@MainActor
struct PgArgusVideoContainerRewrapperTests {
    @Test
    func detectsQuickTimeBrand() throws {
        let quickTime = try makeFile(header: "qt  ")
        defer { try? FileManager.default.removeItem(at: quickTime) }
        let mp4 = try makeFile(header: "mp42")
        defer { try? FileManager.default.removeItem(at: mp4) }
        let tiny = try makeFile(bytes: Data([1, 2, 3]))
        defer { try? FileManager.default.removeItem(at: tiny) }

        #expect(PgArgusVideoContainerRewrapper.isQuickTimeContainer(quickTime))
        #expect(!PgArgusVideoContainerRewrapper.isQuickTimeContainer(mp4))
        #expect(!PgArgusVideoContainerRewrapper.isQuickTimeContainer(tiny))
    }

    @Test
    func leavesFilesThatNeedNoRewrapAlone() async throws {
        let mp4 = try makeFile(header: "mp42")
        defer { try? FileManager.default.removeItem(at: mp4) }
        let quickTimeImage = try makeFile(header: "qt  ")
        defer { try? FileManager.default.removeItem(at: quickTimeImage) }

        // A real MP4 passes through untouched.
        #expect(try await PgArgusVideoContainerRewrapper.mp4Copy(of: mp4, declaredMimeType: "video/mp4") == nil)
        // Only files the app declared as MP4 are rewrapped; other declarations are trusted as is.
        #expect(try await PgArgusVideoContainerRewrapper.mp4Copy(of: quickTimeImage, declaredMimeType: "image/png") == nil)
    }

    @Test
    func rewrapsQuickTimeRecordingAsMP4() async throws {
        let recording = try await makeQuickTimeRecording()
        defer { try? FileManager.default.removeItem(at: recording) }
        #expect(PgArgusVideoContainerRewrapper.isQuickTimeContainer(recording))

        let copy = try #require(await PgArgusVideoContainerRewrapper.mp4Copy(of: recording, declaredMimeType: "video/mp4"))
        defer { try? FileManager.default.removeItem(at: copy) }

        #expect(copy != recording)
        #expect(copy.pathExtension == "mp4")
        #expect(!PgArgusVideoContainerRewrapper.isQuickTimeContainer(copy))
        // The source is left for its owner (the React Native side) to clean up.
        #expect(FileManager.default.fileExists(atPath: recording.path))
    }

    @Test
    func uploadHandlerSendsTheRewrappedCopy() async throws {
        let recording = try await makeQuickTimeRecording()
        defer { try? FileManager.default.removeItem(at: recording) }

        let clientProxy = ClientProxyMock(.init())
        var uploadedURL: URL?
        var uploadedWasQuickTime: Bool?
        clientProxy.uploadArgusFileFileNameFieldsClosure = { media, _, _ in
            uploadedURL = media.url
            uploadedWasQuickTime = PgArgusVideoContainerRewrapper.isQuickTimeContainer(media.url)
            return .success("file-video")
        }

        let message: [String: Any?] = [
            "type": PgArgusFeature.uploadFile.requestType,
            "requestId": "req-video",
            "payload": #"{"path":"\#(recording.path)","fileName":"clip.mp4","mimeType":"video/mp4"}"#
        ]
        let envelope = try #require(PgArgusBridgeEnvelope(message: message))
        let response = await PgArgusFileUploadHandler(clientProxy: clientProxy).handleMessage(message, envelope: envelope)

        #expect(response.fileID == "file-video")
        #expect(response.error == nil)
        let sentURL = try #require(uploadedURL)
        #expect(sentURL != recording)
        #expect(uploadedWasQuickTime == false)
        // The temporary copy is removed once the upload has settled.
        #expect(!FileManager.default.fileExists(atPath: sentURL.path))
    }

    // MARK: - Helpers

    private func makeFile(header brand: String) throws -> URL {
        var bytes = Data([0, 0, 0, 20])
        bytes.append(Data("ftyp".utf8))
        bytes.append(Data(brand.utf8))
        bytes.append(Data([0, 0, 0, 0]))
        bytes.append(Data(brand.utf8))
        return try makeFile(bytes: bytes)
    }

    private func makeFile(bytes: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try bytes.write(to: url)
        return url
    }

    /// Writes a short H.264 QuickTime movie the way `AVCaptureMovieFileOutput` would, but with
    /// an `.mp4` extension, mirroring what vision-camera hands the app for `fileType: 'mp4'`.
    private func makeQuickTimeRecording() async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let width = 64
        let height = 64
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ])
        writer.add(input)

        #expect(writer.startWriting())
        writer.startSession(atSourceTime: .zero)

        let pool = try #require(adaptor.pixelBufferPool)
        for frame in 0..<5 {
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
            let buffer = try #require(pixelBuffer)
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 10)))
        }

        input.markAsFinished()
        await writer.finishWriting()
        #expect(writer.status == .completed, "\(String(describing: writer.error))")
        return url
    }
}
