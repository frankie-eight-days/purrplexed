//
//  StoryTheme.swift
//  Purrplexed
//
//  Story editor palette for fonts, bubbles, and defaults.
//

import SwiftUI

enum StoryTheme {
	static let canvasSize = CGSize(width: 1080, height: 1920)

	static let fonts: [StoryFontStyle] = [
		StoryFontStyle(
			id: "rounded",
			displayName: "Purrplex",
			fontName: "AvenirNextRounded-Bold",
			fallbackName: "HelveticaNeue-Bold",
			defaultSize: 72
		),
		StoryFontStyle(
			id: "handwritten",
			displayName: "Whisker",
			fontName: "ChalkboardSE-Regular",
			fallbackName: "MarkerFelt-Thin",
			defaultSize: 64
		)
	]

	static let bubbles = BubbleTheme.bubbleStyles

	static func font(for id: String) -> StoryFontStyle {
		fonts.first(where: { $0.id == id }) ?? fonts[0]
	}

	static func fallbackFont() -> StoryFontStyle { fonts[0] }

	static func bubbleStyle(for id: String?) -> StoryBubbleStyle? {
		guard let id else { return nil }
		return bubbles.first(where: { $0.id == id })
	}
}

