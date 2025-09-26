//
//  CaptureAnalysisProtocols.swift
//  Purrplexed
//
//  Protocols for capture/analysis pipeline and related services.
//

import Foundation
import SwiftUI
@preconcurrency import AVFoundation

// MARK: - Models

struct CapturedPhoto: Sendable, Equatable {
	let imageData: Data
}

struct CapturedAudio: Sendable, Equatable {
	let data: Data
	let sampleRate: Double
}

struct AnalysisResult: Sendable, Equatable {
	let translatedText: String
	let confidence: Double
	let funFact: String?
}

// MARK: - New Parallel Analysis Models


struct EmotionSummary: Sendable, Equatable, Codable {
	let emotion: String
	let intensity: String
	let description: String
	let emoji: String
	let moodType: String
	let postureHint: String
	let warningMessage: String?

	private enum CodingKeys: String, CodingKey {
		case emotion
		case intensity
		case description
		case emoji
		case moodType
		case warningMessage
		case postureHint
		case legacyMoodType = "mood_type"
		case legacyWarningMessage = "warning_message"
		case legacyPostureHint = "posture_hint"
	}

	init(emotion: String, intensity: String, description: String, emoji: String, moodType: String, postureHint: String, warningMessage: String?) {
		self.emotion = emotion
		self.intensity = intensity
		self.description = description
		self.emoji = emoji
		self.moodType = moodType
		self.postureHint = postureHint
		self.warningMessage = warningMessage
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		emotion = try container.decode(String.self, forKey: .emotion)
		intensity = try container.decode(String.self, forKey: .intensity)
		description = try container.decode(String.self, forKey: .description)
		emoji = try container.decode(String.self, forKey: .emoji)
		if let mood = try container.decodeIfPresent(String.self, forKey: .moodType) {
			moodType = mood
		} else {
			moodType = try container.decode(String.self, forKey: .legacyMoodType)
		}
		if let posture = try container.decodeIfPresent(String.self, forKey: .postureHint) {
			postureHint = posture
		} else if let legacyPosture = try container.decodeIfPresent(String.self, forKey: .legacyPostureHint) {
			postureHint = legacyPosture
		} else {
			postureHint = ""
		}
		if let warning = try container.decodeIfPresent(String.self, forKey: .warningMessage) {
			warningMessage = warning
		} else {
			warningMessage = try container.decodeIfPresent(String.self, forKey: .legacyWarningMessage)
		}
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(emotion, forKey: .emotion)
		try container.encode(intensity, forKey: .intensity)
		try container.encode(description, forKey: .description)
		try container.encode(emoji, forKey: .emoji)
		try container.encode(moodType, forKey: .moodType)
		try container.encode(postureHint, forKey: .postureHint)
		try container.encodeIfPresent(warningMessage, forKey: .warningMessage)
	}
}

struct BodyLanguageAnalysis: Sendable, Equatable, Codable {
	let posture: String
	let ears: String
	let tail: String
	let eyes: String
	let whiskers: String
	let overallMood: String

	private enum CodingKeys: String, CodingKey {
		case posture
		case ears
		case tail
		case eyes
		case whiskers
		case overallMood
		case legacyOverallMood = "overall_mood"
	}

	init(posture: String, ears: String, tail: String, eyes: String, whiskers: String, overallMood: String) {
		self.posture = posture
		self.ears = ears
		self.tail = tail
		self.eyes = eyes
		self.whiskers = whiskers
		self.overallMood = overallMood
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		posture = try container.decode(String.self, forKey: .posture)
		ears = try container.decode(String.self, forKey: .ears)
		tail = try container.decode(String.self, forKey: .tail)
		eyes = try container.decode(String.self, forKey: .eyes)
		whiskers = try container.decode(String.self, forKey: .whiskers)
		if let mood = try container.decodeIfPresent(String.self, forKey: .overallMood) {
			overallMood = mood
		} else {
			overallMood = try container.decode(String.self, forKey: .legacyOverallMood)
		}
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(posture, forKey: .posture)
		try container.encode(ears, forKey: .ears)
		try container.encode(tail, forKey: .tail)
		try container.encode(eyes, forKey: .eyes)
		try container.encode(whiskers, forKey: .whiskers)
		try container.encode(overallMood, forKey: .overallMood)
	}
}

struct ContextualEmotion: Sendable, Equatable, Codable {
	let contextClues: [String]
	let environmentalFactors: [String]
	let emotionalMeaning: [String]

	private enum CodingKeys: String, CodingKey {
		case contextClues
		case environmentalFactors
		case emotionalMeaning
		case legacyContextClues = "context_clues"
		case legacyEnvironmentalFactors = "environmental_factors"
		case legacyEmotionalMeaning = "emotional_meaning"
	}

	init(contextClues: [String], environmentalFactors: [String], emotionalMeaning: [String]) {
		self.contextClues = contextClues
		self.environmentalFactors = environmentalFactors
		self.emotionalMeaning = emotionalMeaning
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		contextClues = ContextualEmotion.decodeStrings(container: container, primary: .contextClues, legacy: .legacyContextClues)
		environmentalFactors = ContextualEmotion.decodeStrings(container: container, primary: .environmentalFactors, legacy: .legacyEnvironmentalFactors)
		emotionalMeaning = ContextualEmotion.decodeStrings(container: container, primary: .emotionalMeaning, legacy: .legacyEmotionalMeaning)
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(contextClues, forKey: .contextClues)
		try container.encode(environmentalFactors, forKey: .environmentalFactors)
		try container.encode(emotionalMeaning, forKey: .emotionalMeaning)
	}

