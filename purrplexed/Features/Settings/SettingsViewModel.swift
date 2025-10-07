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
	
	#if DEBUG
	@Published var showDebugMenu = false
	private var versionTapCount = 0
	private var lastTapTime = Date()
	#endif
	
	private let services: ServiceContainer

	init(services: ServiceContainer) {
		self.services = services
		self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
	}
	
	// MARK: - Debug Methods (Only Available in DEBUG Builds)
	
	func handleVersionTap() {
		#if DEBUG
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
		#endif
	}
	
	#if DEBUG
	func resetUsage() {
		Task {
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
			if let mockService = self.services.subscriptionService as? MockSubscriptionService {
				let oldStatus = await mockService.isPremium
				let newValue = await mockService.togglePremium()
				await MainActor.run {
					NotificationCenter.default.post(name: .subscriptionStatusDidChange, object: nil, userInfo: ["isPremium": newValue, "source": "toggle", "previous": oldStatus])
				}
				print("🔧 Premium status toggled from \(oldStatus ? "premium" : "free") to \(newValue ? "premium" : "free")")
			} else {
				print("🔧 Toggle premium not supported outside mock service")
			}
		}
	}

	func demoteToFree() {
		Task { [weak self] in
			guard let self else { return }
			if let mockService = self.services.subscriptionService as? MockSubscriptionService {
				let oldStatus = await mockService.isPremium
				await mockService.setPremium(false)
				await MainActor.run {
					NotificationCenter.default.post(name: .subscriptionStatusDidChange, object: nil, userInfo: ["isPremium": false, "source": "demote", "previous": oldStatus])
				}
				print("🔧 Premium status forced to free (was \(oldStatus ? "premium" : "free"))")
			} else {
				print("🔧 Demote to free not supported outside mock service")
			}
		}
	}
	
	func showPaywall() {
		services.router.present(.paywall)
		print("🔧 Showing paywall")
	}
	
	func showPaywallFromDebug() {
		// Close debug menu and settings, then show paywall
		// First dismiss everything
		services.router.dismiss()
		// Then after a delay, show the paywall
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
			self.services.router.present(.paywall)
			print("🔧 Showing paywall from debug")
		}
	}
	#endif
}

extension Notification.Name {
	static let subscriptionStatusDidChange = Notification.Name("subscriptionStatusDidChange")
}
