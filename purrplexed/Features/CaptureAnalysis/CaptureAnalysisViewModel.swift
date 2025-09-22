//
//  CaptureAnalysisViewModel.swift
//  Purrplexed
//
//  Unified Capture→Processing→Analysis ViewModel with FSM and async pipelines.
//

import Foundation
import SwiftUI
import UIKit
import Vision

@MainActor
final class CaptureAnalysisViewModel: ObservableObject {
	enum State: Equatable {
		case idle
		case capturing
		case processing(media: MediaDescriptor)
		case ready(result: AnalysisResult)
		case error(message: String)
		
		var isReady: Bool {
			if case .ready = self { return true }
			return false
		}
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
	
	// Parallel analysis results
	@Published var emotionSummary: EmotionSummary? = nil
	@Published var bodyLanguageAnalysis: BodyLanguageAnalysis? = nil
	@Published var contextualEmotion: ContextualEmotion? = nil
	@Published var ownerAdvice: OwnerAdvice? = nil
	@Published var catJokes: CatJokes? = nil
	@Published var isUploadingPhoto: Bool = false
	@Published var isAnalyzing: Bool = false
	@Published var uploadedFileUri: String? = nil
	@Published var showShareCard: Bool = false
	
	// Cat detection state
	@Published var catDetectionResult: CatDetectionResult? = nil
	@Published var isDetectingCat: Bool = false
	@Published var optimalFrameHeight: CGFloat = 280 // Default frame height
	
	// Usage tracking
	@Published private(set) var usedCount: Int = 0
	@Published private(set) var dailyLimit: Int = 3
	@Published private(set) var isPremium: Bool = false
	@Published var showPaywall: Bool = false
	private var hasCommittedUsage = false

	private let media: MediaService
	private let analysis: AnalysisService
	private let parallelAnalysis: ParallelAnalysisService
	private let share: ShareService
	private let analytics: AnalyticsService
	private let permissions: PermissionsService
	private let offlineQueue: OfflineQueueing
	private let captionService: CaptionGenerationService
	private let usageMeter: UsageMeterServiceProtocol
	private let subscriptionService: SubscriptionServiceProtocol
	private var analysisTask: Task<Void, Never>? = nil

	init(media: MediaService, analysis: AnalysisService, parallelAnalysis: ParallelAnalysisService, share: ShareService, analytics: AnalyticsService, permissions: PermissionsService, offlineQueue: OfflineQueueing, captionService: CaptionGenerationService? = nil, usageMeter: UsageMeterServiceProtocol, subscriptionService: SubscriptionServiceProtocol) {
		self.media = media
		self.analysis = analysis
		self.parallelAnalysis = parallelAnalysis
		self.share = share
		self.analytics = analytics
		self.permissions = permissions
		self.offlineQueue = offlineQueue
		self.usageMeter = usageMeter
		self.subscriptionService = subscriptionService
		// Use provided caption service or create a local one as fallback
		self.captionService = captionService ?? LocalCaptionGenerationService()
	}

	// MARK: - Usage & Premium Status
	
	func refreshUsageStatus() {
		Task { [weak self] in
			guard let self else { return }
			let remaining = await self.usageMeter.remainingFreeCount()
			let premium = await self.subscriptionService.isPremium
			let newUsedCount = self.dailyLimit - remaining
			print("🔢 Refreshing usage status - used: \(newUsedCount), remaining: \(remaining), premium: \(premium)")
			await MainActor.run {
				self.usedCount = newUsedCount
				self.isPremium = premium
			}
		}
	}
	
	private func canStartAnalysis() async -> Bool {
		let premium = await subscriptionService.isPremium
		return premium ? true : await usageMeter.canStartJob()
	}
	
	// MARK: - Inputs

