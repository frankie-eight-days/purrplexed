//
//  CaptureAnalysisViewModel.swift
//  Purrplexed
//
//  Unified Capture→Processing→Analysis ViewModel with FSM and async pipelines.
//

import Foundation
import SwiftUI

@MainActor
final class CaptureAnalysisViewModel: ObservableObject {
	enum State: Equatable {
		case idle
		case capturing
		case processing(media: MediaDescriptor)
		case ready(result: AnalysisResult)
		case error(message: String)
	}

	enum MediaDescriptor: Equatable {
		case photo
		case photoWithAudio
	}

	@Published private(set) var state: State = .idle
	@Published var addAudio: Bool = false
	@Published var progress: Double = 0
	@Published var permissionPrompt: String? = nil
	@Published var thumbnailData: Data? = nil

	private let media: MediaService
	private let analysis: AnalysisService
	private let share: ShareService
	private let analytics: AnalyticsService
	private let permissions: PermissionsService
	private let offlineQueue: OfflineQueueing
	private var analysisTask: Task<Void, Never>? = nil

	init(media: MediaService, analysis: AnalysisService, share: ShareService, analytics: AnalyticsService, permissions: PermissionsService, offlineQueue: OfflineQueueing) {
		self.media = media
		self.analysis = analysis
		self.share = share
		self.analytics = analytics
		self.permissions = permissions
		self.offlineQueue = offlineQueue
	}

	// MARK: - Inputs

	func didTapCapture() {
		Task { [weak self] in
			guard let self else { return }
			guard await ensurePermissionFlow() else { return }
			self.transition(.capturing)
			Haptics.impact(.light)
			do {
				let photo = try await self.media.capturePhoto()
				self.thumbnailData = photo.imageData
				// No auto-analysis; wait for explicit Analyze CTA
			} catch {
				self.transition(.error(message: NSLocalizedString("error_capture_failed", comment: "")))
				Haptics.error()
			}
		}
	}

	func didPickPhoto(_ data: Data) {
		Task { [weak self] in
			guard let self else { return }
			self.thumbnailData = data
			self.state = .idle
		}
	}

	func didTapAnalyze() {
		Task { [weak self] in
			guard let self else { return }
			guard let data = self.thumbnailData else { Log.analysis.warning("Analyze tapped with no image"); return }
			Log.analysis.info("Analyze tapped; starting permissions check")
			guard await self.ensurePermissionFlow(photosOnly: true) else { Log.permissions.warning("Permissions not granted"); return }
			Log.analysis.info("Permissions OK; beginning analysis")
			await self.beginAnalysis(photo: CapturedPhoto(imageData: data), audio: self.addAudio ? CapturedAudio(data: Data(), sampleRate: 44_100) : nil)
		}
	}

	func didToggleAudio(_ on: Bool) { addAudio = on }
	func didTapRetry() { transition(.idle) }

	func didTapShare(result: AnalysisResult) {
		analytics.track(event: "share_tap", properties: ["confidence": result.confidence])
		Task { [weak self] in
			guard let self else { return }
			_ = try? await self.share.generateShareCard(result: result, imageData: self.thumbnailData ?? Data(), aspect: .square_1_1)
		}
	}

	func cancelWork() {
		analysisTask?.cancel()
		analysisTask = nil
		progress = 0
	}

	// MARK: - Private

	private func ensurePermissionFlow(photosOnly: Bool = false) async -> Bool {
		if !photosOnly {
			let cam = await permissions.status(for: .camera)
			if cam == .notDetermined { _ = await permissions.request(.camera) }
			let mic = await permissions.status(for: .microphone)
			if addAudio && mic == .notDetermined { _ = await permissions.request(.microphone) }
		}
		let photos = await permissions.status(for: .photos)
		if photos == .notDetermined { _ = await permissions.request(.photos) }
		let finalStatuses: [PermissionStatus] = [photos] + (photosOnly ? [] : [await permissions.status(for: .camera)])
		let ok = finalStatuses.allSatisfy { $0 == .granted }
		permissionPrompt = ok ? nil : NSLocalizedString("perm_inline_prompt", comment: "")
		return ok
	}

	private func beginAnalysis(photo: CapturedPhoto, audio: CapturedAudio?) async {
		cancelWork()
		let mediaKind: MediaDescriptor = audio == nil ? .photo : .photoWithAudio
		Log.analysis.info("Transition to processing: \(String(describing: mediaKind))")
		transition(.processing(media: mediaKind))
		analytics.track(event: "analysis_start", properties: ["media": String(describing: mediaKind)])
		analysisTask = Task { [weak self] in
			guard let self else { return }
			do {
				let stream = try await self.analysis.analyze(photo: photo, audio: audio)
				for await status in stream {
					if Task.isCancelled { Log.analysis.info("Analysis task cancelled"); break }
					switch status {
					case .queued:
						await MainActor.run { self.progress = 0 }
						Log.analysis.info("Status: queued")
					case .processing(let p):
						await MainActor.run { self.progress = p }
						Log.analysis.info("Status: processing progress=\(p, privacy: .public)")
					case .completed(let result):
						Haptics.success()
						await MainActor.run { self.transition(.ready(result: result)) }
						self.analytics.track(event: "analysis_complete", properties: ["confidence": result.confidence])
						Log.analysis.info("Status: completed")
					case .failed(let msg):
						await self.offlineQueue.enqueue(photo: photo, audio: audio)
						await MainActor.run { self.transition(.error(message: msg)) }
						Haptics.error()
						self.analytics.track(event: "analysis_error", properties: ["message": msg])
						Log.analysis.error("Status: failed \(msg, privacy: .public)")
					}
				}
			} catch {
				await self.offlineQueue.enqueue(photo: photo, audio: audio)
				await MainActor.run { self.transition(.error(message: NSLocalizedString("error_network_generic", comment: ""))) }
				Haptics.error()
				Log.network.error("Analyze network error: \(error.localizedDescription, privacy: .public)")
			}
		}
	}

	private func transition(_ new: State) {
		switch (state, new) {
		case (.idle, .capturing),
			(.capturing, .processing),
			(.processing, .ready),
			(.processing, .error),
			(.error, .idle),
			(.ready, .idle),
			(.idle, .processing):
			state = new
		default:
			break
		}
	}
}
