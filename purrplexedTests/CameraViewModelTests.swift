//
//  CameraViewModelTests.swift
//  purrplexedTests
//
//  Unit tests for CameraViewModel FSM and cancellation.
//

import XCTest
@testable import purrplexed

final class CameraViewModelTests: XCTestCase {
	func makeVM() -> CameraViewModel {
		let env = Env(apiBaseURL: nil, freeDailyLimit: 5, featureSavePremium: true)
		let router = AppRouter()
		let usage = UsageMeterService(limit: env.freeDailyLimit)
		let image = MockImageProcessingService()
		let container = ServiceContainer(env: env, router: router, usageMeter: usage, imageService: image)
		return CameraViewModel(services: container)
	}

	func test_illegalTransitionsAreIgnored() async {
		let vm = makeVM()
		XCTAssertEqual(vm.state, .idle)
		vm.test_forceTransition(.result(jobId: "x"))
		XCTAssertEqual(vm.state, .idle) // ignored
	}

	func test_secondCaptureCancelsFirst() async {
		let vm = makeVM()
		await MainActor.run { vm.captureTapped() }
		// Immediately start second capture which should cancel first task
		await MainActor.run { vm.captureTapped() }
		// The first task should be cancelled
		XCTAssertTrue(vm.test_isTaskCancelled)
	}
}