	func didTapCapture() {
		Task { [weak self] in
			guard let self else { return }
			guard await ensurePermissionFlow() else { return }
			
			// Clear previous analysis results when new photo is captured
			await MainActor.run {
				self.resetParallelAnalysisResults()
			}
			
			self.transition(.capturing)
			Haptics.impact(.light)
			do {
				let photo = try await self.media.capturePhoto()
				// Compress image for faster analysis while keeping original quality for thumbnail
				self.thumbnailData = await self.compressImageForAnalysis(photo.imageData)
				// No auto-analysis; wait for explicit Analyze CTA
				
				// Automatically detect cat in captured photo
				await self.detectCatInCurrentPhoto()
			} catch {
				self.transition(.error(message: NSLocalizedString("error_capture_failed", comment: "")))
				Haptics.error()
			}
		}
	}

	func didPickPhoto(_ data: Data) {
		Task { [weak self] in
			guard let self else { return }
			// Clear previous analysis results when new photo is loaded
			await MainActor.run {
				self.resetParallelAnalysisResults()
			}
			
			// Compress picked photo for faster analysis
			self.thumbnailData = await self.compressImageForAnalysis(data)
			self.state = .idle
			
			// Automatically detect cat in new photo
			await self.detectCatInCurrentPhoto()
		}
	}

	func didTapAnalyze() {
		Task { [weak self] in
			guard let self else { return }
			guard let data = self.thumbnailData else { Log.analysis.warning("Analyze tapped with no image"); return }
			
			// Check usage limits first
			guard await self.canStartAnalysis() else {
				await MainActor.run { self.showPaywall = true }
				return
			}
			
			Log.analysis.info("Analyze tapped; starting permissions check")
			guard await self.ensurePermissionFlow(photosOnly: true) else { Log.permissions.warning("Permissions not granted"); return }
			Log.analysis.info("Permissions OK; beginning parallel analysis")
			await self.beginParallelAnalysis(photo: CapturedPhoto(imageData: data))
		}
	}
	
	func didTapAnalyzeClassic() {
		Task { [weak self] in
			guard let self else { return }
			guard let data = self.thumbnailData else { Log.analysis.warning("Analyze tapped with no image"); return }
			
			// Check usage limits first
			guard await self.canStartAnalysis() else {
				await MainActor.run { self.showPaywall = true }
				return
			}
			
			Log.analysis.info("Classic analyze tapped; starting permissions check")
			guard await self.ensurePermissionFlow(photosOnly: true) else { Log.permissions.warning("Permissions not granted"); return }
			Log.analysis.info("Permissions OK; beginning classic analysis")
			await self.beginAnalysis(photo: CapturedPhoto(imageData: data), audio: self.addAudio ? CapturedAudio(data: Data(), sampleRate: 44_100) : nil)
		}
	}

	func didToggleAudio(_ on: Bool) { addAudio = on }
	func didTapRetry() { transition(.idle) }

	func presentShareCard() {
		showShareCard = true
		analytics.track(event: "share_tap", properties: [
			"hasEmotion": emotionSummary != nil,
			"hasBodyLanguage": bodyLanguageAnalysis != nil,
			"hasContextual": contextualEmotion != nil,
			"hasAdvice": ownerAdvice != nil,
			"hasJokes": catJokes != nil
		])
	}
	
	func createShareCardViewModel() -> ShareCardViewModel {
		return ShareCardViewModel(
			catImageData: thumbnailData,
			emotionSummary: emotionSummary,
			bodyLanguageAnalysis: bodyLanguageAnalysis,
			contextualEmotion: contextualEmotion,
			ownerAdvice: ownerAdvice,
			catJokes: catJokes,
			captionService: captionService
		)
	}
	
	func didTapShare(result: AnalysisResult) {
		analytics.track(event: "share_tap", properties: ["confidence": result.confidence])
		Task { [weak self] in
			guard let self else { return }
			_ = try? await self.share.generateShareCard(result: result, imageData: self.thumbnailData ?? Data(), aspect: .square_1_1)
		}
	}
	
	func checkCameraPermission() async -> PermissionStatus {
		return await permissions.status(for: .camera)
	}
	
	func requestCameraPermission() async -> PermissionStatus {
		return await permissions.request(.camera)
	}

	func cancelWork() {
		analysisTask?.cancel()
		analysisTask = nil
		progress = 0
		resetParallelAnalysisResults()
		// Only reset cat detection when explicitly canceling work
		catDetectionResult = nil
		isDetectingCat = false
		optimalFrameHeight = 280
	}
	
