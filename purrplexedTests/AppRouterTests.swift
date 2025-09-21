//
//  AppRouterTests.swift
//  purrplexedTests
//
//  Tests for AppRouter route mutation behavior.
//

import XCTest
@testable import purrplexed

final class AppRouterTests: XCTestCase {
	func test_presentSettingsSelectsTabDoesNotSetModal() {
		let router = AppRouter()
		router.present(.settings)
		XCTAssertEqual(router.selectedTab, .settings)
		XCTAssertNil(router.route)
	}
	
	func test_presentResultSetsModal() {
		let router = AppRouter()
		router.present(.result(jobId: "123"))
		XCTAssertEqual(router.route, .result(jobId: "123"))
	}
}
