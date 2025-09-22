//
//  CaptureAnalysisMocks.swift
//  Purrplexed
//
//  Mock services for previews/tests.
//

import Foundation
@preconcurrency import AVFoundation
import Photos
import UIKit

final class MockMediaService: MediaService, @unchecked Sendable {
	let captureSession: AVCaptureSession? = nil // Placeholder; reuse if added later
	func prepareSession() async throws {}
	func capturePhoto() async throws -> CapturedPhoto {
		try? await Task.sleep(nanoseconds: 100_000_000)
		return CapturedPhoto(imageData: Data())
	}
}

final class MockAnalysisService: AnalysisService {
	func analyze(photo: CapturedPhoto, audio: CapturedAudio?) async throws -> AsyncStream<AnalysisStatus> {
		AsyncStream { continuation in
			Task {
				continuation.yield(.queued)
				for i in 1...5 {
					try? await Task.sleep(nanoseconds: 180_000_000)
					continuation.yield(.processing(progress: Double(i) / 5.0))
				}
				let result = AnalysisResult(translatedText: "Hello, whiskers!", confidence: 0.92, funFact: "Cats sleep 12–16 hours a day.")
				continuation.yield(.completed(result))
				continuation.finish()
			}
		}
	}
}

final class MockShareService: ShareService {
	func generateShareCard(result: AnalysisResult, imageData: Data, aspect: ShareAspect) async throws -> Data {
		try? await Task.sleep(nanoseconds: 80_000_000)
		return Data()
	}
	func saveToPhotos(data: Data) async throws { }
}

final class MockAnalyticsService: AnalyticsService {
	func track(event: String, properties: [String : Sendable]) { }
}

final class MockPermissionsService: PermissionsService {
	func status(for type: PermissionType) async -> PermissionStatus { .granted }
	func request(_ type: PermissionType) async -> PermissionStatus { .granted }
}

final class MockParallelAnalysisService: ParallelAnalysisService {
	func uploadPhoto(_ photo: CapturedPhoto) async throws -> String {
		try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
		return "mock://file/uri/12345"
	}
	
	func analyzeEmotionSummary(fileUri: String) async throws -> EmotionSummary {
		try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
		
		let scenarios = [
			EmotionSummary(
				emotion: "Content", 
				intensity: "Moderate", 
				description: "The cat appears relaxed and comfortable", 
				emoji: "😌", 
				moodType: "happy", 
				warningMessage: nil
			),
			EmotionSummary(
				emotion: "Alert", 
				intensity: "Moderate", 
				description: "The cat is attentive and watching its surroundings", 
				emoji: "👀", 
				moodType: "neutral", 
				warningMessage: nil
			),
			EmotionSummary(
				emotion: "Playful", 
				intensity: "High", 
				description: "The cat looks ready for fun and games", 
				emoji: "😸", 
				moodType: "happy", 
				warningMessage: nil
			)
		]
		
		return scenarios.randomElement()!
	}
	
	func analyzeBodyLanguage(fileUri: String) async throws -> BodyLanguageAnalysis {
		try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
		return BodyLanguageAnalysis(posture: "Relaxed", ears: "Forward", tail: "Still", eyes: "Half-closed", whiskers: "Relaxed and forward", overallMood: "Peaceful")
	}
	
	func analyzeContextualEmotion(fileUri: String) async throws -> ContextualEmotion {
		try? await Task.sleep(nanoseconds: 350_000_000) // 0.35s
		return ContextualEmotion(
			contextClues: ["Soft lighting", "Comfortable furniture", "Quiet environment"], 
			environmentalFactors: ["Indoor safe space", "No visible threats"], 
			emotionalMeaning: ["Feeling secure and at home"]
		)
	}
	
	func analyzeOwnerAdvice(fileUri: String) async throws -> OwnerAdvice {
		try? await Task.sleep(nanoseconds: 450_000_000) // 0.45s
		return OwnerAdvice(
			immediateActions: ["Continue providing a calm environment", "Keep regular feeding schedule"], 
			longTermSuggestions: ["Maintain regular routine"], 
			warningSigns: []
		)
	}
	
