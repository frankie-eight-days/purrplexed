//
//  UsageMeterService.swift
//  Purrplexed
//
//  Actor managing free daily usage counters.
//

import Foundation

actor UsageMeterService: UsageMeterServiceProtocol {
	private let dailyLimit: Int
	private let keychain = KeychainHelper()
	
	// Keychain keys
	private let consumedKey = "usage_consumed"
	private let reservedKey = "usage_reserved"  
	private let lastResetDateKey = "usage_last_reset_date"
	
	private var consumed: Int {
		get { keychain.getInt(for: consumedKey) ?? 0 }
		set { _ = keychain.set(newValue, for: consumedKey) }
	}
	
	private var reserved: Int {
		get { keychain.getInt(for: reservedKey) ?? 0 }
		set { _ = keychain.set(newValue, for: reservedKey) }
	}
	
	private var lastResetDate: Date {
		get { keychain.getDate(for: lastResetDateKey) ?? Date() }
		set { _ = keychain.set(newValue, for: lastResetDateKey) }
	}

	init(limit: Int) {
		self.dailyLimit = max(0, limit)
		print("🔐 UsageMeterService initialized with keychain storage")
		print("🔐 Current state: consumed=\(consumed), reserved=\(reserved), lastReset=\(lastResetDate)")
	}

	private func resetIfNeeded(now: Date = Date()) {
		let calendar = Calendar.current
		if !calendar.isDate(now, inSameDayAs: lastResetDate) {
			print("🔐 Daily reset triggered - clearing usage counts")
			consumed = 0
			reserved = 0
			lastResetDate = now
			print("🔐 Reset complete: consumed=\(consumed), reserved=\(reserved)")
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
		let newReserved = min(dailyLimit, reserved + 1)
		reserved = newReserved
		print("🔐 Reserved usage: reserved=\(reserved), consumed=\(consumed)")
	}

	func commit() async {
		resetIfNeeded()
		if reserved > 0 { 
			reserved -= 1 
		}
		let newConsumed = min(dailyLimit, consumed + 1)
		consumed = newConsumed
		print("🔐 Committed usage: consumed=\(consumed), reserved=\(reserved)")
	}

	func rollback() async {
		resetIfNeeded()
		if reserved > 0 { 
			reserved -= 1 
			print("🔐 Rolled back usage: reserved=\(reserved), consumed=\(consumed)")
		}
	}
}
