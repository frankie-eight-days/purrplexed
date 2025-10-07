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
					.contentShape(Rectangle())
					.onTapGesture {
						viewModel.handleVersionTap()
					}
				}
			}
			.navigationTitle("Settings")
			#if DEBUG
			.sheet(isPresented: $viewModel.showDebugMenu) {
				DebugMenuView(viewModel: viewModel)
			}
			#endif
		}
	}
}

#if DEBUG
struct DebugMenuView: View {
	@ObservedObject var viewModel: SettingsViewModel
	@Environment(\.presentationMode) var presentationMode
	
	var body: some View {
		NavigationView {
			List {
				Section("Debug Tools") {
					Button("🔄 Reset Usage Counter") {
						viewModel.resetUsage()
						presentationMode.wrappedValue.dismiss()
					}
					.foregroundStyle(.blue)
					
					Button("👑 Toggle Premium Status") {
						viewModel.togglePremiumStatus()
						presentationMode.wrappedValue.dismiss()
					}
					.foregroundStyle(.purple)

					Button("⬇️ Demote to Free") {
						viewModel.demoteToFree()
						presentationMode.wrappedValue.dismiss()
					}
					.foregroundStyle(.red)
					
					Button("💳 Show Paywall") {
						presentationMode.wrappedValue.dismiss()
						viewModel.showPaywallFromDebug()
					}
					.foregroundStyle(.orange)
				}
				
				Section("Info") {
					Text("Tap version number 4x rapidly to access this menu")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
			.navigationTitle("Debug Menu")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					Button("Done") {
						presentationMode.wrappedValue.dismiss()
					}
				}
			}
		}
	}
}
#endif

#Preview {
	let env = Env.load()
	let container = ServiceContainer(
		env: env, 
		router: AppRouter(), 
		usageMeter: UsageMeterService(limit: env.freeDailyLimit), 
		subscriptionService: MockSubscriptionService()
	)
	return SettingsView(viewModel: SettingsViewModel(services: container))
}