	func analyzeCatJokes(fileUri: String) async throws -> CatJokes {
		try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
		return CatJokes(jokes: [
			"I'm not sleeping, I'm just resting my eyes... for 16 hours",
			"This sunny spot is mine now. Don't even think about it.",
			"I knocked that off the table for science. You're welcome."
		])
	}
	
	func analyzeParallel(photo: CapturedPhoto) async throws -> AsyncStream<ParallelAnalysisUpdate> {
		AsyncStream { continuation in
			Task {
				continuation.yield(.uploadStarted)
				try? await Task.sleep(nanoseconds: 200_000_000)
				let fileUri = "mock://file/uri/12345"
				continuation.yield(.uploadCompleted(fileUri: fileUri))
				
				// First get emotion summary to determine if we should generate cat jokes
				var emotionSummary: EmotionSummary?
				try? await Task.sleep(nanoseconds: 300_000_000)
				// Vary the mock response to test different scenarios
				let scenarios = [
					EmotionSummary(
						emotion: "Content", 
						intensity: "Moderate", 
						description: "The cat appears relaxed and comfortable", 
						emoji: "😌", 
						moodType: "happy", 
						warningMessage: nil
					),
					EmotionSummary(
						emotion: "Alert", 
						intensity: "Moderate", 
						description: "The cat is attentive and watching its surroundings", 
						emoji: "👀", 
						moodType: "neutral", 
						warningMessage: nil
					),
					EmotionSummary(
						emotion: "Playful", 
						intensity: "High", 
						description: "The cat looks ready for fun and games", 
						emoji: "😸", 
						moodType: "happy", 
						warningMessage: nil
					)
				]
				
				emotionSummary = scenarios.randomElement()!
				continuation.yield(.emotionSummaryCompleted(emotionSummary!))
				
				// Simulate remaining parallel execution with varied timing
				await withTaskGroup(of: Void.self) { group in
					group.addTask {
						try? await Task.sleep(nanoseconds: 400_000_000)
						let result = BodyLanguageAnalysis(posture: "Relaxed", ears: "Forward", tail: "Still", eyes: "Half-closed", whiskers: "Relaxed and forward", overallMood: "Peaceful")
						continuation.yield(.bodyLanguageCompleted(result))
					}
					
					group.addTask {
						try? await Task.sleep(nanoseconds: 350_000_000)
						let result = ContextualEmotion(
							contextClues: ["Soft lighting", "Comfortable furniture", "Quiet environment"], 
							environmentalFactors: ["Indoor safe space", "No visible threats"], 
							emotionalMeaning: ["Feeling secure and at home"]
						)
						continuation.yield(.contextualEmotionCompleted(result))
					}
					
					group.addTask {
						try? await Task.sleep(nanoseconds: 450_000_000)
						let result = OwnerAdvice(
							immediateActions: ["Continue providing a calm environment", "Keep regular feeding schedule"], 
							longTermSuggestions: ["Maintain regular routine"], 
							warningSigns: []
						)
						continuation.yield(.ownerAdviceCompleted(result))
					}
					
					// Cat jokes - only if mood is happy
					if let emotionSummary = emotionSummary, emotionSummary.moodType.lowercased() == "happy" {
						group.addTask {
							try? await Task.sleep(nanoseconds: 250_000_000)
							let result = CatJokes(jokes: [
								"I'm not sleeping, I'm just resting my eyes... for 16 hours",
								"This sunny spot is mine now. Don't even think about it.",
								"I knocked that off the table for science. You're welcome."
							])
							continuation.yield(.catJokesCompleted(result))
						}
					}
				}
				
				continuation.finish()
			}
		}
	}
}

