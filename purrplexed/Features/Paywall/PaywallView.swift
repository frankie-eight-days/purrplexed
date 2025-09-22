//
//  PaywallView.swift
//  Purrplexed
//
//  Compelling paywall for unlimited cat analysis.
//

import SwiftUI

struct PaywallView: View {
	var onClose: () -> Void
	var onUpgrade: () -> Void = {}
	@Environment(\.services) private var services
	@State private var isPurchasing = false
	@State private var purchaseError: String?
	
	var body: some View {
		NavigationView {
			ScrollView {
				VStack(spacing: DS.Spacing.xl) {
					headerSection
					featuresSection
					pricingSection
					actionButtons
				}
				.padding(DS.Spacing.l)
			}
			.navigationTitle("Purrplexed Premium")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button("Maybe Later") { onClose() }
						.foregroundStyle(.secondary)
				}
			}
		}
	}
	
	private var headerSection: some View {
		VStack(spacing: DS.Spacing.l) {
			Image(systemName: "heart.circle.fill")
				.font(.system(size: 80))
				.foregroundStyle(.pink)
			
			Text("You've used your 3 free analyses today!")
				.font(DS.Typography.titleFont())
				.multilineTextAlignment(.center)
			
			Text("Unlock unlimited cat insights with Premium")
				.font(DS.Typography.bodyFont())
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
		}
	}
	
	private var featuresSection: some View {
		VStack(spacing: DS.Spacing.m) {
			FeatureRow(icon: "infinity", title: "Unlimited Analyses", subtitle: "Analyze as many cats as you want, every day")
			FeatureRow(icon: "square.and.arrow.down", title: "Save & Share Results", subtitle: "Keep your favorite cat insights forever")
			FeatureRow(icon: "sparkles", title: "Priority Processing", subtitle: "Faster analysis with premium infrastructure")
			FeatureRow(icon: "heart.text.square", title: "Detailed Insights", subtitle: "Enhanced mood analysis and behavioral tips")
		}
		.padding(DS.Spacing.m)
		.background(DS.Color.pillBackground)
		.clipShape(RoundedRectangle(cornerRadius: 12))
	}
	
	private var pricingSection: some View {
		VStack(spacing: DS.Spacing.m) {
			Text("Choose Your Plan")
				.font(DS.Typography.titleFont())
			
			HStack(spacing: DS.Spacing.m) {
				PricingCard(
					title: "Monthly",
					price: "$2.99",
					period: "/month",
					isPopular: false
				)
				
				PricingCard(
					title: "Yearly",
					price: "$24.99",
					period: "/year",
					isPopular: true,
					savings: "Save 31%"
				)
			}
		}
	}
	
	private var actionButtons: some View {
		VStack(spacing: DS.Spacing.m) {
			Button(isPurchasing ? "Processing..." : "Start Premium") {
				Task {
					await startPurchase()
				}
			}
			.buttonStyle(.borderedProminent)
			.controlSize(.large)
			.frame(maxWidth: .infinity)
			.disabled(isPurchasing)
			
			if let error = purchaseError {
				Text(error)
					.font(.caption)
					.foregroundStyle(.red)
					.multilineTextAlignment(.center)
			}
			
			Button("Restore Purchases") {
				Task {
					await restorePurchases()
				}
			}
			.foregroundStyle(.secondary)
			.disabled(isPurchasing)
			
			Text("Cancel anytime • 7-day free trial")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
	}
	
	private func startPurchase() async {
		guard !isPurchasing else { return }
		isPurchasing = true
		purchaseError = nil
		
		do {
			// Try yearly first (better value)
			let success = try await services?.subscriptionService.purchase(productId: "purrplexed_yearly_premium") ?? false
			if success {
				onUpgrade()
				onClose()
			}
		} catch {
			purchaseError = "Purchase failed. Please try again."
		}
		
		isPurchasing = false
	}
	
	private func restorePurchases() async {
		guard !isPurchasing else { return }
		isPurchasing = true
		purchaseError = nil
		
		do {
			try await services?.subscriptionService.restorePurchases()
			// Check if premium after restore
			if await services?.subscriptionService.isPremium == true {
				onUpgrade()
				onClose()
			} else {
				purchaseError = "No previous purchases found."
			}
		} catch {
			purchaseError = "Restore failed. Please try again."
		}
		
		isPurchasing = false
	}
}

struct FeatureRow: View {
	let icon: String
	let title: String
	let subtitle: String
	
	var body: some View {
		HStack(spacing: DS.Spacing.m) {
			Image(systemName: icon)
				.font(.title2)
				.foregroundStyle(.blue)
				.frame(width: 24)
			
			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(DS.Typography.bodyFont())
					.fontWeight(.medium)
				Text(subtitle)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			
			Spacer()
		}
	}
}

struct PricingCard: View {
	let title: String
	let price: String
	let period: String
	let isPopular: Bool
	let savings: String?
	
	init(title: String, price: String, period: String, isPopular: Bool = false, savings: String? = nil) {
		self.title = title
		self.price = price
		self.period = period
		self.isPopular = isPopular
		self.savings = savings
	}
	
	var body: some View {
		VStack(spacing: DS.Spacing.s) {
			if let savings {
				Text(savings)
					.font(.caption)
					.fontWeight(.semibold)
					.foregroundStyle(.white)
					.padding(.horizontal, DS.Spacing.s)
					.padding(.vertical, 4)
					.background(.green)
					.clipShape(Capsule())
			}
			
			Text(title)
				.font(DS.Typography.bodyFont())
				.fontWeight(.medium)
			
			HStack(alignment: .bottom, spacing: 2) {
				Text(price)
					.font(.title)
					.fontWeight(.bold)
				Text(period)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
		.frame(maxWidth: .infinity)
		.padding()
		.background(isPopular ? DS.Color.accent.opacity(0.1) : DS.Color.pillBackground)
		.clipShape(RoundedRectangle(cornerRadius: 12))
		.overlay(
			RoundedRectangle(cornerRadius: 12)
				.stroke(isPopular ? DS.Color.accent : Color.clear, lineWidth: 2)
		)
	}
}

#Preview { PaywallView(onClose: {}) }
