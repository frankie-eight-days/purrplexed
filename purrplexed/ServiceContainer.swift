//
//  ServiceContainer.swift
//  Purrplexed
//
//  Lightweight DI container and Env loader (reads Env.plist).
//

import Foundation
import SwiftUI

/// Environment configuration loaded from Env.plist (no secrets)
struct Env: Sendable {
	let apiBaseURL: URL?
	let analyzePath: String
	let freeDailyLimit: Int
	let featureSavePremium: Bool
	let appKey: String?

	static func load() -> Env {
		guard let url = Bundle.main.url(forResource: "Env", withExtension: "plist"),
		      let data = try? Data(contentsOf: url),
		      let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
		else {
			return Env(apiBaseURL: nil, analyzePath: "/api/analyze-cat", freeDailyLimit: 5, featureSavePremium: true, appKey: nil)
		}
		let apiString = plist["API_BASE_URL"] as? String
		let apiURL = apiString.flatMap { URL(string: $0) }
		let freeDailyLimit = plist["FREE_DAILY_LIMIT"] as? Int ?? 5
		let featureSavePremium = plist["FEATURE_SAVE_PREMIUM"] as? Bool ?? true
		let analyzePath = (plist["ANALYZE_PATH"] as? String) ?? "/api/analyze-cat"
		let appKey = plist["APP_KEY"] as? String
		return Env(apiBaseURL: apiURL, analyzePath: analyzePath, freeDailyLimit: freeDailyLimit, featureSavePremium: featureSavePremium, appKey: appKey)
	}
}

/// Protocols for services (defined elsewhere)
protocol UsageMeterServiceProtocol: AnyObject, Sendable {
	func canStartJob() async -> Bool
	func remainingFreeCount() async -> Int
	func reserve() async
	func commit() async
	func rollback() async
}

protocol ImageProcessingService: Sendable {
	func submit(imageData: Data) async throws -> String
	func statusStream(jobId: String) -> AsyncStream<ProcessingStatus>
}

enum ProcessingStatus: Equatable, Sendable {
	case queued
	case processing(progress: Double)
	case completed
	case failed(message: String)
}

actor JobOrchestrator: Sendable {
	private let imageService: ImageProcessingService
	private let usageService: UsageMeterServiceProtocol
	private let subscriptionService: SubscriptionServiceProtocol

	init(imageService: ImageProcessingService, usageService: UsageMeterServiceProtocol, subscriptionService: SubscriptionServiceProtocol) {
		self.imageService = imageService
		self.usageService = usageService
		self.subscriptionService = subscriptionService
	}

	/// Submits an image for processing and returns an AsyncStream of statuses.
	func startJob(imageData: Data) async throws -> (jobId: String, stream: AsyncStream<ProcessingStatus>) {
		let isPremium = await subscriptionService.isPremium
		if !isPremium {
			await usageService.reserve()
		}
		let jobId = try await imageService.submit(imageData: imageData)
		return (jobId, imageService.statusStream(jobId: jobId))
	}

	/// Mark job as completed successfully.
	func finishSuccess() async {
		let isPremium = await subscriptionService.isPremium
		if !isPremium {
			await usageService.commit()
		}
	}

	/// Mark job as failed/cancelled.
	func finishFailure() async {
		let isPremium = await subscriptionService.isPremium
		if !isPremium {
			await usageService.rollback()
		}
	}
}

/// Service container for DI
@MainActor
final class ServiceContainer: ObservableObject {
	let env: Env
	let router: AppRouter
	let usageMeter: UsageMeterServiceProtocol
	let imageService: ImageProcessingService
	let jobOrchestrator: JobOrchestrator
	let subscriptionService: SubscriptionServiceProtocol
	// New services
	let mediaService: MediaService
	let analysisService: AnalysisService
	let parallelAnalysisService: ParallelAnalysisService
	let shareService: ShareService
	let analyticsService: AnalyticsService
	let permissionsService: PermissionsService
	let offlineQueue: OfflineQueueing
	let captionService: CaptionGenerationService

	init(
		env: Env = .load(),
		router: AppRouter,
		usageMeter: UsageMeterServiceProtocol,
		imageService: ImageProcessingService,
		subscriptionService: SubscriptionServiceProtocol? = nil,
		mediaService: MediaService = ProductionMediaService(),
		analysisService: AnalysisService = MockAnalysisService(),
		parallelAnalysisService: ParallelAnalysisService? = nil,
		shareService: ShareService = ProductionShareService(),
		analyticsService: AnalyticsService = ProductionAnalyticsService(),
		permissionsService: PermissionsService = ProductionPermissionsService(),
		offlineQueue: OfflineQueueing = InMemoryOfflineQueue(),
		captionService: CaptionGenerationService? = nil
	) {
		self.env = env
		self.router = router
		self.usageMeter = usageMeter
		self.imageService = imageService
		self.subscriptionService = subscriptionService ?? SubscriptionService()
		self.jobOrchestrator = JobOrchestrator(imageService: imageService, usageService: usageMeter, subscriptionService: self.subscriptionService)
		self.mediaService = mediaService
		// Prefer backend service when an API URL is present, otherwise use provided mock
		if let backendURL = env.apiBaseURL ?? URL(string: "https://purrplexed-backend.vercel.app") {
			self.analysisService = BackendAnalysisService(
				baseURL: backendURL, 
				analyzePath: env.analyzePath, 
				prompt: "Analyze this cat's body language. Summarize mood, cues, and likely needs in 2-3 sentences.",
				appKey: env.appKey
			)
			self.parallelAnalysisService = HTTPParallelAnalysisService(baseURL: backendURL, appKey: env.appKey)
		} else {
			self.analysisService = analysisService
			self.parallelAnalysisService = parallelAnalysisService ?? MockParallelAnalysisService()
		}
		self.shareService = shareService
		self.analyticsService = analyticsService
		self.permissionsService = permissionsService
		self.offlineQueue = offlineQueue
		
		// Caption service - prefer backend service when available, otherwise use local
		if let backendURL = env.apiBaseURL ?? URL(string: "https://purrplexed-backend.vercel.app") {
			self.captionService = captionService ?? HTTPCaptionGenerationService(baseURL: backendURL, appKey: env.appKey)
		} else {
			self.captionService = captionService ?? LocalCaptionGenerationService()
		}
	}
}

/// SwiftUI injection key
private struct ServiceContainerKey: EnvironmentKey { static let defaultValue: ServiceContainer? = nil }
extension EnvironmentValues { var services: ServiceContainer? { get { self[ServiceContainerKey.self] } set { self[ServiceContainerKey.self] = newValue } } }

extension View {
	func inject(_ services: ServiceContainer) -> some View { environment(\.services, services) }
}
