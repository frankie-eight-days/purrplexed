//
//  AppRouter.swift
//  Purrplexed
//
//  Centralized navigation router with unidirectional data flow.
//

import Foundation
import SwiftUI

/// Top-level app tabs
enum AppTab: Hashable {
	case camera
	case audio
	case settings
}

/// App routes to present as modal flows or tab changes
enum Route: Equatable, Identifiable {
	case processing(jobId: String)
	case result(jobId: String)
	case paywall
	case settings

	var id: String {
		switch self {
		case .processing(let jobId): return "processing_\(jobId)"
		case .result(let jobId): return "result_\(jobId)"
		case .paywall: return "paywall"
		case .settings: return "settings"
		}
	}
}

@MainActor
protocol Routing: AnyObject {
	var selectedTab: AppTab { get set }
	var route: Route? { get set }
	func present(_ route: Route)
	func dismiss()
}

/// Centralized app router. Owns selected tab and modal route.
@MainActor
final class AppRouter: ObservableObject, Routing {
	@Published var selectedTab: AppTab = .camera
	@Published var route: Route? = nil

	/// Single mutation to present a route. `.settings` now presents as a modal.
	func present(_ route: Route) {
		self.route = route
	}

	func dismiss() {
		self.route = nil
	}
}
