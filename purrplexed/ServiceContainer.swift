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
	func totalDailyLimit() async -> Int
	func reserve() async
	func commit() async
	func rollback() async
}

/// Service container for DI
@MainActor
final class ServiceContainer: ObservableObject {
	let env: Env
	let router: AppRouter
	let usageMeter: UsageMeterServiceProtocol
	let subscriptionService: SubscriptionServiceProtocol
	let mediaService: MediaService
	let analysisService: AnalysisService
	let parallelAnalysisService: ParallelAnalysisService
	let analyticsService: AnalyticsService
	let permissionsService: PermissionsService

	init(
		env: Env = .load(),
		router: AppRouter,
		usageMeter: UsageMeterServiceProtocol,
		subscriptionService: SubscriptionServiceProtocol? = nil,
		mediaService: MediaService = ProductionMediaService(),
		analysisService: AnalysisService? = nil,
		parallelAnalysisService: ParallelAnalysisService? = nil,
		analyticsService: AnalyticsService = ProductionAnalyticsService(),
		permissionsService: PermissionsService = ProductionPermissionsService()
	) {
		self.env = env
		self.router = router
		self.usageMeter = usageMeter
		#if DEBUG
		self.subscriptionService = subscriptionService ?? MockSubscriptionService()
		#else
		self.subscriptionService = subscriptionService ?? SubscriptionService()
		#endif
		self.mediaService = mediaService
		if let analysisService {
			self.analysisService = analysisService
		} else if env.apiBaseURL != nil {
			self.analysisService = ProductionAnalysisService(env: env)
		} else {
			self.analysisService = MockAnalysisService()
		}

		if let parallelAnalysisService {
			self.parallelAnalysisService = parallelAnalysisService
		} else if let baseURL = env.apiBaseURL {
			self.parallelAnalysisService = HTTPParallelAnalysisService(
				baseURL: baseURL,
				uploadPath: env.analyzePath == "/api/analyze-cat" ? "/api/upload" : env.analyzePath.replacingOccurrences(of: "analyze", with: "upload"),
				analyzePath: env.analyzePath,
				appKey: env.appKey
			)
		} else {
			self.parallelAnalysisService = MockParallelAnalysisService()
		}
		self.analyticsService = analyticsService
		self.permissionsService = permissionsService
	}
}

/// SwiftUI injection key
private struct ServiceContainerKey: EnvironmentKey { static let defaultValue: ServiceContainer? = nil }
extension EnvironmentValues { var services: ServiceContainer? { get { self[ServiceContainerKey.self] } set { self[ServiceContainerKey.self] = newValue } } }

extension View {
	func inject(_ services: ServiceContainer) -> some View { environment(\.services, services) }
}
