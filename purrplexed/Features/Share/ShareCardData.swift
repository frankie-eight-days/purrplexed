import Foundation
import SwiftUI

struct ShareCardData: Equatable {
	let catImageData: Data?
	let emotion: String
	let emoji: String
	let selectedContextHighlights: [String]
	let selectedAdviceHighlights: [String]
	
	init(
		catImageData: Data?,
		emotion: String,
		emoji: String,
		selectedContextHighlights: [String],
		selectedAdviceHighlights: [String]
	) {
		self.catImageData = catImageData
		self.emotion = emotion
		self.emoji = emoji
		self.selectedContextHighlights = selectedContextHighlights
		self.selectedAdviceHighlights = selectedAdviceHighlights
	}
}

struct ShareCardOptions: Equatable {
	let contextHighlights: [String]
	let adviceHighlights: [String]
}