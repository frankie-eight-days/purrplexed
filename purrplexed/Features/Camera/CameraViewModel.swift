//
//  CameraViewModel.swift
//  Purrplexed
//
//  Camera feature ViewModel with finite state machine and job orchestration.
//

import Foundation
import SwiftUI

@MainActor
final class CameraViewModel: ObservableObject {
	// FSM
	enum State: Equatable {
		case idle
		case submitting(mediaId: String)
		case processing(jobId: String)
		case result(jobId: String)
		case error(message: String)
	}

	@Published private(set) var state: State = .idle
	@Published private(set) var remainingFree: Int = 0

	private let services: ServiceContainer
	private var statusTask: Task<Void, Never>? = nil
	private var currentJobId: String? = nil
	private weak var router: Routing?

	init(services: ServiceContainer) {
		self.services = services
		self.router = services.router
	}

	func onAppear() {
		Task { [weak self] in
			guard let self else { return }
			self.remainingFree = await self.services.usageMeter.remainingFreeCount()
		}
	}

	func onDisappear() {
		cancelInFlight()
	}

	func captureTapped() {
		guard state == .idle else { return } // ignore illegal
		Task { [weak self] in
			guard let self else { return }
			let canStart = await self.services.usageMeter.canStartJob()
			guard canStart else {
				self.transition(.error(message: "Daily limit reached"))
				return
			}
			// Simulate capture and create mediaId
			let mediaId = UUID().uuidString
			self.transition(.submitting(mediaId: mediaId))
			await self.startProcessing()
		}
	}

	func beginProcessing(with image: UIImage) {
		Task { [weak self] in
			guard let self else { return }
			guard await self.services.usageMeter.canStartJob() else {
				self.transition(.error(message: "Daily limit reached"))
				return
			}
			self.transition(.submitting(mediaId: UUID().uuidString))
			if let data = image.jpegData(compressionQuality: 0.9) {
				await self.startProcessing(imageData: data)
			} else {
				self.transition(.error(message: "Could not encode image"))
			}
		}
	}

	private func startProcessing(imageData: Data) async {
		cancelInFlight()
		do {
			let (jobId, stream) = try await services.jobOrchestrator.startJob(imageData: imageData)
			self.currentJobId = jobId
			self.transition(.processing(jobId: jobId))
			statusTask = Task { [weak self] in
				guard let self else { return }
				for await status in stream {
					if Task.isCancelled { break }
					switch status {
					case .queued:
						break
					case .processing:
						break
					case .completed:
						await self.services.jobOrchestrator.finishSuccess()
						let remaining = await self.services.usageMeter.remainingFreeCount()
						await MainActor.run {
							self.remainingFree = remaining
							self.transition(.result(jobId: jobId))
							self.router?.present(.result(jobId: jobId))
						}
					case .failed(let message):
						await self.services.jobOrchestrator.finishFailure()
						await MainActor.run {
							self.transition(.error(message: message))
						}
					}
				}
			}
		} catch {
			await services.jobOrchestrator.finishFailure()
			self.transition(.error(message: "Submit failed"))
		}
	}

	private func startProcessing() async {
		let imageData = Data()
		await startProcessing(imageData: imageData)
	}

	private func cancelInFlight() {
		statusTask?.cancel()
		statusTask = nil
	}

	private func transition(_ newState: State) {
		// Allowed transitions
		switch (state, newState) {
		case (.idle, .submitting),
			(.submitting, .processing),
			(.processing, .result),
			(.processing, .error),
			(.error, .idle),
			(.result, .idle):
			state = newState
		default:
			// ignore illegal
			break
		}
	}

	#if DEBUG
	// Testing helpers
	func test_forceTransition(_ newState: State) { transition(newState) }
	var test_isTaskCancelled: Bool { statusTask?.isCancelled ?? false }
	#endif
}
