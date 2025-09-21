//
//  CaptureAnalysisViewModelTests.swift
//  purrplexedTests
//
//  Tests for unified CaptureAnalysisViewModel FSM.
//

import XCTest
@testable import purrplexed

final class CaptureAnalysisViewModelTests: XCTestCase {
	func makeVM() -> CaptureAnalysisViewModel {
		CaptureAnalysisViewModel(
			media: MockMediaService(),
			analysis: MockAnalysisService(),
			parallelAnalysis: MockParallelAnalysisService(),
			share: MockShareService(),
			analytics: MockAnalyticsService(),
			permissions: MockPermissionsService(),
			offlineQueue: InMemoryOfflineQueue()
		)
	}

	func test_flowIdleToReady() async throws {
		let vm = makeVM()
		XCTAssertEqual(vm.state, .idle)
		await MainActor.run { vm.didTapCapture() }
		try await Task.sleep(nanoseconds: 1_200_000_000)
		if case .ready = vm.state { } else { XCTFail("Expected ready") }
	}

	func test_cancelStopsProgress() async throws {
		let vm = makeVM()
		await MainActor.run { vm.didTapCapture() }
		try await Task.sleep(nanoseconds: 300_000_000)
		await MainActor.run { vm.cancelWork() }
		let progressAfter = vm.progress
		try await Task.sleep(nanoseconds: 400_000_000)
		XCTAssertEqual(progressAfter, vm.progress)
	}
}
