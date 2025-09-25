//
//  SubscriptionService.swift
//  Purrplexed
//
//  Manages premium subscriptions and StoreKit integration.
//

import Foundation
import StoreKit

/// Protocol for managing premium subscriptions
protocol SubscriptionServiceProtocol: AnyObject, Sendable {
	var isPremium: Bool { get async }
	func restorePurchases() async throws
	func purchase(productId: String) async throws -> Bool
	func getAvailableProducts() async throws -> [Product]
	func refreshPremiumStatus() async
	func setDebugPremiumOverride(_ value: Bool?) async
}

/// Production SubscriptionService using StoreKit 2
@MainActor
final class SubscriptionService: ObservableObject, SubscriptionServiceProtocol {
	@Published private(set) var currentSubscription: Product.SubscriptionInfo.Status?
	@Published private(set) var availableProducts: [Product] = []
	
	private let productIds = [
		"purrplexed_monthly_premium",
		"purrplexed_yearly_premium"
	]
	private let premiumOverrideKey = "debug_premium_override"
	
	private var updateListenerTask: Task<Void, Error>?
	
	var isPremium: Bool {
		get async {
			if let override = debugPremiumOverride {
				return override
			}
			return currentSubscription?.state == .subscribed
		}
	}

	private var debugPremiumOverride: Bool? {
		get {
			UserDefaults.standard.object(forKey: premiumOverrideKey) as? Bool
		}
		set {
			if let value = newValue {
				UserDefaults.standard.set(value, forKey: premiumOverrideKey)
			} else {
				UserDefaults.standard.removeObject(forKey: premiumOverrideKey)
			}
		}
	}
	
	init() {
		updateListenerTask = listenForTransactions()
		Task {
			await loadProducts()
			await updateCustomerProductStatus()
		}
	}
	
	deinit {
		updateListenerTask?.cancel()
	}
	
	func restorePurchases() async throws {
		try await AppStore.sync()
		await updateCustomerProductStatus()
	}
	
	func purchase(productId: String) async throws -> Bool {
		guard let product = availableProducts.first(where: { $0.id == productId }) else {
			throw SubscriptionError.productNotFound
		}
		
		let result = try await product.purchase()
		
		switch result {
		case .success(let verification):
			let transaction = try await checkVerified(verification)
			await updateCustomerProductStatus()
			await transaction.finish()
			return true
			
		case .userCancelled:
			return false
			
		case .pending:
			return false
			
		@unknown default:
			return false
		}
	}
	
	func getAvailableProducts() async throws -> [Product] {
		return availableProducts
	}

	func refreshPremiumStatus() async {
		await updateCustomerProductStatus()
	}

	func setDebugPremiumOverride(_ value: Bool?) async {
		let previous = debugPremiumOverride
		debugPremiumOverride = value
		if value == nil {
			print("🔧 Debug premium override removed (was: \(previous.map { $0 ? "enabled" : "disabled" } ?? "none"))")
		} else {
			print("🔧 Debug premium override set to \(value == true ? "premium" : "free") (was: \(previous.map { $0 ? "premium" : "free" } ?? "none"))")
		}
		objectWillChange.send()
	}
	
	private func loadProducts() async {
		do {
			availableProducts = try await Product.products(for: productIds)
		} catch {
			print("Failed to load products: \(error)")
		}
	}
	
	private func updateCustomerProductStatus() async {
		for await result in Transaction.currentEntitlements {
			do {
				let transaction = try await checkVerified(result)
				
				switch transaction.productType {
				case .autoRenewable:
					if let subscription = availableProducts.first(where: { $0.id == transaction.productID }) {
						currentSubscription = try? await subscription.subscription?.status.first
					}
				default:
					break
				}
			} catch {
				print("Transaction verification failed: \(error)")
			}
		}
	}
	
	private func listenForTransactions() -> Task<Void, Error> {
		return Task.detached {
			for await result in Transaction.updates {
				do {
					let transaction = try await self.checkVerified(result)
					await self.updateCustomerProductStatus()
					await transaction.finish()
				} catch {
					print("Transaction failed verification")
				}
			}
		}
	}
	
	private func checkVerified<T>(_ result: VerificationResult<T>) async throws -> T {
		switch result {
		case .unverified:
			throw SubscriptionError.failedVerification
		case .verified(let safe):
			return safe
		}
	}
}

/// Mock SubscriptionService for development and testing
actor MockSubscriptionService: SubscriptionServiceProtocol {
	private var _isPremium: Bool {
		get {
			UserDefaults.standard.bool(forKey: "mock_premium_status")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "mock_premium_status")
		}
	}
	
	var isPremium: Bool {
		get async { _isPremium }
	}
	
	func restorePurchases() async throws {
		// Simulate restore - check UserDefaults
		print("🔧 Mock: Restored premium status = \(_isPremium)")
	}
	
	func purchase(productId: String) async throws -> Bool {
		// Simulate purchase
		_isPremium = true
		print("🔧 Mock: Purchased premium = true")
		return true
	}

	func refreshPremiumStatus() async {
		// Nothing needed for mock; state derived from UserDefaults
	}

	func setDebugPremiumOverride(_ value: Bool?) async {
		let resolved = value ?? false
		let previous = _isPremium
		_isPremium = resolved
		print("🔧 Mock: Premium override set to \(resolved) (was: \(previous))")
	}

	func setPremiumOverride(_ value: Bool?) async { _isPremium = value ?? _isPremium }

	func setPremium(_ value: Bool) async {
		_isPremium = value
		print("🔧 Mock: Premium status manually set to \(value)")
		NotificationCenter.default.post(name: .subscriptionStatusDidChange, object: nil, userInfo: ["isPremium": value, "source": "mockServiceSet"])
	}

	func togglePremium() async -> Bool {
		let newValue = !_isPremium
		_isPremium = newValue
		print("🔧 Mock: Premium status toggled to \(newValue)")
		NotificationCenter.default.post(name: .subscriptionStatusDidChange, object: nil, userInfo: ["isPremium": newValue, "source": "mockServiceToggle"])
		return newValue
	}
	
	func getAvailableProducts() async throws -> [Product] {
		// Return empty array for mock
		return []
	}
}

enum SubscriptionError: Error {
	case productNotFound
	case failedVerification
	case purchaseFailed
}
