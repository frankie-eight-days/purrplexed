//
//  ParallelAnalysisService.swift
//  Purrplexed
//
//  HTTP-backed parallel analysis service that uploads an image and performs parallel analyses.
//

import Foundation
import CryptoKit
import UIKit

struct SingleAnalysisResponse: Decodable {
	let summary: EmotionSummary?
	let bodyLanguage: BodyLanguageAnalysis?
	let contextualEmotion: ContextualEmotion?
	let ownerAdvice: OwnerAdvice?
	let catJokes: CatJokes?
	let doNow: ContextualEmotion?
	let risks: OwnerAdvice?
	let errors: [String]?
}

struct BackendParallelErrorResponse: Decodable {
	let error: String?
	let message: String?
}

// MARK: - Individual Analysis Response Types

struct SummaryResponse: Decodable {
	let summary: EmotionSummary
	let success: Bool
}

struct BodyLanguageResponse: Decodable {
	let bodyLanguage: BodyLanguageAnalysis
	let success: Bool
}

struct ContextualEmotionResponse: Decodable {
	let contextualEmotion: ContextualEmotion
	let success: Bool
}

struct OwnerAdviceResponse: Decodable {
	let ownerAdvice: OwnerAdvice
	let success: Bool
}

struct CatJokesResponse: Decodable {
	let catJokes: CatJokes?
	let success: Bool
}

// Legacy streaming structures - keeping for backward compatibility if needed
private struct StreamErrorPayload: Decodable { let message: String? }

final class HTTPParallelAnalysisService: ParallelAnalysisService {
	private let baseURL: URL
	private let analyzePath: String
	private let appKey: String?
	private let urlSession: URLSession
	
	init(baseURL: URL, analyzePath: String = "/api/analyze", appKey: String? = nil, urlSession: URLSession = .shared) {
		self.baseURL = baseURL
		self.analyzePath = analyzePath
		self.appKey = appKey
		self.urlSession = urlSession
	}
	
	func analyzeParallel(photo: CapturedPhoto) async throws -> AsyncStream<ParallelAnalysisUpdate> {
		let imageFingerprint = shortHash(for: photo.imageData)
		Log.network.info("Preparing analysis (non-stream primary) fingerprint=\(imageFingerprint) size=\(photo.imageData.count) bytes")
		let encodedImage = encodeImage(photo.imageData)
		return AsyncStream<ParallelAnalysisUpdate>(bufferingPolicy: .unbounded) { continuation in
			let task = Task {
				// Try fast non-stream first
				await self.performNonStreamFallback(encodedImage: encodedImage, continuation: continuation)
			}
			continuation.onTermination = { @Sendable _ in task.cancel() }
		}
	}

	private func handleSseLine(_ dataLine: String, continuation: AsyncStream<ParallelAnalysisUpdate>.Continuation) {
		guard let data = dataLine.data(using: .utf8) else { return }
		do {
			let anyObj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
			guard let event = anyObj?["event"] as? String else { return }
			let payload = anyObj?["payload"]
			switch event {
			case "started":
				continuation.yield(.started)
			case "summary":
				if let p = payload, let model: EmotionSummary = try decodePayload(p) {
					continuation.yield(.emotionSummaryCompleted(model))
				}
			case "bodyLanguage":
				if let p = payload, let model: BodyLanguageAnalysis = try decodePayload(p) {
					continuation.yield(.bodyLanguageCompleted(model))
				}
			case "contextualEmotion":
				if let p = payload, let model: ContextualEmotion = try decodePayload(p) {
					continuation.yield(.contextualEmotionCompleted(model))
				}
			case "ownerAdvice":
				if let p = payload, let model: OwnerAdvice = try decodePayload(p) {
					continuation.yield(.ownerAdviceCompleted(model))
				}
			case "catJokes":
				if let p = payload, let model: CatJokes = try decodePayload(p) {
					continuation.yield(.catJokesCompleted(model))
				}
			case "partialFailures":
				if let p = payload, let errors: [String] = try decodePayload(p) {
					continuation.yield(.partialFailures(errors))
				}
			case "error":
				let message: String
				if let p = payload as? [String: Any], let m = p["message"] as? String { message = m } else { message = "Analysis error" }
				continuation.yield(.failed(message: message))
			case "complete":
				break
			default:
				break
			}
		} catch {
			Log.network.warning("Failed to parse SSE line: \(error.localizedDescription, privacy: .public)")
		}
	}

