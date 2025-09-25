//
//  AppRootView.swift
//  Purrplexed
//
//  App root hosting single-screen with centralized routing.
//

import SwiftUI

struct AppRootView: View {
	@Environment(\.services) private var services
	@ObservedObject private var router: AppRouter
	@StateObject private var captureVM: CaptureAnalysisViewModel
	@State private var showOnboarding = !UserDefaults.hasCompletedOnboarding

	init(services: ServiceContainer) {
		self._router = ObservedObject(initialValue: services.router)
		self._captureVM = StateObject(wrappedValue: CaptureAnalysisViewModel(
			media: services.mediaService,
			analysis: services.analysisService,
			parallelAnalysis: services.parallelAnalysisService,
			analytics: services.analyticsService,
			permissions: services.permissionsService,
			usageMeter: services.usageMeter,
			subscriptionService: services.subscriptionService
		))
	}

	var body: some View {
		NavigationStack {
			CaptureAnalysisView(viewModel: captureVM)
				.navigationTitle("Purrplexed")
				.navigationBarTitleDisplayMode(.inline)
				.onAppear {
					captureVM.refreshUsageStatus()
				}
				.onChange(of: captureVM.showPaywall) { _, shouldShow in
					if shouldShow {
						router.present(.paywall)
						captureVM.showPaywall = false // Reset flag
					}
				}
				.toolbar {
					ToolbarItem(placement: .topBarLeading) {
						UsageMeterPill(
							used: captureVM.usedCount,
							total: captureVM.dailyLimit,
							isPremium: captureVM.isPremium,
							onUpgradeTap: captureVM.isPremium ? nil : {
								router.present(.paywall)
							}
						)
					}
					
					ToolbarItem(placement: .topBarTrailing) {
						Button(action: { router.present(.settings) }) {
							Image(systemName: "gear")
						}
						.accessibilityLabel("Settings")
					}
				}
		}
		.tint(DS.Color.accent)
		.sheet(item: $router.route, onDismiss: { router.dismiss() }) { route in
			switch route {
			case .paywall:
				PaywallView(
					onClose: { router.dismiss() },
					onUpgrade: {
						captureVM.refreshUsageStatus()
					}
				)
			case .settings:
				SettingsView(viewModel: SettingsViewModel(services: services!))
			case .onboarding:
				EmptyView()
			}
		}
		.fullScreenCover(isPresented: $showOnboarding) {
			OnboardingView(services: services!) {
				showOnboarding = false
			}
		}
	}
}

#Preview("AppRootView - Light/Dark") {
	let env = Env.load()
	let usage = UsageMeterService(limit: env.freeDailyLimit)
	let router = AppRouter()
	let container = ServiceContainer(env: env, router: router, usageMeter: usage)
	return Group {
		AppRootView(services: container)
			.preferredColorScheme(.light)
		AppRootView(services: container)
			.preferredColorScheme(.dark)
	}
}
