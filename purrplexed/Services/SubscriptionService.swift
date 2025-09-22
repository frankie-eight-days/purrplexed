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
	
	private var updateListenerTask: Task<Void, Error>?
	
	var isPremium: Bool {
		get async {
			await MainActor.run {
				currentSubscription?.state == .subscribed
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