	private static func decodeStrings(container: KeyedDecodingContainer<CodingKeys>, primary: CodingKeys, legacy: CodingKeys) -> [String] {
		if let values = try? container.decode([String].self, forKey: primary) {
			return values
		}
		if let legacyValues = try? container.decode([String].self, forKey: legacy) {
			return legacyValues
		}
		if let single = try? container.decode(String.self, forKey: primary) {
			return [single]
		}
		if let legacySingle = try? container.decode(String.self, forKey: legacy) {
			return [legacySingle]
		}
		return []
	}
}

struct OwnerAdvice: Sendable, Equatable, Codable {
	let immediateActions: [String]
	let longTermSuggestions: [String]
	let warningSigns: [String]

	private enum CodingKeys: String, CodingKey {
		case immediateActions
		case longTermSuggestions
		case warningSigns
		case legacyImmediateActions = "immediate_actions"
		case legacyLongTermSuggestions = "long_term_suggestions"
		case legacyWarningSigns = "warning_signs"
	}

	/// Returns immediate actions formatted as bullet points
	var immediateActionsBulletPoints: [String] {
		immediateActions.filter { !$0.isEmpty }
	}

	/// Returns long-term suggestions formatted as bullet points
	var longTermSuggestionsBulletPoints: [String] {
		longTermSuggestions.filter { !$0.isEmpty }
	}

	/// Returns warning signs formatted as bullet points
	var warningSignsBulletPoints: [String] {
		warningSigns.filter { !$0.isEmpty }
	}

	// Memberwise initializer for mocks and direct construction
	init(immediateActions: [String], longTermSuggestions: [String], warningSigns: [String]) {
		self.immediateActions = immediateActions
		self.longTermSuggestions = longTermSuggestions
		self.warningSigns = warningSigns
	}

	// Legacy initializer for backward compatibility with string inputs
	init(immediateActions: String, longTermSuggestions: String, warningSigns: String) {
		self.immediateActions = [immediateActions]
		self.longTermSuggestions = [longTermSuggestions]
		self.warningSigns = [warningSigns]
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		if let array = try? container.decode([String].self, forKey: .immediateActions) {
			self.immediateActions = array
		} else if let legacyArray = try? container.decode([String].self, forKey: .legacyImmediateActions) {
			self.immediateActions = legacyArray
		} else if let string = try? container.decode(String.self, forKey: .immediateActions) {
			self.immediateActions = [string]
		} else if let legacyString = try? container.decode(String.self, forKey: .legacyImmediateActions) {
			self.immediateActions = [legacyString]
		} else {
			self.immediateActions = []
		}

		if let array = try? container.decode([String].self, forKey: .longTermSuggestions) {
			self.longTermSuggestions = array
		} else if let legacyArray = try? container.decode([String].self, forKey: .legacyLongTermSuggestions) {
			self.longTermSuggestions = legacyArray
		} else if let string = try? container.decode(String.self, forKey: .longTermSuggestions) {
			self.longTermSuggestions = [string]
		} else if let legacyString = try? container.decode(String.self, forKey: .legacyLongTermSuggestions) {
			self.longTermSuggestions = [legacyString]
		} else {
			self.longTermSuggestions = []
		}

		if let array = try? container.decode([String].self, forKey: .warningSigns) {
			self.warningSigns = array
		} else if let legacyArray = try? container.decode([String].self, forKey: .legacyWarningSigns) {
			self.warningSigns = legacyArray
		} else if let string = try? container.decode(String.self, forKey: .warningSigns) {
			self.warningSigns = [string]
		} else if let legacyString = try? container.decode(String.self, forKey: .legacyWarningSigns) {
			self.warningSigns = [legacyString]
		} else {
			self.warningSigns = []
		}
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(immediateActions, forKey: .immediateActions)
		try container.encode(longTermSuggestions, forKey: .longTermSuggestions)
		try container.encode(warningSigns, forKey: .warningSigns)
	}
}

struct CatJokes: Sendable, Equatable, Codable {
	let jokes: [String]
}

enum AnalysisStatus: Sendable, Equatable {
	case queued
	case processing(progress: Double)
	case completed(AnalysisResult)
	case failed(message: String)
}

// MARK: - Protocols

protocol MediaService: AnyObject, Sendable {
	var captureSession: AVCaptureSession? { get }
	func prepareSession() async throws
	func capturePhoto() async throws -> CapturedPhoto
}

protocol AnalysisService: AnyObject, Sendable {
	func analyze(photo: CapturedPhoto, audio: CapturedAudio?) async throws -> AsyncStream<AnalysisStatus>
}

protocol ParallelAnalysisService: AnyObject, Sendable {
	func analyzeParallel(photo: CapturedPhoto) async throws -> AsyncStream<ParallelAnalysisUpdate>
}

enum ParallelAnalysisUpdate: Sendable, Equatable {
	case started
	case emotionSummaryCompleted(EmotionSummary)
	case bodyLanguageCompleted(BodyLanguageAnalysis)
	case contextualEmotionCompleted(ContextualEmotion)
	case ownerAdviceCompleted(OwnerAdvice)
	case catJokesCompleted(CatJokes)
	case partialFailures([String])
	case failed(message: String)
}

protocol AnalyticsService: AnyObject, Sendable {
	func track(event: String, properties: [String: Sendable])
}

enum PermissionType { case camera, microphone, photos }

enum PermissionStatus { case notDetermined, granted, denied, restricted }

protocol PermissionsService: AnyObject, Sendable {
	func status(for type: PermissionType) async -> PermissionStatus
	func request(_ type: PermissionType) async -> PermissionStatus
}
