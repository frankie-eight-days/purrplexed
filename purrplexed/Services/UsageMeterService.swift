//
//  UsageMeterService.swift
//  Purrplexed
//
//  Actor managing free daily usage counters.
//

import Foundation

actor UsageMeterService: UsageMeterServiceProtocol {
	private let dailyLimit: Int
	private var consumed: Int = 0
	private var reserved: Int = 0
	private var lastResetDate: Date = Date()

	init(limit: Int) {
		self.dailyLimit = max(0, limit)
	}

	private func resetIfNeeded(now: Date = Date()) {
		let calendar = Calendar.current
		if !calendar.isDate(now, inSameDayAs: lastResetDate) {
			consumed = 0
			reserved = 0
			lastResetDate = now
		}
	}

	func canStartJob() async -> Bool {
		resetIfNeeded()
		return (consumed + reserved) < dailyLimit
	}

	func remainingFreeCount() async -> Int {
		resetIfNeeded()
		return max(0, dailyLimit - (consumed + reserved))
	}

	func reserve() async {
		resetIfNeeded()
		reserved = min(dailyLimit, reserved + 1)
	}

	func commit() async {
		resetIfNeeded()
		if reserved > 0 { reserved -= 1 }
		consumed = min(dailyLimit, consumed + 1)
	}

	func rollback() async {
		resetIfNeeded()
		if reserved > 0 { reserved -= 1 }
	}
}
