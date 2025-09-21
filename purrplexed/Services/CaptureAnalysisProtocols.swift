//
//  CaptureAnalysisProtocols.swift
//  Purrplexed
//
//  Protocols for capture/analysis pipeline and related services.
//

import Foundation
import SwiftUI
import AVFoundation

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
