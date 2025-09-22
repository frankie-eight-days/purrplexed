//
//  SettingsViewModel.swift
//  Purrplexed
//
//  Settings feature model.
//

import Foundation
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
	@Published var appVersion: String
	@Published var showDebugMenu = false
	
	private let services: ServiceContainer
	private var versionTapCount = 0
	private var lastTapTime = Date()

	init(services: ServiceContainer) {
		self.services = services
		self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
	}
	
	// MARK: - Debug Methods
	
	func handleVersionTap() {
		let now = Date()
		
		// Reset tap count if more than 2 seconds since last tap
		if now.timeIntervalSince(lastTapTime) > 2.0 {
			versionTapCount = 0
		}
		
		lastTapTime = now
		versionTapCount += 1
		
		print("🔧 Version tapped \(versionTapCount) times")
		
		// Show debug menu after 4 rapid taps
		if versionTapCount >= 4 {
			showDebugMenu = true
			versionTapCount = 0
			print("🔧 Debug menu activated!")
		}
	}
	
	func resetUsage() {
		Task { [weak self] in
			guard let self else { return }
			// Delete keychain entries to reset usage
			let keychain = KeychainHelper()
			_ = keychain.delete(for: "usage_consumed")
			_ = keychain.delete(for: "usage_reserved")
			_ = keychain.delete(for: "usage_last_reset_date")
			print("🔧 Usage reset - keychain cleared")
			
			// Refresh the capture view model if accessible
			// (This will pick up the reset values on next operation)
		}
	}
	
	func togglePremiumStatus() {
		Task { [weak self] in
			guard let self else { return }
			let currentStatus = await self.services.subscriptionService.isPremium
			
			if let mockService = self.services.subscriptionService as? MockSubscriptionService {
				// Toggle mock premium status
				UserDefaults.standard.set(!currentStatus, forKey: "mock_premium_status")
				print("🔧 Premium status toggled to: \(!currentStatus)")
			} else {
				print("🔧 Can only toggle premium in debug/mock mode")
			}
		}
	}
}
