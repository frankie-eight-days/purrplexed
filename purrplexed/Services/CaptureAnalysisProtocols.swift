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
	let warningMessage: String?
	
	private enum CodingKeys: String, CodingKey {
		case emotion, intensity, description, emoji
		case moodType = "mood_type"
		case warningMessage = "warning_message"
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
		case posture, ears, tail, eyes, whiskers
		case overallMood = "overall_mood"
	}
}

struct ContextualEmotion: Sendable, Equatable, Codable {
	let contextClues: [String]
	let environmentalFactors: [String]
	let emotionalMeaning: [String]
	
	private enum CodingKeys: String, CodingKey {
		case contextClues = "context_clues"
		case environmentalFactors = "environmental_factors"
		case emotionalMeaning = "emotional_meaning"
	}
}

struct OwnerAdvice: Sendable, Equatable, Codable {
	let immediateActions: [String]
	let longTermSuggestions: [String]
	let warningSigns: [String]
	
	private enum CodingKeys: String, CodingKey {
		case immediateActions = "immediate_actions"
		case longTermSuggestions = "long_term_suggestions"
		case warningSigns = "warning_signs"
	}
	
	/// Returns immediate actions formatted as bullet points
	var immediateActionsBulletPoints: [String] {
		return immediateActions.filter { !$0.isEmpty }
	}
	
	/// Returns long-term suggestions formatted as bullet points
	var longTermSuggestionsBulletPoints: [String] {
		return longTermSuggestions.filter { !$0.isEmpty }
	}
	
	/// Returns warning signs formatted as bullet points
	var warningSignsBulletPoints: [String] {
		return warningSigns.filter { !$0.isEmpty }
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
		
		// Handle immediate_actions - can be string or array
		if let actionsArray = try? container.decode([String].self, forKey: .immediateActions) {
			self.immediateActions = actionsArray
		} else if let actionsString = try? container.decode(String.self, forKey: .immediateActions) {
			self.immediateActions = [actionsString]
		} else {
			self.immediateActions = []
		}
		
		// Handle long_term_suggestions - can be string or array
		if let suggestionsArray = try? container.decode([String].self, forKey: .longTermSuggestions) {
			self.longTermSuggestions = suggestionsArray
		} else if let suggestionsString = try? container.decode(String.self, forKey: .longTermSuggestions) {
			self.longTermSuggestions = [suggestionsString]
		} else {
			self.longTermSuggestions = []
		}
		
		// Handle warning_signs - can be string or array
		if let warningsArray = try? container.decode([String].self, forKey: .warningSigns) {
			self.warningSigns = warningsArray
		} else if let warningsString = try? container.decode(String.self, forKey: .warningSigns) {
			self.warningSigns = [warningsString]
		} else {
			self.warningSigns = []
		}
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
	func uploadPhoto(_ photo: CapturedPhoto) async throws -> String // Returns fileUri
	func analyzeEmotionSummary(fileUri: String) async throws -> EmotionSummary
	func analyzeBodyLanguage(fileUri: String) async throws -> BodyLanguageAnalysis
	func analyzeContextualEmotion(fileUri: String) async throws -> ContextualEmotion
	func analyzeOwnerAdvice(fileUri: String) async throws -> OwnerAdvice
	func analyzeCatJokes(fileUri: String) async throws -> CatJokes
	func analyzeParallel(photo: CapturedPhoto) async throws -> AsyncStream<ParallelAnalysisUpdate>
}

enum ParallelAnalysisUpdate: Sendable, Equatable {
	case uploadStarted
	case uploadCompleted(fileUri: String)
	case emotionSummaryCompleted(EmotionSummary)
	case bodyLanguageCompleted(BodyLanguageAnalysis)
	case contextualEmotionCompleted(ContextualEmotion)
	case ownerAdviceCompleted(OwnerAdvice)
	case catJokesCompleted(CatJokes)
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
