//
//  BubbleTheme.swift
//  Purrplexed
//
//  Shared styles for speech/thought bubbles.
//

import SwiftUI

struct BubbleTheme {
	static let bubbleStyles: [StoryBubbleStyle] = [
		StoryBubbleStyle(
			id: "daydream",
			displayName: "Daydream",
			fillColor: StoryColor(red: 0.94, green: 0.97, blue: 1.0, alpha: 0.92),
			strokeColor: StoryColor(red: 0.35, green: 0.52, blue: 0.98),
			lineWidth: 4,
			cornerRadius: 48,
			tailDirection: .right
		),
		StoryBubbleStyle(
			id: "playful",
			displayName: "Playful",
			fillColor: StoryColor(red: 1.0, green: 0.94, blue: 0.84, alpha: 0.95),
			strokeColor: StoryColor(red: 0.94, green: 0.58, blue: 0.23),
			lineWidth: 5,
			cornerRadius: 38,
			tailDirection: .left
		),
		StoryBubbleStyle(
			id: "whisper",
			displayName: "Whisper",
			fillColor: StoryColor(red: 0.16, green: 0.16, blue: 0.2, alpha: 0.85),
			strokeColor: StoryColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.28),
			lineWidth: 2,
			cornerRadius: 44,
			tailDirection: .bottom
		)
	]
}

