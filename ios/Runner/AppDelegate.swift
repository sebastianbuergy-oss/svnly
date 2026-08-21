import Flutter
import AVFoundation
import CoreImage
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "ch.sebastianbuergy.svnly/video_processor",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "burnLiveLook",
            let arguments = call.arguments as? [String: Any],
            let inputPath = arguments["inputPath"] as? String,
            let outputPath = arguments["outputPath"] as? String,
            let look = arguments["look"] as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      LiveLookVideoProcessor().process(
        inputURL: URL(fileURLWithPath: inputPath),
        outputURL: URL(fileURLWithPath: outputPath),
        look: look
      ) { processingResult in
        DispatchQueue.main.async {
          switch processingResult {
          case .success(let proof):
            result(proof)
          case .failure(let error):
            result(FlutterError(
              code: "LIVE_LOOK_EXPORT_FAILED",
              message: error.localizedDescription,
              details: nil
            ))
          }
        }
      }
    }
  }
}

enum LiveLookVideoProcessorError: LocalizedError {
  case exportUnavailable
  case invalidOutput
  case exportFailed(String)

  var errorDescription: String? {
    switch self {
    case .exportUnavailable: return "The video cannot be exported with this preset."
    case .invalidOutput: return "The processed video output is empty."
    case .exportFailed(let message): return "Video look export failed: \(message)"
    }
  }
}

final class LiveLookVideoProcessor {
  private let context = CIContext(options: [.cacheIntermediates: false])

  func process(
    inputURL: URL,
    outputURL: URL,
    look: String,
    completion: @escaping (Result<[String: Any], Error>) -> Void
  ) {
    let asset = AVURLAsset(url: inputURL)
    let composition = AVVideoComposition(asset: asset) { [weak self] request in
      guard let self else {
        request.finish(with: request.sourceImage, context: nil)
        return
      }
      let source = request.sourceImage.clampedToExtent()
      let filtered = self.apply(look: look, to: source).cropped(to: request.sourceImage.extent)
      request.finish(with: filtered, context: self.context)
    }

    guard let exporter = AVAssetExportSession(
      asset: asset,
      presetName: AVAssetExportPresetHighestQuality
    ) else {
      completion(.failure(LiveLookVideoProcessorError.exportUnavailable))
      return
    }

    try? FileManager.default.removeItem(at: outputURL)
    exporter.outputURL = outputURL
    exporter.outputFileType = .mp4
    exporter.shouldOptimizeForNetworkUse = true
    exporter.videoComposition = composition
    exporter.exportAsynchronously {
      if exporter.status == .completed,
         let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
         let size = attributes[.size] as? NSNumber,
         size.intValue > 0 {
        completion(.success([
          "outputPath": outputURL.path,
          "look": look,
          "filterApplied": true,
          "byteCount": size.intValue
        ]))
      } else if exporter.status == .completed {
        completion(.failure(LiveLookVideoProcessorError.invalidOutput))
      } else {
        completion(.failure(LiveLookVideoProcessorError.exportFailed(
          exporter.error?.localizedDescription ?? "unknown export status \(exporter.status.rawValue)"
        )))
      }
    }
  }

  private func apply(look: String, to image: CIImage) -> CIImage {
    switch look {
    case "Black & White":
      return image.applyingFilter("CIColorControls", parameters: [
        kCIInputSaturationKey: 0.0,
        kCIInputContrastKey: 1.08
      ])
    case "Warm Film":
      return image
        .applyingFilter("CITemperatureAndTint", parameters: [
          "inputNeutral": CIVector(x: 6500, y: 0),
          "inputTargetNeutral": CIVector(x: 5200, y: 8)
        ])
        .applyingFilter("CIColorControls", parameters: [
          kCIInputSaturationKey: 0.92,
          kCIInputContrastKey: 1.06
        ])
    case "Cool":
      return image.applyingFilter("CITemperatureAndTint", parameters: [
        "inputNeutral": CIVector(x: 6500, y: 0),
        "inputTargetNeutral": CIVector(x: 8200, y: -5)
      ])
    case "Retro":
      return image
        .applyingFilter("CIPhotoEffectProcess")
        .applyingFilter("CIVignette", parameters: [
          kCIInputIntensityKey: 0.45,
          kCIInputRadiusKey: 1.2
        ])
    default:
      return image
    }
  }
}