	private func resetParallelAnalysisResults() {
		emotionSummary = nil
		bodyLanguageAnalysis = nil
		contextualEmotion = nil
		ownerAdvice = nil
		catJokes = nil
		isUploadingPhoto = false
		isAnalyzing = false
		uploadedFileUri = nil
		showShareCard = false
		// Preserve cat detection results and frame sizing during analysis
		// catDetectionResult = nil
		// isDetectingCat = false
		// optimalFrameHeight = 280
	}

	// MARK: - Private
	
	/// Compress image data for faster analysis while maintaining quality
	private func compressImageForAnalysis(_ imageData: Data) async -> Data {
		return await Task.detached {
			guard let image = UIImage(data: imageData) else {
				Log.analysis.warning("Failed to create UIImage from data, using original")
				return imageData
			}
			
			// Optimize for Gemini Vision API: balance speed vs environmental context preservation
			let compressed = ImageUtils.jpegDataFitting(
				image, 
				maxDimension: 1280,  // Preserve more detail for environmental context analysis
				targetBytes: 800_000, // ~800KB balances speed with context retention
				initialQuality: 0.82   // High quality but compressed for environmental details
			)
			
			if let compressed = compressed {
				let originalSizeMB = Double(imageData.count) / 1_000_000
				let compressedSizeMB = Double(compressed.count) / 1_000_000
				Log.analysis.info("Image compressed: \(String(format: "%.2f", originalSizeMB))MB → \(String(format: "%.2f", compressedSizeMB))MB")
				return compressed
			} else {
				Log.analysis.warning("Image compression failed, using original")
				return imageData
			}
		}.value
	}

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
	
	private func beginParallelAnalysis(photo: CapturedPhoto) async {
		// Cancel any existing work without resetting cat detection
		analysisTask?.cancel()
		analysisTask = nil
		progress = 0
		
		// Reserve usage for non-premium users
		let isPremium = await subscriptionService.isPremium
		print("🔢 Starting analysis - isPremium: \(isPremium)")
		if !isPremium {
			await usageMeter.reserve()
			let remaining = await usageMeter.remainingFreeCount()
			print("🔢 Usage reserved - remaining: \(remaining)")
		}
		
		resetParallelAnalysisResults()
		hasCommittedUsage = false  // Reset for new analysis
		isAnalyzing = true
		Log.analysis.info("Starting parallel analysis")
		transition(.processing(media: .photo))
		analytics.track(event: "parallel_analysis_start", properties: ["media": "photo"])
		
		analysisTask = Task { [weak self] in
			guard let self else { return }
			do {
				let stream = try await self.parallelAnalysis.analyzeParallel(photo: photo)
				for await update in stream {
					if Task.isCancelled { 
						Log.analysis.info("Parallel analysis task cancelled")
						self.isAnalyzing = false
						break 
					}
					await MainActor.run {
						self.handleParallelAnalysisUpdate(update)
					}
				}
			} catch {
				await self.offlineQueue.enqueue(photo: photo, audio: nil)
				await MainActor.run { 
					self.isAnalyzing = false
					self.transition(.error(message: NSLocalizedString("error_network_generic", comment: ""))) 
				}
				Haptics.error()
				self.analytics.track(event: "parallel_analysis_error", properties: ["error": error.localizedDescription])
				Log.network.error("Parallel analysis network error: \(error.localizedDescription, privacy: .public)")
				
				// Rollback usage for non-premium users on error
				let isPremium = await self.subscriptionService.isPremium
				if !isPremium {
					await self.usageMeter.rollback()
				}
			}
		}
	}
	
