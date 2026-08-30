import AVFoundation
import CoreImage
import CoreVideo
import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  func testBlackAndWhiteLookIsBurnedIntoExportedVideo() throws {
    let input = temporaryURL("source.mov")
    let output = temporaryURL("filtered.mp4")
    try makeSolidRedVideo(at: input)

    let exported = expectation(description: "Live Look export")
    var processingError: Error?
    LiveLookVideoProcessor().process(
      inputURL: input,
      outputURL: output,
      look: "Black & White"
    ) { result in
      if case .failure(let error) = result { processingError = error }
      exported.fulfill()
    }
    wait(for: [exported], timeout: 20)
    XCTAssertNil(processingError)
    XCTAssertGreaterThan(try Data(contentsOf: output).count, 0)

    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: output))
    generator.appliesPreferredTrackTransform = true
    let frame = try generator.copyCGImage(
      at: CMTime(value: 1, timescale: 30),
      actualTime: nil
    )
    let pixel = rgbaPixel(from: frame)
    XCTAssertLessThan(abs(Int(pixel.0) - Int(pixel.1)), 12)
    XCTAssertLessThan(abs(Int(pixel.1) - Int(pixel.2)), 12)
  }

  func testFinalVideoProducesThreeBoundedJpegModerationFrames() throws {
    let input = temporaryURL("moderation-source.mov")
    try makeSolidRedVideo(at: input)

    let frames = try ModerationFrameExtractor().extract(inputURL: input)

    XCTAssertEqual(frames.count, 3)
    for frame in frames {
      XCTAssertGreaterThanOrEqual(frame.count, 256)
      XCTAssertLessThanOrEqual(frame.count, 1024 * 1024)
      XCTAssertEqual(Array(frame.prefix(2)), [0xff, 0xd8])
      XCTAssertEqual(Array(frame.suffix(2)), [0xff, 0xd9])
    }
  }

  private func temporaryURL(_ name: String) -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    return directory.appendingPathComponent(name)
  }

  private func makeSolidRedVideo(at url: URL) throws {
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: 64,
        AVVideoHeightKey: 64
      ]
    )
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: 64,
        kCVPixelBufferHeightKey as String: 64
      ]
    )
    XCTAssertTrue(writer.canAdd(input))
    writer.add(input)
    XCTAssertTrue(writer.startWriting())
    writer.startSession(atSourceTime: .zero)

    guard let pool = adaptor.pixelBufferPool else {
      XCTFail("Missing pixel buffer pool")
      return
    }
    for index in 0..<210 {
      var buffer: CVPixelBuffer?
      XCTAssertEqual(
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer),
        kCVReturnSuccess
      )
      guard let pixelBuffer = buffer else { continue }
      CVPixelBufferLockBaseAddress(pixelBuffer, [])
      if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        for y in 0..<64 {
          for x in 0..<64 {
            let offset = y * rowBytes + x * 4
            bytes[offset] = 0
            bytes[offset + 1] = 0
            bytes[offset + 2] = 255
            bytes[offset + 3] = 255
          }
        }
      }
      CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
      while !input.isReadyForMoreMediaData {
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
      }
      XCTAssertTrue(
        adaptor.append(
          pixelBuffer,
          withPresentationTime: CMTime(value: Int64(index), timescale: 30)
        )
      )
    }
    input.markAsFinished()
    let finished = expectation(description: "Fixture video")
    writer.finishWriting { finished.fulfill() }
    wait(for: [finished], timeout: 10)
    XCTAssertEqual(
      writer.status,
      .completed,
      writer.error?.localizedDescription ?? "AVAssetWriter did not complete"
    )
  }

  private func rgbaPixel(from image: CGImage) -> (UInt8, UInt8, UInt8, UInt8) {
    var bytes = [UInt8](repeating: 0, count: 4)
    CIContext().render(
      CIImage(cgImage: image),
      toBitmap: &bytes,
      rowBytes: 4,
      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
      format: .RGBA8,
      colorSpace: CGColorSpaceCreateDeviceRGB()
    )
    return (bytes[0], bytes[1], bytes[2], bytes[3])
  }
}
