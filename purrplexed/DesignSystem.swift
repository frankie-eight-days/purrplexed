//
//  DesignSystem.swift
//  Purrplexed
//
//  Minimal theming helpers.
//

import SwiftUI

enum DS {
	enum Color {
		static let background = SwiftUI.Color(.systemBackground)
		static let accent = SwiftUI.Color.accentColor
		static let textPrimary = SwiftUI.Color.primary
		static let pillBackground = SwiftUI.Color(.secondarySystemBackground)
	}
	
	enum Typography {
		static func titleFont() -> Font { .system(.title2, design: .rounded).weight(.semibold) }
		static func bodyFont() -> Font { .system(.body, design: .rounded) }
		static func buttonFont() -> Font { .system(.headline, design: .rounded) }
	}
	
	enum Spacing {
		static let s: CGFloat = 8
		static let m: CGFloat = 16
		static let l: CGFloat = 24
		static let xl: CGFloat = 32
	}
}