	private func handleParallelAnalysisUpdate(_ update: ParallelAnalysisUpdate) {
		switch update {
		case .uploadStarted:
			isUploadingPhoto = true
			progress = 0.1
			Log.analysis.info("Upload started")
		
		case .uploadCompleted(let fileUri):
			isUploadingPhoto = false
			uploadedFileUri = fileUri
			progress = 0.2
			Log.analysis.info("Upload completed: \(fileUri, privacy: .private(mask: .hash))")
			
		case .emotionSummaryCompleted(let result):
			emotionSummary = result
			progress = max(progress, 0.4)
			Log.analysis.info("Emotion summary completed")
			stopSpinnerOnFirstResponse()
			
		case .bodyLanguageCompleted(let result):
			bodyLanguageAnalysis = result
			progress = max(progress, 0.6)
			Log.analysis.info("Body language analysis completed")
			stopSpinnerOnFirstResponse()
			
		case .contextualEmotionCompleted(let result):
			contextualEmotion = result
			progress = max(progress, 0.8)
			Log.analysis.info("Contextual emotion analysis completed")
			stopSpinnerOnFirstResponse()
			
		case .ownerAdviceCompleted(let result):
			ownerAdvice = result
			progress = max(progress, 0.8)
			Log.analysis.info("Owner advice completed")
			stopSpinnerOnFirstResponse()
			checkAnalysisCompletion()
			
		case .catJokesCompleted(let result):
			catJokes = result
			progress = 1.0
			Log.analysis.info("Cat jokes completed")
			// Don't stop spinner here - this is bonus content after main analysis
			checkAnalysisCompletion()
			
		case .failed(let message):
			transition(.error(message: message))
			isAnalyzing = false
			Haptics.error()
			analytics.track(event: "parallel_analysis_partial_failure", properties: ["message": message])
			Log.analysis.error("Parallel analysis partial failure: \(message, privacy: .public)")
		}
	}
	
	private func stopSpinnerOnFirstResponse() {
		if isAnalyzing {
			Log.analysis.info("First analysis response received - stopping spinner")
			isAnalyzing = false
			
			// Commit usage on FIRST successful response (not completion)
			if !hasCommittedUsage {
				hasCommittedUsage = true
				print("🔢 First successful response - committing usage")
				Task { [weak self] in
					guard let self else { return }
					let isPremium = await self.subscriptionService.isPremium
					print("🔢 About to commit on first response - isPremium: \(isPremium)")
					if !isPremium {
						await self.usageMeter.commit()
						let remaining = await self.usageMeter.remainingFreeCount()
						let newUsedCount = self.dailyLimit - remaining
						print("🔢 Usage updated on first response: used=\(newUsedCount), remaining=\(remaining), limit=\(self.dailyLimit)")
						await MainActor.run {
							self.usedCount = newUsedCount
						}
					}
				}
			}
		}
	}
	
	private func checkAnalysisCompletion() {
		// Check if all core analyses are complete
		let coreAnalysesComplete = emotionSummary != nil && bodyLanguageAnalysis != nil && 
								   contextualEmotion != nil && ownerAdvice != nil
		
		Log.analysis.info("Analysis completion check: core=\(coreAnalysesComplete)")
		Log.analysis.info("Analysis status: emotion=\(self.emotionSummary != nil), body=\(self.bodyLanguageAnalysis != nil), context=\(self.contextualEmotion != nil), advice=\(self.ownerAdvice != nil), jokes=\(self.catJokes != nil)")
		
		// Complete as soon as all core analyses are done - cat jokes are bonus content
		if coreAnalysesComplete {
			print("🔢 Core analyses complete - hasCommittedUsage: \(hasCommittedUsage)")
			progress = 1.0
			Haptics.success()
			Log.analysis.info("Core analyses complete - finishing (cat jokes optional)")
			
			// Create a combined result for the UI (for backward compatibility)
			let combinedText = """
				Emotion: \(emotionSummary?.description ?? "")
				
				Body Language: \(bodyLanguageAnalysis?.overallMood ?? "")
				
				Context: \(contextualEmotion?.emotionalMeaning.joined(separator: "; ") ?? "")
				
				Advice: \(ownerAdvice?.immediateActionsBulletPoints.joined(separator: "; ") ?? "")
				"""
			let result = AnalysisResult(translatedText: combinedText, confidence: 0.9, funFact: nil)
			transition(.ready(result: result))
			// Note: isAnalyzing is already set to false by stopSpinnerOnFirstResponse()
			analytics.track(event: "parallel_analysis_complete", properties: ["confidence": 0.9])
			
			// Usage will be committed on first successful response, not here
		}
	}