	private func decodePayload<T: Decodable>(_ any: Any) throws -> T? {
		guard JSONSerialization.isValidJSONObject(any) else { return nil }
		let data = try JSONSerialization.data(withJSONObject: any)
		return try JSONDecoder().decode(T.self, from: data)
	}

	private struct FullAnalysisResponse: Decodable {
		let summary: EmotionSummary
		let bodyLanguage: BodyLanguageAnalysis
		let contextualEmotion: ContextualEmotion
		let ownerAdvice: OwnerAdvice
		let catJokes: CatJokes?
		let errors: [String]
	}

	private func performNonStreamFallback(encodedImage: String, continuation: AsyncStream<ParallelAnalysisUpdate>.Continuation) async {
		do {
			var request = URLRequest(url: baseURL.appendingPathComponent(analyzePath))
			request.httpMethod = "POST"
			request.setValue("application/json", forHTTPHeaderField: "Content-Type")
			if let appKey = appKey { request.setValue("Bearer \(appKey)", forHTTPHeaderField: "Authorization") }
			let payload: [String: Any] = [
				"images": [encodedImage],
				"stream": false
			]
			request.httpBody = try JSONSerialization.data(withJSONObject: payload)
			let (data, response) = try await urlSession.data(for: request)
			if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
				let decoded = try JSONDecoder().decode(FullAnalysisResponse.self, from: data)
				continuation.yield(.started)
				continuation.yield(.emotionSummaryCompleted(decoded.summary))
				continuation.yield(.bodyLanguageCompleted(decoded.bodyLanguage))
				continuation.yield(.contextualEmotionCompleted(decoded.contextualEmotion))
				continuation.yield(.ownerAdviceCompleted(decoded.ownerAdvice))
				if let jokes = decoded.catJokes { continuation.yield(.catJokesCompleted(jokes)) }
				if !decoded.errors.isEmpty { continuation.yield(.partialFailures(decoded.errors)) }
				continuation.finish()
				return
			}
			// Non-2xx or decode failure: log and retry with SSE
			let bodyText = String(data: data, encoding: .utf8) ?? ""
			Log.network.error("Non-stream analysis failed: \(bodyText, privacy: .public)")
			await self.performSseRetry(encodedImage: encodedImage, continuation: continuation)
		} catch {
			Log.network.warning("Non-stream decode error: \(error.localizedDescription, privacy: .public). Retrying SSE…")
			await self.performSseRetry(encodedImage: encodedImage, continuation: continuation)
		}
	}

	private func performSseRetry(encodedImage: String, continuation: AsyncStream<ParallelAnalysisUpdate>.Continuation) async {
		let endpointURL = baseURL.appendingPathComponent(analyzePath)
		var request = URLRequest(url: endpointURL)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
		if let appKey = appKey { request.setValue("Bearer \(appKey)", forHTTPHeaderField: "Authorization") }
		let payload: [String: Any] = ["images": [encodedImage], "stream": true]
		request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
		do {
			let (bytes, response) = try await urlSession.bytes(for: request)
			guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
				continuation.yield(.failed(message: "Server error"))
				continuation.finish()
				return
			}
			var currentDataLine = ""
			for try await line in bytes.lines {
				if line.hasPrefix("data:") {
					let jsonPart = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
					currentDataLine = String(jsonPart)
					continue
				}
				if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
					if !currentDataLine.isEmpty {
						self.handleSseLine(currentDataLine, continuation: continuation)
						currentDataLine = ""
					}
				}
			}
			continuation.finish()
		} catch {
			continuation.yield(.failed(message: error.localizedDescription))
			continuation.finish()
		}
	}
	
	// MARK: - New Parallel Analysis Implementation
	
	private func getSummary(encodedImage: String, imageFingerprint: String) async throws -> EmotionSummary {
		let payload: [String: Any] = [
			"images": [encodedImage]
		]
		let body = try JSONSerialization.data(withJSONObject: payload)
		
		var request = URLRequest(url: baseURL.appendingPathComponent("/api/analyze/summary"))
		request.httpMethod = "POST"
		request.httpBody = body
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		if let appKey = appKey {
			request.setValue("Bearer \(appKey)", forHTTPHeaderField: "Authorization")
		}
		
		Log.network.info("POST /api/analyze/summary fingerprint=\(imageFingerprint)")
		
		let (data, response) = try await urlSession.data(for: request)
		guard let httpResponse = response as? HTTPURLResponse else {
			throw AnalysisError.networkError("Invalid response from server")
		}
		
		guard (200..<300).contains(httpResponse.statusCode) else {
			if let errorResponse = try? JSONDecoder().decode(BackendParallelErrorResponse.self, from: data) {
				throw AnalysisError.serverError(errorResponse.message ?? errorResponse.error ?? "Summary analysis failed")
			}
			throw AnalysisError.serverError("Summary analysis returned status \(httpResponse.statusCode)")
		}
		
		let summaryResponse = try JSONDecoder().decode(SummaryResponse.self, from: data)
		return summaryResponse.summary
	}
	
	private func performParallelDetailedAnalyses(
		encodedImage: String,
		summary: EmotionSummary,
		imageFingerprint: String,
		continuation: AsyncStream<ParallelAnalysisUpdate>.Continuation,
		collectedErrors: inout [String]
	) async throws {
		var localErrors: [String] = []
		// Create parallel tasks for each detailed analysis
		let bodyLanguageTask = Task {
			try await getBodyLanguageAnalysis(encodedImage: encodedImage, summary: summary, imageFingerprint: imageFingerprint)
		}
		
		let contextualTask = Task {
			try await getContextualEmotionAnalysis(encodedImage: encodedImage, summary: summary, imageFingerprint: imageFingerprint)
		}
		
		let ownerAdviceTask = Task {
			try await getOwnerAdviceAnalysis(encodedImage: encodedImage, summary: summary, imageFingerprint: imageFingerprint)
		}
		
		let catJokesTask = Task {
			try await getCatJokesAnalysis(encodedImage: encodedImage, summary: summary, imageFingerprint: imageFingerprint)
		}
		
		// Process results as they complete using TaskGroup
		await withTaskGroup(of: String?.self) { group in
			// Body Language Analysis
			group.addTask {
				do {
					let result = try await bodyLanguageTask.value
					continuation.yield(.bodyLanguageCompleted(result))
					return nil
				} catch {
					let errorMessage = "Body language analysis failed: \(error.localizedDescription)"
					Log.network.error("Body language analysis failed: \(error.localizedDescription, privacy: .public)")
					return errorMessage
				}
			}
			
			// Contextual Emotion Analysis
			group.addTask {
				do {
					let result = try await contextualTask.value
					continuation.yield(.contextualEmotionCompleted(result))
					return nil
				} catch {
					let errorMessage = "Contextual emotion analysis failed: \(error.localizedDescription)"
					Log.network.error("Contextual emotion analysis failed: \(error.localizedDescription, privacy: .public)")
					return errorMessage
				}
			}
			
			// Owner Advice Analysis
			group.addTask {
				do {
					let result = try await ownerAdviceTask.value
					continuation.yield(.ownerAdviceCompleted(result))
					return nil
				} catch {
					let errorMessage = "Owner advice analysis failed: \(error.localizedDescription)"
					Log.network.error("Owner advice analysis failed: \(error.localizedDescription, privacy: .public)")
					return errorMessage
				}
			}
			
			// Cat Jokes Analysis (optional)
			group.addTask {
				do {
					let result = try await catJokesTask.value
					if let jokes = result {
						continuation.yield(.catJokesCompleted(jokes))
					}
					return nil
				} catch {
					Log.network.warning("Cat jokes analysis failed (optional): \(error.localizedDescription)")
					return nil // Don't report cat jokes errors as they're optional
				}
			}
			
			// Collect errors from completed tasks
			for await errorMessage in group {
				if let error = errorMessage {
					localErrors.append(error)
				}
			}
		}
		
		// Add local errors to the collected errors
		collectedErrors.append(contentsOf: localErrors)
		
		if !localErrors.isEmpty {
			continuation.yield(.partialFailures(localErrors))
		}
	}
	
	// MARK: - Individual Analysis Methods
	
	private func getBodyLanguageAnalysis(encodedImage: String, summary: EmotionSummary, imageFingerprint: String) async throws -> BodyLanguageAnalysis {
		return try await performAnalysisRequest(
			endpoint: "/api/analyze/body-language",
			encodedImage: encodedImage,
			summary: summary,
			imageFingerprint: imageFingerprint,
			responseType: BodyLanguageResponse.self
		).bodyLanguage
	}
	
	private func getContextualEmotionAnalysis(encodedImage: String, summary: EmotionSummary, imageFingerprint: String) async throws -> ContextualEmotion {
		return try await performAnalysisRequest(
			endpoint: "/api/analyze/contextual-emotion",
			encodedImage: encodedImage,
			summary: summary,
			imageFingerprint: imageFingerprint,
			responseType: ContextualEmotionResponse.self
		).contextualEmotion
	}
	
	private func getOwnerAdviceAnalysis(encodedImage: String, summary: EmotionSummary, imageFingerprint: String) async throws -> OwnerAdvice {
		return try await performAnalysisRequest(
			endpoint: "/api/analyze/owner-advice",
			encodedImage: encodedImage,
			summary: summary,
			imageFingerprint: imageFingerprint,
			responseType: OwnerAdviceResponse.self
		).ownerAdvice
	}
	
	private func getCatJokesAnalysis(encodedImage: String, summary: EmotionSummary, imageFingerprint: String) async throws -> CatJokes? {
		let response = try await performAnalysisRequest(
			endpoint: "/api/analyze/cat-jokes",
			encodedImage: encodedImage,
			summary: summary,
			imageFingerprint: imageFingerprint,
			responseType: CatJokesResponse.self
		)
		return response.catJokes
	}
	
	private func performAnalysisRequest<T: Decodable>(
		endpoint: String,
		encodedImage: String,
		summary: EmotionSummary,
		imageFingerprint: String,
		responseType: T.Type
	) async throws -> T {
		let payload: [String: Any] = [
			"images": [encodedImage],
			"summary": [
				"emotion": summary.emotion,
				"intensity": summary.intensity,
				"description": summary.description,
				"emoji": summary.emoji,
				"moodType": summary.moodType,
				"postureHint": summary.postureHint,
				"warningMessage": summary.warningMessage as Any
			]
		]
		let body = try JSONSerialization.data(withJSONObject: payload)
		
		var request = URLRequest(url: baseURL.appendingPathComponent(endpoint))
		request.httpMethod = "POST"
		request.httpBody = body
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		if let appKey = appKey {
			request.setValue("Bearer \(appKey)", forHTTPHeaderField: "Authorization")
		}
		
		Log.network.info("POST \(endpoint) fingerprint=\(imageFingerprint)")
		
		let (data, response) = try await urlSession.data(for: request)
		guard let httpResponse = response as? HTTPURLResponse else {
			throw AnalysisError.networkError("Invalid response from server")
		}
		
		guard (200..<300).contains(httpResponse.statusCode) else {
			if let errorResponse = try? JSONDecoder().decode(BackendParallelErrorResponse.self, from: data) {
				throw AnalysisError.serverError(errorResponse.message ?? errorResponse.error ?? "\(endpoint) analysis failed")
			}
			throw AnalysisError.serverError("\(endpoint) analysis returned status \(httpResponse.statusCode)")
		}
		
		return try JSONDecoder().decode(responseType, from: data)
	}
	
	private func encodeImage(_ data: Data) -> String {
		guard let image = UIImage(data: data) else {
			Log.network.warning("Failed to decode image for downscaling; sending original data")
			return "data:image/jpeg;base64,\(data.base64EncodedString())"
		}
		let maxDimension: CGFloat = 768
		let originalSize = image.size
		let scaleFactor = min(1.0, maxDimension / max(originalSize.width, originalSize.height))
		let targetSize = CGSize(width: originalSize.width * scaleFactor, height: originalSize.height * scaleFactor)
		let renderer = UIGraphicsImageRenderer(size: targetSize)
		let scaledData = renderer.jpegData(withCompressionQuality: 0.6) { _ in
			image.draw(in: CGRect(origin: .zero, size: targetSize))
		}
		let base64 = scaledData.base64EncodedString()
		Log.network.info("Encoded image downscaled from \(Int(originalSize.width))x\(Int(originalSize.height)) to \(Int(targetSize.width))x\(Int(targetSize.height)) size=\(scaledData.count) bytes")
		return "data:image/jpeg;base64,\(base64)"
	}
	
	// MARK: - Utility Methods
	
	private func shortHash(for data: Data) -> String {
		let digest = SHA256.hash(data: data)
		return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
	}
}

// MARK: - Error Types

enum AnalysisError: LocalizedError {
	case networkError(String)
	case serverError(String)
	case invalidResponse(String)
	
	var errorDescription: String? {
		switch self {
		case .networkError(let message):
			return "Network error: \(message)"
		case .serverError(let message):
			return "Server error: \(message)"
		case .invalidResponse(let message):
			return "Invalid response: \(message)"
		}
	}
}
