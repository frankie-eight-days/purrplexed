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

private struct StreamCompletePayload: Decodable {
	let summary: EmotionSummary
	let bodyLanguage: BodyLanguageAnalysis
	let contextualEmotion: ContextualEmotion
	let ownerAdvice: OwnerAdvice
	let catJokes: CatJokes?
	let errors: [String]
	
	private enum CodingKeys: String, CodingKey {
		case summary
		case bodyLanguage
		case contextualEmotion
		case ownerAdvice
		case catJokes
		case errors
	}
	
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		summary = try container.decode(EmotionSummary.self, forKey: .summary)
		bodyLanguage = try container.decode(BodyLanguageAnalysis.self, forKey: .bodyLanguage)
		contextualEmotion = try container.decode(ContextualEmotion.self, forKey: .contextualEmotion)
		ownerAdvice = try container.decode(OwnerAdvice.self, forKey: .ownerAdvice)
		catJokes = try container.decodeIfPresent(CatJokes.self, forKey: .catJokes)
		errors = try container.decodeIfPresent([String].self, forKey: .errors) ?? []
	}
}

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
		Log.network.info("Preparing analysis for fingerprint=\(imageFingerprint) size=\(photo.imageData.count) bytes")
		let encodedImage = encodeImage(photo.imageData)
		
		return AsyncStream<ParallelAnalysisUpdate>(bufferingPolicy: .unbounded) { continuation in
			let task = Task {
				let overallStart = CFAbsoluteTimeGetCurrent()
				var summary: EmotionSummary?
				var bodyLanguage: BodyLanguageAnalysis?
				var contextual: ContextualEmotion?
				var ownerAdvice: OwnerAdvice?
				var catJokes: CatJokes?
				var collectedErrors: [String] = []
				let decoder = JSONDecoder()

				do {
					try Task.checkCancellation()
					continuation.yield(.started)

					try await self.streamAnalysis(
						encodedImage: encodedImage,
						imageFingerprint: imageFingerprint,
						summary: &summary,
						bodyLanguage: &bodyLanguage,
						contextual: &contextual,
						ownerAdvice: &ownerAdvice,
						catJokes: &catJokes,
						collectedErrors: &collectedErrors,
						overallStart: overallStart,
						continuation: continuation,
						decoder: decoder
					)
					return
				} catch is CancellationError {
					Log.network.info("Parallel analysis cancelled")
					continuation.finish()
				} catch let error as AnalysisError {
					Log.network.error("Parallel analysis failed fingerprint=\(imageFingerprint) error=\(error.localizedDescription, privacy: .public)")
					continuation.yield(.failed(message: error.localizedDescription))
					continuation.finish()
				} catch {
					Log.network.error("Parallel analysis failed fingerprint=\(imageFingerprint) error=\(error.localizedDescription, privacy: .public)")
					continuation.yield(.failed(message: error.localizedDescription))
					continuation.finish()
				}
			}
			continuation.onTermination = { @Sendable _ in task.cancel() }
		}
	}
	
	private func streamAnalysis(
		encodedImage: String,
		imageFingerprint: String,
		summary: inout EmotionSummary?,
		bodyLanguage: inout BodyLanguageAnalysis?,
		contextual: inout ContextualEmotion?,
		ownerAdvice: inout OwnerAdvice?,
		catJokes: inout CatJokes?,
		collectedErrors: inout [String],
		overallStart: CFAbsoluteTime,
		continuation: AsyncStream<ParallelAnalysisUpdate>.Continuation,
		decoder: JSONDecoder
	) async throws {
		var payload: [String: Any] = [
			"images": [encodedImage],
			"stream": true
		]
		if !collectedErrors.isEmpty {
			payload["context"] = ["errors": collectedErrors]
		}
		let body = try JSONSerialization.data(withJSONObject: payload)
		
		var request = URLRequest(url: baseURL.appendingPathComponent(self.analyzePath))
		request.httpMethod = "POST"
		request.httpBody = body
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
		if let appKey = appKey {
			request.setValue("Bearer \(appKey)", forHTTPHeaderField: "Authorization")
		}
		
		Log.network.info("POST \(request.url?.absoluteString ?? self.analyzePath, privacy: .public) stream=true images=\(1) (after preflight)")
		
		let (bytes, response) = try await urlSession.bytes(for: request)
		guard let httpResponse = response as? HTTPURLResponse else {
			throw AnalysisError.networkError("Invalid response from server")
		}
		
		Log.network.info("Analysis streaming status=\(httpResponse.statusCode)")
		guard (200..<300).contains(httpResponse.statusCode) else {
			var errorData = Data()
			for try await byte in bytes {
				errorData.append(byte)
				if errorData.count > 4096 { break }
			}
			if let backendError = try? JSONDecoder().decode(BackendParallelErrorResponse.self, from: errorData) {
				throw AnalysisError.serverError(backendError.message ?? backendError.error ?? "Analysis service temporarily unavailable")
			}
			let fallbackText = String(data: errorData, encoding: .utf8) ?? ""
			throw AnalysisError.serverError("Analysis service returned status \(httpResponse.statusCode) \(fallbackText)")
		}
		
		for try await line in bytes.lines {
			if Task.isCancelled { break }
			guard line.hasPrefix("data:") else { continue }
			let jsonString = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
			guard !jsonString.isEmpty, let data = jsonString.data(using: .utf8) else { continue }
			guard let jsonEvent = try JSONSerialization.jsonObject(with: data) as? [String: Any],
			      let event = jsonEvent["event"] as? String else { continue }
			let payload = jsonEvent["payload"]
			
			switch event {
			case "started":
				continue
			case "summary":
				if let payload {
					let decoded: EmotionSummary = try decodePayload(payload, decoder: decoder)
					summary = decoded
					continuation.yield(.emotionSummaryCompleted(decoded))
				}
			case "bodyLanguage":
				if let payload {
					let decoded: BodyLanguageAnalysis = try decodePayload(payload, decoder: decoder)
					bodyLanguage = decoded
					continuation.yield(.bodyLanguageCompleted(decoded))
				}
			case "contextualEmotion":
				if let payload {
					let decoded: ContextualEmotion = try decodePayload(payload, decoder: decoder)
					contextual = decoded
					continuation.yield(.contextualEmotionCompleted(decoded))
				}
			case "ownerAdvice":
				if let payload {
					let decoded: OwnerAdvice = try decodePayload(payload, decoder: decoder)
					ownerAdvice = decoded
					continuation.yield(.ownerAdviceCompleted(decoded))
				}
			case "catJokes":
				if let payload {
					let decoded: CatJokes = try decodePayload(payload, decoder: decoder)
					catJokes = decoded
					continuation.yield(.catJokesCompleted(decoded))
				}
			case "partialFailures":
				if let payload {
					let decoded: [String] = try decodePayload(payload, decoder: decoder)
					collectedErrors.append(contentsOf: decoded)
					continuation.yield(.partialFailures(decoded))
				}
			case "error":
				let message: String
				if let payload {
					let decoded: StreamErrorPayload = try decodePayload(payload, decoder: decoder)
					message = decoded.message ?? "Analysis failed"
				} else {
					message = "Analysis failed"
				}
				Log.network.error("Parallel analysis failed fingerprint=\(imageFingerprint) error=\(message, privacy: .public)")
				continuation.yield(.failed(message: message))
				continuation.finish()
				return
		case "complete":
			if let payload {
				let final: StreamCompletePayload = try decodePayload(payload, decoder: decoder)
				if summary == nil {
					summary = final.summary
					continuation.yield(.emotionSummaryCompleted(final.summary))
				}
				if bodyLanguage == nil {
					bodyLanguage = final.bodyLanguage
					continuation.yield(.bodyLanguageCompleted(final.bodyLanguage))
				}
				if contextual == nil {
					contextual = final.contextualEmotion
					continuation.yield(.contextualEmotionCompleted(final.contextualEmotion))
				}
				if ownerAdvice == nil {
					ownerAdvice = final.ownerAdvice
					continuation.yield(.ownerAdviceCompleted(final.ownerAdvice))
				}
				if catJokes == nil, let jokes = final.catJokes {
					catJokes = jokes
					continuation.yield(.catJokesCompleted(jokes))
				}
				let newErrors = final.errors.filter { !collectedErrors.contains($0) }
				if !newErrors.isEmpty {
					collectedErrors.append(contentsOf: newErrors)
					continuation.yield(.partialFailures(newErrors))
				}
			}
			let duration = CFAbsoluteTimeGetCurrent() - overallStart
			Log.network.info("Analysis completed fingerprint=\(imageFingerprint) duration=\(String(format: "%.3f", duration))s")
			continuation.finish()
			return
			default:
				break
			}
		}
		
		if Task.isCancelled {
			Log.network.info("Parallel analysis cancelled")
			return
		}

		if summary == nil {
			let message = collectedErrors.last ?? "Analysis interrupted"
			Log.network.error("Parallel analysis incomplete fingerprint=\(imageFingerprint) message=\(message, privacy: .public)")
			continuation.yield(.failed(message: message))
		}
		
		let duration = CFAbsoluteTimeGetCurrent() - overallStart
		let summaryDone = summary != nil
		let bodyDone = bodyLanguage != nil
		let contextDone = contextual != nil
		let adviceDone = ownerAdvice != nil
		let jokesDone = catJokes != nil
		Log.network.info("Streaming phase finished fingerprint=\(imageFingerprint) duration=\(String(format: "%.3f", duration))s (summary: \(summaryDone), body: \(bodyDone), context: \(contextDone), advice: \(adviceDone), jokes: \(jokesDone))")
		continuation.finish()
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
	
	private func decodePayload<T: Decodable>(_ payload: Any, decoder: JSONDecoder) throws -> T {
		let data = try payloadData(from: payload)
		return try decoder.decode(T.self, from: data)
	}
	
	private func payloadData(from payload: Any) throws -> Data {
		if JSONSerialization.isValidJSONObject(payload) {
			return try JSONSerialization.data(withJSONObject: payload)
		}
		if let string = payload as? String {
			return try JSONEncoder().encode(string)
		}
		if let number = payload as? NSNumber {
			return try JSONEncoder().encode(number.doubleValue)
		}
		if payload is NSNull {
			return Data("null".utf8)
		}
		throw AnalysisError.invalidResponse("Unsupported payload type: \(type(of: payload))")
	}
	
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
