//
//  AppRootView.swift
//  Purrplexed
//
//  App root hosting TabView and centralized routing.
//

import SwiftUI

struct AppRootView: View {
	@Environment(\.services) private var services
	@ObservedObject private var router: AppRouter

	init(services: ServiceContainer) {
		self._router = ObservedObject(initialValue: services.router)
	}

	var body: some View {
		TabView(selection: $router.selectedTab) {
			CameraView(viewModel: CameraViewModel(services: services!))
				.tabItem {
					Label("Camera", systemImage: "camera")
				}
				.tag(AppTab.camera)

			AudioView(viewModel: AudioViewModel())
				.tabItem {
					Label("Audio", systemImage: "waveform")
				}
				.tag(AppTab.audio)

			SettingsView(viewModel: SettingsViewModel(services: services!))
				.tabItem {
					Label("Settings", systemImage: "gear")
				}
				.tag(AppTab.settings)
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
				EmptyView() // handled by tab selection
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
