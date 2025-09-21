//
//  SettingsView.swift
//  Purrplexed
//
//  Settings screen shell.
//

import SwiftUI

struct SettingsView: View {
	@ObservedObject var viewModel: SettingsViewModel

	var body: some View {
		NavigationView {
			List {
				Section("About") {
					HStack {
						Text("Version")
						Spacer()
						Text(viewModel.appVersion)
							.foregroundStyle(.secondary)
					}
				}
			}
			.navigationTitle("Settings")
		}
	}
}

#Preview {
	let env = Env.load()
	let container = ServiceContainer(env: env, router: AppRouter(), usageMeter: UsageMeterService(limit: env.freeDailyLimit), imageService: MockImageProcessingService())
	return SettingsView(viewModel: SettingsViewModel(services: container))
}
