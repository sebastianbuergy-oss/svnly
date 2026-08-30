import Flutter
import AVFoundation
import CoreImage
import ImageIO
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pushChannel: FlutterMethodChannel?
  private var pendingPushResult: FlutterResult?

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
      guard let arguments = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }

      switch call.method {
      case "burnLiveLook":
        guard let inputPath = arguments["inputPath"] as? String,
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
      case "extractModerationFrames":
        guard let inputPath = arguments["inputPath"] as? String else {
          result(FlutterMethodNotImplemented)
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            let frames = try ModerationFrameExtractor().extract(
              inputURL: URL(fileURLWithPath: inputPath)
            )
            DispatchQueue.main.async {
              result(frames.map { FlutterStandardTypedData(bytes: $0) })
            }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(
                code: "MODERATION_FRAME_EXTRACTION_FAILED",
                message: error.localizedDescription,
                details: nil
              ))
            }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    pushChannel = FlutterMethodChannel(
      name: "ch.sebastianbuergy.svnly/push",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    pushChannel?.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "requestRegistration":
        self.requestPushRegistration(promptIfNeeded: true, result: result)
      case "refreshRegistration":
        self.requestPushRegistration(promptIfNeeded: false, result: result)
      case "unregister":
        UIApplication.shared.unregisterForRemoteNotifications()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    UNUserNotificationCenter.current().delegate = self
  }

  private func requestPushRegistration(promptIfNeeded: Bool, result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
      guard let self else { return }
      if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
        DispatchQueue.main.async {
          self.pendingPushResult = result
          UIApplication.shared.registerForRemoteNotifications()
        }
        return
      }
      guard promptIfNeeded && settings.authorizationStatus == .notDetermined else {
        DispatchQueue.main.async { result(["granted": false]) }
        return
      }
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {
        granted, error in
        DispatchQueue.main.async {
          if let error {
            result(FlutterError(code: "PUSH_PERMISSION_FAILED", message: error.localizedDescription, details: nil))
          } else if granted {
            self.pendingPushResult = result
            UIApplication.shared.registerForRemoteNotifications()
          } else {
            result(["granted": false])
          }
        }
      }
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    #if DEBUG
    let environment = "sandbox"
    #else
    let environment = "production"
    #endif
    let registration: [String: Any] = [
      "granted": true,
      "token": token,
      "environment": environment,
      "locale": Locale.preferredLanguages.first ?? "en",
      "timezone": TimeZone.current.identifier
    ]
    pendingPushResult?(registration)
    pendingPushResult = nil
    pushChannel?.invokeMethod("tokenChanged", arguments: registration)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    pendingPushResult?(FlutterError(
      code: "APNS_REGISTRATION_FAILED",
      message: error.localizedDescription,
      details: nil
    ))
    pendingPushResult = nil
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    pushChannel?.invokeMethod(
      "notificationOpened",
      arguments: response.notification.request.content.userInfo
    )
    completionHandler()
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .badge, .sound])
  }
}

enum ModerationFrameExtractorError: LocalizedError {
  case frameUnavailable
  case encodingFailed

  var errorDescription: String? {
    switch self {
    case .frameUnavailable: return "A moderation frame could not be read from the final video."
    case .encodingFailed: return "A moderation frame could not be encoded as JPEG."
    }
  }
}

final class ModerationFrameExtractor {
  private let frameTimes = [0.70, 3.50, 6.30]

  func extract(inputURL: URL) throws -> [Data] {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: inputURL))
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 720, height: 720)
    generator.requestedTimeToleranceBefore = CMTime(seconds: 0.15, preferredTimescale: 600)
    generator.requestedTimeToleranceAfter = CMTime(seconds: 0.15, preferredTimescale: 600)

    return try frameTimes.map { seconds in
      let image: CGImage
      do {
        image = try generator.copyCGImage(
          at: CMTime(seconds: seconds, preferredTimescale: 600),
          actualTime: nil
        )
      } catch {
        throw ModerationFrameExtractorError.frameUnavailable
      }
      let data = NSMutableData()
      guard let destination = CGImageDestinationCreateWithData(
              data as CFMutableData,
              "public.jpeg" as CFString,
              1,
              nil
            ) else {
        throw ModerationFrameExtractorError.encodingFailed
      }
      CGImageDestinationAddImage(
        destination,
        image,
        [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary
      )
      guard CGImageDestinationFinalize(destination), data.length >= 256 else {
        throw ModerationFrameExtractorError.encodingFailed
      }
      return data as Data
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
    // Keep the processor alive until AVFoundation has rendered every frame.
    // Callers intentionally create this processor as a short-lived value.
    let composition = AVVideoComposition(asset: asset) { request in
      let source = request.sourceImage.clampedToExtent()
      let filtered = self.apply(look: look, to: source).cropped(to: request.sourceImage.extent)
      request.finish(with: filtered, context: self.context)
    }

    guard let exporter = AVAssetExportSession(
      asset: asset,
      // Seven seconds must reliably remain below the 12 MiB take-bucket cap,
      // including on modern iPhones whose high preset can exceed it.
      presetName: AVAssetExportPreset1280x720
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
