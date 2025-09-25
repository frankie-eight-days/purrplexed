//
//  PaywallView.swift
//  Purrplexed
//
//  Compelling paywall for unlimited cat analysis.
//

import SwiftUI
import StoreKit

private enum SubscriptionProductId {
	static let monthly = "purrplexed_monthly_premium"
	static let yearly = "purrplexed_yearly_premium"
}

private struct SubscriptionOption: Identifiable {
	let id: String
	let title: String
	let fallbackPrice: String
	let fallbackPeriod: String
	let isPopular: Bool
	let savings: String?
}

struct PaywallView: View {
	var onClose: () -> Void
	var onUpgrade: () -> Void = {}
	@Environment(\.services) private var services
	@State private var isPurchasing = false
	@State private var purchaseError: String?
	@State private var selectedProductId: String = SubscriptionProductId.yearly
	@State private var products: [Product] = []
	@State private var isLoadingProducts = false
	@State private var hasRemainingFreeAnalyses = true
	@State private var dailyFreeLimit = 3
	@State private var maxPricingCardHeight: CGFloat = 0

	private let subscriptionOptions: [SubscriptionOption] = [
		SubscriptionOption(
			id: SubscriptionProductId.monthly,
			title: "Monthly",
			fallbackPrice: "$2.99",
			fallbackPeriod: "/month",
			isPopular: false,
			savings: nil
		),
		SubscriptionOption(
			id: SubscriptionProductId.yearly,
			title: "Yearly",
			fallbackPrice: "$24.99",
			fallbackPeriod: "/year",
			isPopular: true,
			savings: "Save 31%"
		)
	]

	private var selectedOption: SubscriptionOption? {
		subscriptionOptions.first(where: { $0.id == selectedProductId })
	}

	private var selectedProduct: Product? {
		products.first(where: { $0.id == selectedProductId })
	}

	private var startButtonTitle: String {
		if isPurchasing { return "Processing..." }
		if isLoadingProducts && products.isEmpty { return "Loading plans..." }
		let planName = selectedOption?.title ?? "Premium"
		return "Start \(planName)"
	}

	private var startButtonIcon: String {
		isPurchasing ? "hourglass" : "arrow.forward.circle.fill"
	}

	private var startButtonDisabled: Bool {
		isPurchasing || (isLoadingProducts && products.isEmpty)
	}

