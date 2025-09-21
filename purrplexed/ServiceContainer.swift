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
	let freeDailyLimit: Int
	let featureSavePremium: Bool

	static func load() -> Env {
		guard let url = Bundle.main.url(forResource: "Env", withExtension: "plist"),
		      let data = try? Data(contentsOf: url),
		      let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
		else {
			return Env(apiBaseURL: nil, freeDailyLimit: 5, featureSavePremium: true)
		}
		let apiString = plist["API_BASE_URL"] as? String
		let apiURL = apiString.flatMap { URL(string: $0) }
		let freeDailyLimit = plist["FREE_DAILY_LIMIT"] as? Int ?? 5
		let featureSavePremium = plist["FEATURE_SAVE_PREMIUM"] as? Bool ?? true
		return Env(apiBaseURL: apiURL, freeDailyLimit: freeDailyLimit, featureSavePremium: featureSavePremium)
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

	init(imageService: ImageProcessingService, usageService: UsageMeterServiceProtocol) {
		self.imageService = imageService
		self.usageService = usageService
	}

	/// Submits an image for processing and returns an AsyncStream of statuses.
	func startJob(imageData: Data) async throws -> (jobId: String, stream: AsyncStream<ProcessingStatus>) {
		await usageService.reserve()
		let jobId = try await imageService.submit(imageData: imageData)
		return (jobId, imageService.statusStream(jobId: jobId))
	}

	/// Mark job as completed successfully.
	func finishSuccess() async {
		await usageService.commit()
	}

	/// Mark job as failed/cancelled.
	func finishFailure() async {
		await usageService.rollback()
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

	init(
		env: Env = .load(),
		router: AppRouter,
		usageMeter: UsageMeterServiceProtocol,
		imageService: ImageProcessingService
	) {
		self.env = env
		self.router = router
		self.usageMeter = usageMeter
		self.imageService = imageService
		self.jobOrchestrator = JobOrchestrator(imageService: imageService, usageService: usageMeter)
	}
}

/// SwiftUI injection key
private struct ServiceContainerKey: EnvironmentKey { static let defaultValue: ServiceContainer? = nil }
extension EnvironmentValues { var services: ServiceContainer? { get { self[ServiceContainerKey.self] } set { self[ServiceContainerKey.self] = newValue } } }

extension View {
	func inject(_ services: ServiceContainer) -> some View { environment(\.services, services) }
}