	private func beginAnalysis(photo: CapturedPhoto, audio: CapturedAudio?) async {
		cancelWork()
		let mediaKind: MediaDescriptor = audio == nil ? .photo : .photoWithAudio
		
		// Reserve usage for non-premium users
		let isPremium = await subscriptionService.isPremium
		if !isPremium {
			await usageMeter.reserve()
		}
		
		hasCommittedUsage = false  // Reset for new analysis
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
						
						// Usage will be committed on first successful response, not here
					case .failed(let msg):
						await self.offlineQueue.enqueue(photo: photo, audio: audio)
						await MainActor.run { self.transition(.error(message: msg)) }
						Haptics.error()
						self.analytics.track(event: "analysis_error", properties: ["message": msg])
						Log.analysis.error("Status: failed \(msg, privacy: .public)")
						
						// Rollback usage for non-premium users on error
						let isPremium = await self.subscriptionService.isPremium
						if !isPremium {
							await self.usageMeter.rollback()
						}
					}
				}
			} catch {
				await self.offlineQueue.enqueue(photo: photo, audio: audio)
				await MainActor.run { self.transition(.error(message: NSLocalizedString("error_network_generic", comment: ""))) }
				Haptics.error()
				Log.network.error("Analyze network error: \(error.localizedDescription, privacy: .public)")
				
				// Rollback usage for non-premium users on error
				let isPremium = await self.subscriptionService.isPremium
				if !isPremium {
					await self.usageMeter.rollback()
				}
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
	
	// MARK: - Cat Detection
	
	func detectCatInCurrentPhoto() async {
		guard let data = thumbnailData else { return }
		
		isDetectingCat = true
		Log.analysis.info("Starting cat detection")
		
		do {
			let result = try await detectCat(in: data)
			catDetectionResult = result
			if let result = result {
				Log.analysis.info("Cat detected successfully")
				calculateOptimalFrameHeight(for: result)
				Haptics.impact(.light)
			} else {
				Log.analysis.info("No cat detected in image")
				optimalFrameHeight = 280 // Reset to default
			}
		} catch {
			Log.analysis.error("Cat detection failed: \(error.localizedDescription, privacy: .public)")
			optimalFrameHeight = 280 // Reset to default on error
		}
		
		isDetectingCat = false
	}
	
	private func calculateOptimalFrameHeight(for catResult: CatDetectionResult) {
		guard let imageData = thumbnailData, UIImage(data: imageData) != nil else {
			optimalFrameHeight = 280
			return
		}
		
		// Get screen width (assuming full width usage with padding)
		let screenWidth = UIScreen.main.bounds.width
		let availableWidth = screenWidth - 32 // Account for padding
		
		// Add padding around cat (30% padding)
		let paddingRatio: CGFloat = 0.3
		let paddingX = catResult.boundingBox.width * paddingRatio
		let paddingY = catResult.boundingBox.height * paddingRatio
		
		let expandedCatBox = catResult.boundingBox.insetBy(dx: -paddingX, dy: -paddingY)
		
		// Ensure cat box stays within image bounds
		let constrainedCatBox = expandedCatBox.intersection(
			CGRect(origin: .zero, size: catResult.imageSize)
		)
		
		// Calculate what height we need to show this cat box properly
		let catAspectRatio = constrainedCatBox.width / constrainedCatBox.height
		
		var targetHeight: CGFloat
		
		if catAspectRatio > (availableWidth / 280) {
			// Cat box is wider relative to container - fit to width
			targetHeight = availableWidth / catAspectRatio
		} else {
			// Cat box is taller relative to container - use calculated height
			let catWidthInFrame = constrainedCatBox.width * (availableWidth / catResult.imageSize.width)
			targetHeight = catWidthInFrame / catAspectRatio
		}
		
		// Constrain height to reasonable bounds
		let minHeight: CGFloat = 200
		let maxHeight: CGFloat = min(500, UIScreen.main.bounds.height * 0.6)
		
		optimalFrameHeight = max(minHeight, min(maxHeight, targetHeight))
		
		Log.analysis.info("Calculated optimal frame height: \(self.optimalFrameHeight) for cat box: \(NSCoder.string(for: constrainedCatBox))")
	}
	
	private func detectCat(in imageData: Data) async throws -> CatDetectionResult? {
		// Check if running in simulator - Vision animal detection often doesn't work in simulator
		#if targetEnvironment(simulator)
		Log.analysis.info("Running in simulator - using mock cat detection")
		return mockCatDetectionForSimulator(imageData: imageData)
		#else
		
		return try await withCheckedThrowingContinuation { continuation in
			var isResumed = false
			
			guard let image = UIImage(data: imageData),
				  let cgImage = image.cgImage else {
				if !isResumed {
					isResumed = true
					continuation.resume(throwing: CatDetectionError.invalidImageData)
				}
				return
			}
			
			let request = VNRecognizeAnimalsRequest { request, error in
				guard !isResumed else { return }
				
				if let error = error {
					isResumed = true
					continuation.resume(throwing: CatDetectionError.visionError(error))
					return
				}
				
				guard let observations = request.results as? [VNRecognizedObjectObservation] else {
					isResumed = true
					continuation.resume(returning: nil)
					return
				}
				
				// Find the cat with highest confidence
				var bestCatObservation: VNRecognizedObjectObservation?
				var bestConfidence: Double = 0
				
				for observation in observations {
					for label in observation.labels {
						if label.identifier.lowercased() == "cat" && 
						   Double(label.confidence) > 0.7 &&
						   Double(label.confidence) > bestConfidence {
							bestCatObservation = observation
							bestConfidence = Double(label.confidence)
						}
					}
				}
				
				isResumed = true
				if let catObservation = bestCatObservation {
					let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
					let boundingBox = self.convertVisionBoundingBox(
						catObservation.boundingBox,
						to: imageSize
					)
					
					let result = CatDetectionResult(
						boundingBox: boundingBox,
						confidence: bestConfidence,
						imageSize: imageSize
					)
					continuation.resume(returning: result)
				} else {
					continuation.resume(returning: nil)
				}
			}
			
			let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
			do {
				try handler.perform([request])
			} catch {
				if !isResumed {
					isResumed = true
					continuation.resume(throwing: CatDetectionError.visionError(error))
				}
			}
		}
		#endif
	}
	
	#if targetEnvironment(simulator)
	private func mockCatDetectionForSimulator(imageData: Data) -> CatDetectionResult? {
		guard let image = UIImage(data: imageData) else { return nil }
		
		let imageSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
		
		// Create a mock bounding box in the center-ish area of the image
		let mockWidth = imageSize.width * 0.4  // 40% of image width
		let mockHeight = imageSize.height * 0.5 // 50% of image height
		let mockX = (imageSize.width - mockWidth) * 0.3  // Slightly off-center
		let mockY = (imageSize.height - mockHeight) * 0.2 // Upper portion
		
		let mockBoundingBox = CGRect(
			x: mockX,
			y: mockY,
			width: mockWidth,
			height: mockHeight
		)
		
		// Simulate 90% confidence
		return CatDetectionResult(
			boundingBox: mockBoundingBox,
			confidence: 0.9,
			imageSize: imageSize
		)
	}
	#endif
	
	private func convertVisionBoundingBox(_ visionBox: CGRect, to imageSize: CGSize) -> CGRect {
		let x = visionBox.origin.x * imageSize.width
		let y = (1 - visionBox.origin.y - visionBox.height) * imageSize.height
		let width = visionBox.width * imageSize.width
		let height = visionBox.height * imageSize.height
		
		return CGRect(x: x, y: y, width: width, height: height)
	}
}

// MARK: - Cat Detection Models

struct CatDetectionResult: Sendable, Equatable {
	let boundingBox: CGRect
	let confidence: Double
	let imageSize: CGSize
}

enum CatDetectionError: Error, LocalizedError {
	case invalidImageData
	case visionError(Error)
	
	var errorDescription: String? {
		switch self {
		case .invalidImageData:
			return "Invalid image data"
		case .visionError(let error):
			return "Vision framework error: \(error.localizedDescription)"
		}
	}
}
