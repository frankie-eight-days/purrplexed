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
}

struct BodyLanguageAnalysis: Sendable, Equatable, Codable {
	let posture: String
	let ears: String
	let tail: String
	let eyes: String
	let overallMood: String
	
	private enum CodingKeys: String, CodingKey {
		case posture, ears, tail, eyes
		case overallMood = "overall_mood"
	}
}

struct ContextualEmotion: Sendable, Equatable, Codable {
	let contextClues: String
	let environmentalFactors: String
	let emotionalMeaning: String
	
	private enum CodingKeys: String, CodingKey {
		case contextClues = "context_clues"
		case environmentalFactors = "environmental_factors"
		case emotionalMeaning = "emotional_meaning"
	}
}

struct OwnerAdvice: Sendable, Equatable, Codable {
	let immediateActions: String
	let longTermSuggestions: String
	let warningSigns: String
	
	private enum CodingKeys: String, CodingKey {
		case immediateActions = "immediate_actions"
		case longTermSuggestions = "long_term_suggestions"
		case warningSigns = "warning_signs"
	}
}

struct ParallelAnalysisResult: Sendable, Equatable {
	let emotionSummary: EmotionSummary?
	let bodyLanguage: BodyLanguageAnalysis?
	let contextualEmotion: ContextualEmotion?
	let ownerAdvice: OwnerAdvice?
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
	func analyzeParallel(photo: CapturedPhoto) async throws -> AsyncStream<ParallelAnalysisUpdate>
}

enum ParallelAnalysisUpdate: Sendable, Equatable {
	case uploadStarted
	case uploadCompleted(fileUri: String)
	case emotionSummaryCompleted(EmotionSummary)
	case bodyLanguageCompleted(BodyLanguageAnalysis)
	case contextualEmotionCompleted(ContextualEmotion)
	case ownerAdviceCompleted(OwnerAdvice)
	case failed(message: String)
}

protocol ShareService: AnyObject, Sendable {
	func generateShareCard(result: AnalysisResult, imageData: Data, aspect: ShareAspect) async throws -> Data
	func saveToPhotos(data: Data) async throws
}

enum ShareAspect: Sendable {
	case square_1_1
	case portrait_9_16
	case landscape_16_9
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

protocol OfflineQueueing: AnyObject, Sendable {
	func enqueue(photo: CapturedPhoto, audio: CapturedAudio?) async
	func pendingCount() async -> Int
}
