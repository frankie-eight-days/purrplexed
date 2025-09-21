//
//  CaptureAnalysisMocks.swift
//  Purrplexed
//
//  Mock services for previews/tests.
//

import Foundation
import AVFoundation

final class MockMediaService: MediaService {
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

actor InMemoryOfflineQueue: OfflineQueueing {
	private var items: [(CapturedPhoto, CapturedAudio?)] = []
	func enqueue(photo: CapturedPhoto, audio: CapturedAudio?) async { items.append((photo, audio)) }
	func pendingCount() async -> Int { items.count }
}
