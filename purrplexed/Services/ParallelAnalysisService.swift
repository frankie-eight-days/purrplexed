//
//  ParallelAnalysisService.swift
//  Purrplexed
//
//  HTTP-backed parallel analysis service that uploads an image and performs parallel analyses.
//

import Foundation
import CryptoKit

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
				do {
					try Task.checkCancellation()
					continuation.yield(ParallelAnalysisUpdate.started)
					
					var context: [String: Any] = [:]
					var partialErrors: [String] = []
					let images = [encodedImage]
					
					let summaryResponse = try await self.fetchSingleAnalysis(type: "summary", images: images, context: [:])
					partialErrors.append(contentsOf: summaryResponse.errors ?? [])
					guard let summary = summaryResponse.summary else {
						Log.network.error("Summary response missing required payload")
						continuation.yield(.failed(message: "Analysis unavailable"))
						continuation.finish()
						return
					}
					if let summaryContext = self.encodeContextValue(summary) {
						context["summary"] = summaryContext
					}
					continuation.yield(.emotionSummaryCompleted(summary))
					
					do {
						let response = try await self.fetchSingleAnalysis(type: "bodyLanguage", images: images, context: context)
						partialErrors.append(contentsOf: response.errors ?? [])
						if let body = response.bodyLanguage {
							if let json = self.encodeContextValue(body) { context["bodyLanguage"] = json }
							continuation.yield(.bodyLanguageCompleted(body))
						} else {
							partialErrors.append("Body language analysis unavailable")
						}
                    } catch {
                        let message = "Body language analysis failed: \(error.localizedDescription)"
                        Log.network.warning("\(message, privacy: .public)")
                        partialErrors.append(message)
                    }
					
					do {
						let response = try await self.fetchSingleAnalysis(type: "contextualEmotion", images: images, context: context)
						partialErrors.append(contentsOf: response.errors ?? [])
						if let contextual = response.contextualEmotion {
							if let json = self.encodeContextValue(contextual) { context["contextualEmotion"] = json }
							continuation.yield(.contextualEmotionCompleted(contextual))
						} else {
							partialErrors.append("Contextual analysis unavailable")
						}
                    } catch {
                        let message = "Contextual analysis failed: \(error.localizedDescription)"
                        Log.network.warning("\(message, privacy: .public)")
                        partialErrors.append(message)
                    }
					
					do {
						let response = try await self.fetchSingleAnalysis(type: "ownerAdvice", images: images, context: context)
						partialErrors.append(contentsOf: response.errors ?? [])
						if let advice = response.ownerAdvice {
							if let json = self.encodeContextValue(advice) { context["ownerAdvice"] = json }
							continuation.yield(.ownerAdviceCompleted(advice))
						} else {
							partialErrors.append("Owner advice unavailable")
						}
                    } catch {
                        let message = "Owner advice analysis failed: \(error.localizedDescription)"
                        Log.network.warning("\(message, privacy: .public)")
                        partialErrors.append(message)
                    }
					
					if ["content", "playful"].contains(summary.moodType.lowercased()) {
						do {
							let response = try await self.fetchSingleAnalysis(type: "catJokes", images: images, context: context)
							partialErrors.append(contentsOf: response.errors ?? [])
							if let jokes = response.catJokes {
								continuation.yield(.catJokesCompleted(jokes))
							}
                        } catch {
                            let message = "Cat jokes request failed: \(error.localizedDescription)"
                            Log.network.warning("\(message, privacy: .public)")
                            partialErrors.append(message)
                        }
					}
					
					if !partialErrors.isEmpty {
						continuation.yield(.partialFailures(partialErrors))
					}
					
					let duration = CFAbsoluteTimeGetCurrent() - overallStart
					Log.network.info("Analysis completed fingerprint=\(imageFingerprint) duration=\(String(format: "%.3f", duration))s")
					continuation.finish()
				} catch is CancellationError {
					Log.network.info("Parallel analysis cancelled")
					continuation.finish()
				} catch {
					let duration = CFAbsoluteTimeGetCurrent() - overallStart
					Log.network.error("Parallel analysis failed fingerprint=\(imageFingerprint) duration=\(String(format: "%.3f", duration))s error=\(error.localizedDescription, privacy: .public)")
					continuation.yield(.failed(message: "Analysis failed"))
					continuation.finish()
				}
			}
			continuation.onTermination = { @Sendable _ in task.cancel() }
		}
	}
	
	private func encodeImage(_ data: Data) -> String {
		let base64 = data.base64EncodedString()
		return "data:image/jpeg;base64,\(base64)"
	}
	
	private func encodeContextValue<T: Encodable>(_ value: T) -> Any? {
		guard let data = try? JSONEncoder().encode(value) else { return nil }
		return try? JSONSerialization.jsonObject(with: data, options: [])
	}
	
	private func fetchSingleAnalysis(type: String, images: [String], context: [String: Any]) async throws -> SingleAnalysisResponse {
		try await sendRequest(images: images, analysisType: type, context: context)
	}
	
	private func sendRequest(images: [String], analysisType: String?, context: [String: Any]) async throws -> SingleAnalysisResponse {
		var payload: [String: Any] = ["images": images]
		if let analysisType {
			payload["analysisType"] = analysisType
		}
		if !context.isEmpty {
			if JSONSerialization.isValidJSONObject(context) {
				payload["context"] = context
			} else {
				Log.network.warning("Skipping non-serializable context for type \(analysisType ?? "full")")
			}
		}
		guard JSONSerialization.isValidJSONObject(payload) else {
			throw AnalysisError.invalidResponse("Invalid request payload")
		}
		
		let body = try JSONSerialization.data(withJSONObject: payload, options: [])
		var request = URLRequest(url: baseURL.appendingPathComponent(self.analyzePath))
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		if let appKey = appKey {
			request.setValue("Bearer \(appKey)", forHTTPHeaderField: "Authorization")
		}
		
		Log.network.info("POST \(request.url?.absoluteString ?? self.analyzePath, privacy: .public) type=\(analysisType ?? "full") images=\(images.count)")
		let requestStart = CFAbsoluteTimeGetCurrent()
		do {
			let (data, response) = try await urlSession.upload(for: request, from: body)
			let duration = CFAbsoluteTimeGetCurrent() - requestStart
			let status = (response as? HTTPURLResponse)?.statusCode ?? -1
			Log.network.info("Analysis response status=\(status) type=\(analysisType ?? "full") duration=\(String(format: "%.3f", duration))s")
			
			guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
				if let backendError = try? JSONDecoder().decode(BackendParallelErrorResponse.self, from: data) {
					Log.network.error("Analysis request backend error type=\(analysisType ?? "full") duration=\(String(format: "%.3f", duration))s error=\(backendError.message ?? backendError.error ?? "unknown", privacy: .public)")
					throw AnalysisError.serverError(backendError.message ?? backendError.error ?? "Analysis service temporarily unavailable")
				}
				Log.network.error("Analysis service unavailable type=\(analysisType ?? "full") duration=\(String(format: "%.3f", duration))s status=\(status)")
				throw AnalysisError.networkError("Analysis service temporarily unavailable")
			}
			
			return try JSONDecoder().decode(SingleAnalysisResponse.self, from: data)
		} catch {
			let duration = CFAbsoluteTimeGetCurrent() - requestStart
			Log.network.error("Analysis request failed type=\(analysisType ?? "full") duration=\(String(format: "%.3f", duration))s error=\(error.localizedDescription, privacy: .public)")
			throw error
		}
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
