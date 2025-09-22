//
//  CaptureAnalysisMocks.swift
//  Purrplexed
//
//  Mock services for previews/tests.
//

import Foundation
@preconcurrency import AVFoundation

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
