//
//  AppRouter.swift
//  Purrplexed
//
//  Centralized navigation router with unidirectional data flow.
//

import Foundation
import SwiftUI

/// App routes to present as modal flows or tab changes
enum Route: Equatable, Identifiable {
	case paywall
	case settings
	case onboarding

	var id: String {
		switch self {
		case .paywall: return "paywall"
		case .settings: return "settings"
		case .onboarding: return "onboarding"
		}
	}
}

@MainActor
protocol Routing: AnyObject {
	var route: Route? { get set }
	func present(_ route: Route)
	func dismiss()
}

/// Centralized app router. Owns selected tab and modal route.
@MainActor
final class AppRouter: ObservableObject, Routing {
	@Published var route: Route? = nil

	/// Single mutation to present a route. `.settings` now presents as a modal.
	func present(_ route: Route) {
		self.route = route
	}

	func dismiss() {
		self.route = nil
	}
}
