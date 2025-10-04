//
//  ShareEditorContext.swift
//  Purrplexed
//
//  Lightweight data transfer object for the share editor feature.
//

import Foundation

struct ShareEditorContext: Equatable, Sendable {
	let originalImageData: Data
	let catDetectionResult: CatDetectionResult?
	let emotionSummary: EmotionSummary?
	let bodyLanguageAnalysis: BodyLanguageAnalysis?
	let contextualEmotion: ContextualEmotion?
	let ownerAdvice: OwnerAdvice?
	let catJokes: CatJokes?
}


