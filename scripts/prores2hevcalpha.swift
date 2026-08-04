#!/usr/bin/env swift
//
// prores2hevcalpha.swift
//
// Transcodes a ProRes 4444 (or any alpha-carrying) video into HEVC-with-alpha
// using Apple's own AVAssetReader/AVAssetWriter path (AVVideoCodecType.hevcWithAlpha),
// NOT ffmpeg's hevc_videotoolbox, whose alpha is advertised but ignored by AVPlayerLayer.
//
// Usage:
//   swift prores2hevcalpha.swift <input.mov> <output.mov> [quality]
//     quality: optional Double 0.0-1.0, default 0.9. Maps to
//              kVTCompressionPropertyKey_TargetQualityForAlpha.
//
import Foundation
import AVFoundation
import VideoToolbox
import CoreMedia

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(("ERROR: " + msg + "\n").data(using: .utf8)!)
    exit(1)
}

// MARK: - Argument parsing

let args = CommandLine.arguments
guard args.count >= 3 else {
    fail("Usage: swift prores2hevcalpha.swift <input.mov> <output.mov> [quality 0.0-1.0]")
}

let inputPath = args[1]
let outputPath = args[2]
var quality: Double = 0.9
if args.count >= 4 {
    guard let q = Double(args[3]), q >= 0.0, q <= 1.0 else {
        fail("quality must be a Double between 0.0 and 1.0 (got '\(args[3])')")
    }
    quality = q
}

let inputURL = URL(fileURLWithPath: inputPath)
let outputURL = URL(fileURLWithPath: outputPath)

guard FileManager.default.fileExists(atPath: inputURL.path) else {
    fail("Input file does not exist: \(inputURL.path)")
}

if FileManager.default.fileExists(atPath: outputURL.path) {
    do {
        try FileManager.default.removeItem(at: outputURL)
    } catch {
        fail("Could not remove existing output file at \(outputURL.path): \(error.localizedDescription)")
    }
}

// MARK: - Load source asset / track

let asset = AVURLAsset(url: inputURL)

guard let videoTrack = asset.tracks(withMediaType: .video).first else {
    fail("No video track found in input: \(inputURL.path)")
}

let naturalSize = videoTrack.naturalSize
let width = Int(abs(naturalSize.width).rounded())
let height = Int(abs(naturalSize.height).rounded())
guard width > 0, height > 0 else {
    fail("Could not determine a valid frame size from source track (got \(naturalSize))")
}

let srcDurationSeconds = CMTimeGetSeconds(asset.duration)
let srcFrameCount = videoTrack.nominalFrameRate > 0
    ? Int((srcDurationSeconds * Double(videoTrack.nominalFrameRate)).rounded())
    : -1

print("Input:  \(inputURL.path)")
print("        \(width)x\(height), nominalFrameRate=\(videoTrack.nominalFrameRate), duration=\(String(format: "%.3f", srcDurationSeconds))s")
print("Output: \(outputURL.path)  (TargetQualityForAlpha=\(quality))")

// MARK: - Reader

guard let reader = try? AVAssetReader(asset: asset) else {
    fail("Could not create AVAssetReader for \(inputURL.path)")
}

// Request 32BGRA from the reader so alpha survives decode as straight alpha.
let readerOutputSettings: [String: Any] = [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
]
let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerOutputSettings)
trackOutput.alwaysCopiesSampleData = false

guard reader.canAdd(trackOutput) else {
    fail("AVAssetReader cannot add track output with 32BGRA settings")
}
reader.add(trackOutput)

// MARK: - Writer

guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mov) else {
    fail("Could not create AVAssetWriter for \(outputURL.path)")
}

// kVTCompressionPropertyKey_TargetQualityForAlpha is available directly from
// VideoToolbox on macOS 10.15+ (confirmed present in this SDK), so no literal
// string fallback was needed.
let compressionProperties: [String: Any] = [
    kVTCompressionPropertyKey_TargetQualityForAlpha as String: quality
]

let videoSettings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.hevcWithAlpha,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: compressionProperties
]

guard writer.canApply(outputSettings: videoSettings, forMediaType: .video) else {
    fail("AVAssetWriter cannot apply hevcWithAlpha output settings (\(width)x\(height)) on this system")
}

let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
writerInput.expectsMediaDataInRealTime = false
writerInput.transform = videoTrack.preferredTransform // preserve source orientation

guard writer.canAdd(writerInput) else {
    fail("AVAssetWriter cannot add the configured video input")
}
writer.add(writerInput)

// MARK: - Run reader/writer session synchronously

guard reader.startReading() else {
    fail("Failed to start reading: \(reader.error?.localizedDescription ?? "unknown error")")
}

guard writer.startWriting() else {
    fail("Failed to start writing: \(writer.error?.localizedDescription ?? "unknown error")")
}
writer.startSession(atSourceTime: .zero)

let writerQueue = DispatchQueue(label: "prores2hevcalpha.writer.queue")
let doneSemaphore = DispatchSemaphore(value: 0)

var frameCount = 0
var lastPTS = CMTime.zero
var appendError: String?

writerInput.requestMediaDataWhenReady(on: writerQueue) {
    while writerInput.isReadyForMoreMediaData {
        if reader.status != .reading {
            writerInput.markAsFinished()
            doneSemaphore.signal()
            return
        }
        guard let sampleBuffer = trackOutput.copyNextSampleBuffer() else {
            // No more samples from the reader: we're done.
            writerInput.markAsFinished()
            doneSemaphore.signal()
            return
        }
        lastPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if !writerInput.append(sampleBuffer) {
            appendError = writer.error?.localizedDescription ?? "unknown append error"
            reader.cancelReading()
            writerInput.markAsFinished()
            doneSemaphore.signal()
            return
        }
        frameCount += 1
        if frameCount % 50 == 0 {
            print("  ...\(frameCount) frames encoded")
        }
    }
}

doneSemaphore.wait()

if let appendError = appendError {
    fail("Failed to append sample buffer at frame \(frameCount): \(appendError)")
}

if reader.status == .failed {
    fail("AVAssetReader failed: \(reader.error?.localizedDescription ?? "unknown error")")
}

let finishSemaphore = DispatchSemaphore(value: 0)
writer.finishWriting {
    finishSemaphore.signal()
}
finishSemaphore.wait()

guard writer.status == .completed else {
    fail("AVAssetWriter did not complete (status=\(writer.status.rawValue)): \(writer.error?.localizedDescription ?? "unknown error")")
}

if frameCount == 0 {
    fail("No frames were written; refusing to report success on an empty output")
}

if srcFrameCount > 0 && frameCount != srcFrameCount {
    FileHandle.standardError.write(("WARNING: source nominally has \(srcFrameCount) frames but wrote \(frameCount)\n").data(using: .utf8)!)
}

// MARK: - Summary

let outAsset = AVURLAsset(url: outputURL)
let outDuration = CMTimeGetSeconds(outAsset.duration)
let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
let fileSize = (attrs?[.size] as? NSNumber)?.int64Value ?? 0

print("Done.")
print("  Frames written:   \(frameCount)")
print("  Output duration:  \(String(format: "%.3f", outDuration))s")
print("  Output file size: \(fileSize) bytes (\(String(format: "%.2f", Double(fileSize) / 1_048_576.0)) MB)")

exit(0)
