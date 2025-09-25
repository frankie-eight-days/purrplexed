//
//  CaptureAnalysisMocks.swift
//  Purrplexed
//
//  Mock services for previews/tests.
//

import Foundation
@preconcurrency import AVFoundation
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
				emotion: "Relaxed stretch", 
				intensity: "Low", 
				description: "The cat is resting comfortably with loose muscles.", 
				emoji: "😌", 
				moodType: "relaxed", 
				warningMessage: nil
			),
			EmotionSummary(
				emotion: "Calm vigilance", 
				intensity: "Medium", 
				description: "The cat is alert but composed, watching the room.", 
				emoji: "👀", 
				moodType: "alert", 
				warningMessage: nil
			),
			EmotionSummary(
				emotion: "Playful focus", 
				intensity: "High", 
				description: "The cat looks poised to engage with something interesting.", 
				emoji: "😼", 
				moodType: "playful", 
				warningMessage: nil
			)
		]
		
		return scenarios.randomElement()!
	}
	
	func analyzeBodyLanguage(fileUri: String) async throws -> BodyLanguageAnalysis {
		try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
		return BodyLanguageAnalysis(posture: "Loafed with shoulders relaxed", ears: "Pointed forward", tail: "Resting along the body", eyes: "Soft and half-open", whiskers: "Neutral angle", overallMood: "relaxed")
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
				
				let emotionScenarios = [
					EmotionSummary(
						emotion: "Relaxed stretch", 
						intensity: "Low", 
						description: "The cat is resting comfortably with loose muscles.", 
						emoji: "😌", 
						moodType: "relaxed", 
						warningMessage: nil
					),
					EmotionSummary(
						emotion: "Calm vigilance", 
						intensity: "Medium", 
						description: "The cat is alert but composed, watching the room.", 
						emoji: "👀", 
						moodType: "alert", 
						warningMessage: nil
					),
					EmotionSummary(
						emotion: "Playful focus", 
						intensity: "High", 
						description: "The cat looks poised to engage with something interesting.", 
						emoji: "😼", 
						moodType: "playful", 
						warningMessage: nil
					)
				]
				
				let summary = emotionScenarios.randomElement()!
				continuation.yield(.emotionSummaryCompleted(summary))
				
				try? await Task.sleep(nanoseconds: 200_000_000)
				let body = BodyLanguageAnalysis(posture: "Loafed with shoulders relaxed", ears: "Pointed forward", tail: "Resting along the body", eyes: "Soft and half-open", whiskers: "Neutral angle", overallMood: "relaxed")
				continuation.yield(.bodyLanguageCompleted(body))
				
				try? await Task.sleep(nanoseconds: 150_000_000)
				let context = ContextualEmotion(
					contextClues: ["Soft lighting", "Comfortable furniture", "Quiet environment"],
					environmentalFactors: ["Indoor safe space", "No visible threats"],
					emotionalMeaning: ["Feeling secure and at home"]
				)
				continuation.yield(.contextualEmotionCompleted(context))
				
				try? await Task.sleep(nanoseconds: 150_000_000)
				let advice = OwnerAdvice(
					immediateActions: ["Continue providing a calm environment", "Keep regular feeding schedule"],
					longTermSuggestions: ["Maintain regular routine"],
					warningSigns: []
				)
				continuation.yield(.ownerAdviceCompleted(advice))
				
				if ["content", "playful"].contains(summary.moodType.lowercased()) {
					try? await Task.sleep(nanoseconds: 120_000_000)
					let jokes = CatJokes(jokes: [
						"This patch of sunlight is under new management.",
						"I’ll chase the toy after this very serious lounge session.",
						"Please log all petting requests in triplicate."
					])
					continuation.yield(.catJokesCompleted(jokes))
				}
				
				continuation.finish()
			}
		}
	}
}

// MARK: - Production Implementations

/// Production PermissionsService using AVFoundation
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
			return .granted
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
			return .granted
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
