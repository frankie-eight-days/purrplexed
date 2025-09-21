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
	private let services: ServiceContainer

	init(services: ServiceContainer) {
		self.services = services
		self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
	}
}