	private var headerPrimaryText: String {
		guard dailyFreeLimit > 0 else { return "Upgrade to unlock unlimited analyses" }
		let limitText = dailyFreeLimit == 1 ? "1 free analysis" : "\(dailyFreeLimit) free analyses"
		return hasRemainingFreeAnalyses ? "Upgrade today!" : "You've used all your \(limitText) today!"
	}
	
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
		.task {
			await loadProductsIfNeeded()
			await refreshUsageStatus()
		}
	}
	
	private var headerSection: some View {
		VStack(spacing: DS.Spacing.l) {
			Image(systemName: "heart.circle.fill")
				.font(.system(size: 80))
				.foregroundStyle(.pink)
			
			Text(headerPrimaryText)
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
		}
		.padding(DS.Spacing.m)
		.background(DS.Color.pillBackground)
		.clipShape(RoundedRectangle(cornerRadius: 12))
	}
	
	private var pricingSection: some View {
		VStack(spacing: DS.Spacing.m) {
			Text("Choose Your Plan")
				.font(DS.Typography.titleFont())
			
			if isLoadingProducts && products.isEmpty {
				ProgressView()
					.controlSize(.small)
					.progressViewStyle(.circular)
			}
			
			HStack(alignment: .top, spacing: DS.Spacing.m) {
				ForEach(subscriptionOptions, id: \.id) { option in
					Button {
						selectedProductId = option.id
						purchaseError = nil
					} label: {
						PricingCard(
							title: option.title,
							price: priceText(for: option.id, fallback: option.fallbackPrice),
							period: periodText(for: option.id, fallback: option.fallbackPeriod),
							isPopular: option.isPopular,
							savings: option.savings,
							isSelected: selectedProductId == option.id,
							maxHeight: $maxPricingCardHeight
						)
					}
					.buttonStyle(PlainButtonStyle())
				}
			}
		}
	}
	
	private var actionButtons: some View {
		VStack(spacing: DS.Spacing.m) {
			Button(action: startPurchaseAction) {
				Label(startButtonTitle, systemImage: startButtonIcon)
					.font(.headline)
			}
			.buttonStyle(.borderedProminent)
			.controlSize(.large)
			.frame(maxWidth: .infinity)
			.disabled(startButtonDisabled)
			.accessibilityLabel("Start premium subscription")
			.accessibilityHint("Completes purchase of the selected plan")
			
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

	private func startPurchaseAction() {
		Task { await startPurchase() }
	}

	private func startPurchase() async {
		let productId = selectedProductId
		guard !isPurchasing else { return }
		isPurchasing = true
		purchaseError = nil
		
		do {
			let success = try await services?.subscriptionService.purchase(productId: productId) ?? false
			if success {
				onUpgrade()
				onClose()
			}
		} catch SubscriptionError.productNotFound {
			purchaseError = "Plan temporarily unavailable. Please try again soon."
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

	@MainActor
	private func loadProductsIfNeeded() async {
		guard products.isEmpty else { return }
		guard let subscriptionService = services?.subscriptionService else { return }
		isLoadingProducts = true
		defer { isLoadingProducts = false }
		
		do {
			let fetched = try await subscriptionService.getAvailableProducts()
			let ordered = subscriptionOptions
				.compactMap { option in fetched.first(where: { $0.id == option.id }) }
			let additional = fetched.filter { product in
				!subscriptionOptions.contains(where: { $0.id == product.id })
			}
			products = ordered + additional
			if products.contains(where: { $0.id == selectedProductId }) == false,
			   let firstAvailable = ordered.first ?? additional.first {
				selectedProductId = firstAvailable.id
			}
		} catch {
			print("Failed to load subscription products: \(error)")
		}
	}

	private func priceText(for productId: String, fallback: String) -> String {
		if let product = products.first(where: { $0.id == productId }) {
			return product.displayPrice
		}
		return fallback
	}

	private func periodText(for productId: String, fallback: String) -> String {
		if let product = products.first(where: { $0.id == productId }),
		   let subscription = product.subscription {
			return periodDisplayText(for: subscription.subscriptionPeriod)
		}
		return fallback
	}

	private func periodDisplayText(for period: Product.SubscriptionPeriod?) -> String {
		guard let period else { return "/period" }
		let unitName: String
		switch period.unit {
		case .day: unitName = period.value == 1 ? "day" : "days"
		case .week: unitName = period.value == 1 ? "week" : "weeks"
		case .month: unitName = period.value == 1 ? "month" : "months"
		case .year: unitName = period.value == 1 ? "year" : "years"
		@unknown default:
			unitName = "period"
		}
		if period.value == 1 {
			return "/\(unitName)"
		} else {
			return "/\(period.value) \(unitName)"
		}
	}

	private func refreshUsageStatus() async {
		guard let services else { return }
		let usageMeter = services.usageMeter
		let subscription = services.subscriptionService
		async let remaining = usageMeter.remainingFreeCount()
		async let totalLimit = usageMeter.totalDailyLimit()
		async let premium = subscription.isPremium
		let (remainingCount, limit, isPremium) = await (remaining, totalLimit, premium)
		await MainActor.run {
			hasRemainingFreeAnalyses = remainingCount > 0 || isPremium
			dailyFreeLimit = limit
		}
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
	let isSelected: Bool
	@Binding var maxHeight: CGFloat
	
	init(title: String, price: String, period: String, isPopular: Bool = false, savings: String? = nil, isSelected: Bool = false, maxHeight: Binding<CGFloat>) {
		self.title = title
		self.price = price
		self.period = period
		self.isPopular = isPopular
		self.savings = savings
		self.isSelected = isSelected
		self._maxHeight = maxHeight
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
				.foregroundStyle(.primary)
			
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
		.frame(minHeight: maxHeight)
		.padding()
		.background(backgroundColor)
		.clipShape(RoundedRectangle(cornerRadius: 16))
		.overlay(
			RoundedRectangle(cornerRadius: 16)
				.stroke(borderColor, lineWidth: borderWidth)
		)
		.overlay(alignment: .topTrailing) {
			if isSelected {
				Image(systemName: "checkmark.circle.fill")
					.font(.title3)
					.foregroundStyle(DS.Color.accent)
					.padding(8)
			}
		}
		.background(
			GeometryReader { proxy in
				Color.clear
					.onAppear {
						if proxy.size.height > maxHeight {
							maxHeight = proxy.size.height
						}
					}
			}
		)
		.animation(.easeOut(duration: 0.2), value: isSelected)
		.accessibilityElement(children: .combine)
		.accessibilityAddTraits(isSelected ? [.isSelected] : [])
		.accessibilityLabel("\(title) plan")
		.accessibilityValue("Price \(price) \(period)")
	}
	
	private var backgroundColor: Color {
		if isSelected {
			return DS.Color.accent.opacity(0.15)
		} else if isPopular {
			return DS.Color.accent.opacity(0.08)
		} else {
			return DS.Color.pillBackground
		}
	}
	
	private var borderColor: Color {
		if isSelected {
			return DS.Color.accent
		} else if isPopular {
			return DS.Color.accent.opacity(0.6)
		} else {
			return .clear
		}
	}
	
	private var borderWidth: CGFloat {
		isSelected ? 2.5 : (isPopular ? 1.5 : 1)
	}
}

private struct IntrinsicHeightPreferenceKey: PreferenceKey {
	static var defaultValue: CGFloat = 0
	static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
		value = max(value, nextValue())
	}
}

#Preview { PaywallView(onClose: {}) }
