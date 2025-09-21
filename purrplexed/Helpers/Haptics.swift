//
//  Haptics.swift
//  Purrplexed
//
//  Simple haptics helpers.
//

import UIKit

enum Haptics {
	static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
		UIImpactFeedbackGenerator(style: style).impactOccurred()
	}
	static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
	static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
