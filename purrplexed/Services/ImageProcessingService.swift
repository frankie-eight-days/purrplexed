//
//  ImageProcessingService.swift
//  Purrplexed
//
//  Protocol and a simple mock implementation that simulates processing.
//

import Foundation

final class MockImageProcessingService: ImageProcessingService {
	func submit(imageData: Data) async throws -> String {
		// Simulate an async submit
		try? await Task.sleep(nanoseconds: 150_000_000)
		return UUID().uuidString
	}

	func statusStream(jobId: String) -> AsyncStream<ProcessingStatus> {
		AsyncStream { continuation in
			Task {
				continuation.yield(.queued)
				try? await Task.sleep(nanoseconds: 250_000_000)
				for i in 1...5 {
					try? await Task.sleep(nanoseconds: 200_000_000)
					continuation.yield(.processing(progress: Double(i) / 5.0))
				}
				continuation.yield(.completed)
				continuation.finish()
			}
		}
	}
}