actor InMemoryOfflineQueue: OfflineQueueing {
	private var items: [(CapturedPhoto, CapturedAudio?)] = []
	func enqueue(photo: CapturedPhoto, audio: CapturedAudio?) async { items.append((photo, audio)) }
	func pendingCount() async -> Int { items.count }
}

// MARK: - Production Implementations

/// Production PermissionsService using AVFoundation and Photos framework
final class ProductionPermissionsService: PermissionsService {
	func status(for type: PermissionType) async -> PermissionStatus {
		switch type {
		case .camera:
			let status = AVCaptureDevice.authorizationStatus(for: .video)
			return status.toPermissionStatus()
		case .microphone:
			let status = AVCaptureDevice.authorizationStatus(for: .audio)
			return status.toPermissionStatus()
		case .photos:
			let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
			return status.toPermissionStatus()
		}
	}
	
	func request(_ type: PermissionType) async -> PermissionStatus {
		switch type {
		case .camera:
			let granted = await AVCaptureDevice.requestAccess(for: .video)
			return granted ? .granted : .denied
		case .microphone:
			let granted = await AVCaptureDevice.requestAccess(for: .audio)
			return granted ? .granted : .denied
		case .photos:
			let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
			return status.toPermissionStatus()
		}
	}
}

private extension AVAuthorizationStatus {
	func toPermissionStatus() -> PermissionStatus {
		switch self {
		case .notDetermined: return .notDetermined
		case .restricted: return .restricted
		case .denied: return .denied
		case .authorized: return .granted
		@unknown default: return .denied
		}
	}
}

private extension PHAuthorizationStatus {
	func toPermissionStatus() -> PermissionStatus {
		switch self {
		case .notDetermined: return .notDetermined
		case .restricted: return .restricted
		case .denied: return .denied
		case .authorized, .limited: return .granted
		@unknown default: return .denied
		}
	}
}

/// Production MediaService using AVFoundation
final class ProductionMediaService: NSObject, MediaService, @unchecked Sendable {
	internal var captureSession: AVCaptureSession?
	private var photoOutput: AVCapturePhotoOutput?
	private var currentPhotoCapture: PhotoCaptureProcessor?
	
	func prepareSession() async throws {
		guard captureSession == nil else { return } // Already prepared
		
		let session = AVCaptureSession()
		session.beginConfiguration()
		
		// Configure for high quality photos
		if session.canSetSessionPreset(.photo) {
			session.sessionPreset = .photo
		}
		
		// Add camera input
		guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
			throw MediaError.cameraUnavailable
		}
		
		let cameraInput = try AVCaptureDeviceInput(device: camera)
		guard session.canAddInput(cameraInput) else {
			throw MediaError.failedToAddInput
		}
		session.addInput(cameraInput)
		
		// Add photo output
		let photoOutput = AVCapturePhotoOutput()
		guard session.canAddOutput(photoOutput) else {
			throw MediaError.failedToAddOutput
		}
		session.addOutput(photoOutput)
		
		session.commitConfiguration()
		
		self.captureSession = session
		self.photoOutput = photoOutput
		
		// Start session
		session.startRunning()
	}
	
	func capturePhoto() async throws -> CapturedPhoto {
		guard let photoOutput = photoOutput else {
			throw MediaError.notPrepared
		}
		
		let settings = AVCapturePhotoSettings()
		settings.photoQualityPrioritization = .quality
		
		let processor = PhotoCaptureProcessor()
		currentPhotoCapture = processor
		
		photoOutput.capturePhoto(with: settings, delegate: processor)
		
		return try await processor.photoData()
	}
}

private class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
	private var continuation: CheckedContinuation<CapturedPhoto, Error>?
	
	func photoData() async throws -> CapturedPhoto {
		return try await withCheckedThrowingContinuation { continuation in
			self.continuation = continuation
		}
	}
	
	func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
		defer { continuation = nil }
		
		if let error = error {
			continuation?.resume(throwing: error)
			return
		}
		
		guard let imageData = photo.fileDataRepresentation() else {
			continuation?.resume(throwing: MediaError.failedToGenerateImageData)
			return
		}
		
		let capturedPhoto = CapturedPhoto(imageData: imageData)
		continuation?.resume(returning: capturedPhoto)
	}
}

