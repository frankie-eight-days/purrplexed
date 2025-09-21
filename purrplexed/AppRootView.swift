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

	init(services: ServiceContainer) {
		self._router = ObservedObject(initialValue: services.router)
		self._captureVM = StateObject(wrappedValue: CaptureAnalysisViewModel(
			media: services.mediaService,
			analysis: services.analysisService,
			parallelAnalysis: services.parallelAnalysisService,
			share: services.shareService,
			analytics: services.analyticsService,
			permissions: services.permissionsService,
			offlineQueue: services.offlineQueue
		))
	}

	var body: some View {
		NavigationStack {
			CaptureAnalysisView(viewModel: captureVM)
				.navigationTitle("Purrplexed")
				.navigationBarTitleDisplayMode(.inline)
				.toolbar {
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
			case .processing(let jobId):
				ProcessingView(jobId: jobId)
			case .result(let jobId):
				ResultView(jobId: jobId)
			case .paywall:
				PaywallView(onClose: { router.dismiss() })
			case .settings:
				SettingsView(viewModel: SettingsViewModel(services: services!))
			}
		}
	}
}

#Preview("AppRootView - Light/Dark") {
	let env = Env.load()
	let usage = UsageMeterService(limit: env.freeDailyLimit)
	let image = MockImageProcessingService()
	let router = AppRouter()
	let container = ServiceContainer(env: env, router: router, usageMeter: usage, imageService: image)
	return Group {
		AppRootView(services: container)
			.preferredColorScheme(.light)
		AppRootView(services: container)
			.preferredColorScheme(.dark)
	}
}