enum MediaError: Error, LocalizedError {
	case cameraUnavailable
	case failedToAddInput
	case failedToAddOutput
	case notPrepared
	case failedToGenerateImageData
	
	var errorDescription: String? {
		switch self {
		case .cameraUnavailable:
			return "Camera is not available"
		case .failedToAddInput:
			return "Failed to add camera input"
		case .failedToAddOutput:
			return "Failed to add photo output"
		case .notPrepared:
			return "Camera session is not prepared"
		case .failedToGenerateImageData:
			return "Failed to generate image data from captured photo"
		}
	}
}

/// Production ShareService for generating share cards and saving to Photos
final class ProductionShareService: ShareService {
	func generateShareCard(result: AnalysisResult, imageData: Data, aspect: ShareAspect) async throws -> Data {
		guard let image = UIImage(data: imageData) else {
			throw ShareError.invalidImageData
		}
		
		let cardSize = sizeFor(aspect: aspect)
		let cardImage = try await generateShareCardImage(
			image: image,
			result: result,
			size: cardSize
		)
		
		guard let pngData = cardImage.pngData() else {
			throw ShareError.failedToGenerateShareCard
		}
		
		return pngData
	}
	
	func saveToPhotos(data: Data) async throws {
		try await PHPhotoLibrary.shared().performChanges {
			if let image = UIImage(data: data) {
				PHAssetCreationRequest.creationRequestForAsset(from: image)
			}
		}
	}
	
	private func sizeFor(aspect: ShareAspect) -> CGSize {
		switch aspect {
		case .square_1_1:
			return CGSize(width: 1080, height: 1080)
		case .portrait_9_16:
			return CGSize(width: 1080, height: 1920)
		case .landscape_16_9:
			return CGSize(width: 1920, height: 1080)
		}
	}
	
	private func generateShareCardImage(image: UIImage, result: AnalysisResult, size: CGSize) async throws -> UIImage {
		let renderer = UIGraphicsImageRenderer(size: size)
		
		return renderer.image { context in
			let rect = CGRect(origin: .zero, size: size)
			
			// Background
			UIColor.systemBackground.setFill()
			context.fill(rect)
			
			// Image
			let imageRect = CGRect(
				x: 40,
				y: 40,
				width: size.width - 80,
				height: (size.height - 200) * 0.7
			)
			image.draw(in: imageRect)
			
			// Text
			let textRect = CGRect(
				x: 40,
				y: imageRect.maxY + 20,
				width: size.width - 80,
				height: size.height - imageRect.maxY - 60
			)
			
			let text = result.translatedText
			let font = UIFont.systemFont(ofSize: 28, weight: .medium)
			let attributes: [NSAttributedString.Key: Any] = [
				.font: font,
				.foregroundColor: UIColor.label
			]
			
			text.draw(in: textRect, withAttributes: attributes)
		}
	}
}

enum ShareError: Error, LocalizedError {
	case invalidImageData
	case failedToGenerateShareCard
	
	var errorDescription: String? {
		switch self {
		case .invalidImageData:
			return "Invalid image data provided"
		case .failedToGenerateShareCard:
			return "Failed to generate share card"
		}
	}
}

/// Production AnalyticsService (basic implementation - replace with your analytics provider)
final class ProductionAnalyticsService: AnalyticsService {
	func track(event: String, properties: [String: Sendable]) {
		// Replace with your analytics provider (Firebase, Mixpanel, etc.)
		print("📊 Analytics Event: \(event)")
		for (key, value) in properties {
			print("   \(key): \(value)")
		}
		
		// Example integration points:
		// Analytics.logEvent(event, parameters: properties)
		// Mixpanel.shared.track(event: event, properties: properties)
	}
}
