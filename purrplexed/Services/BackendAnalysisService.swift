//
//  BackendAnalysisService.swift
//  Purrplexed
//
//  HTTP-backed analysis service that uploads an image and receives text.
//

import Foundation

struct BackendAnalysisResponse: Decodable { let analysis: String?; let text: String? }
struct BackendErrorResponse: Decodable { let error: String?; let message: String? }

final class ProductionAnalysisService: AnalysisService {
	private let baseURL: URL
	private let analyzePath: String
	private let prompt: String
	private let appKey: String?
	private let urlSession: URLSession
	
	init(env: Env, urlSession: URLSession = .shared) {
		guard let baseURL = env.apiBaseURL else {
			fatalError("ProductionAnalysisService requires API_BASE_URL in Env.plist")
		}
		self.baseURL = baseURL
		self.analyzePath = env.analyzePath
		self.prompt = "Summarize the cat's state in plain language."
		self.appKey = env.appKey
		self.urlSession = urlSession
	}
	
	func analyze(photo: CapturedPhoto, audio: CapturedAudio?) async throws -> AsyncStream<AnalysisStatus> {
		AsyncStream { continuation in
			Task {
				continuation.yield(.queued)
				do {
					let url = baseURL.appendingPathComponent(analyzePath)
					Log.network.info("POST \(url.absoluteString, privacy: .public)")
					var request = URLRequest(url: url)
					request.httpMethod = "POST"
					request.setValue("application/json", forHTTPHeaderField: "Content-Type")
					
					// Add API key authentication if available
					if let appKey = appKey {
						request.setValue("Bearer \(appKey)", forHTTPHeaderField: "Authorization")
					}

					// Backend expects JSON with base64 data URL string + optional context text
					let base64 = photo.imageData.base64EncodedString()
					let dataURL = "data:image/jpeg;base64,\(base64)"
					let payload: [String: Any] = [
						"image": dataURL,
						"mimeType": "image/jpeg",
						"text": prompt
					]
					let body = try JSONSerialization.data(withJSONObject: payload)
					let (data, response) = try await urlSession.upload(for: request, from: body)
					let status = (response as? HTTPURLResponse)?.statusCode ?? -1
					guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
						let bodyText = String(data: data, encoding: .utf8) ?? ""
						Log.network.error("HTTP error statusCode=\(status) body=\(bodyText, privacy: .public)")
						if let err = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
							let message = err.message ?? err.error ?? "Server error"
							continuation.yield(.failed(message: message))
						} else {
							continuation.yield(.failed(message: "Server error"))
						}
						continuation.finish()
						return
					}
					let decoded = try JSONDecoder().decode(BackendAnalysisResponse.self, from: data)
					let text = decoded.analysis ?? decoded.text ?? ""
					Log.network.info("Analyze success \(text, privacy: .private(mask: .hash))")
					let result = AnalysisResult(translatedText: text, confidence: 0.0, funFact: nil)
					continuation.yield(.completed(result))
					continuation.finish()
				} catch {
					Log.network.error("Analyze request failed: \(error.localizedDescription, privacy: .public)")
					continuation.yield(.failed(message: "Network error"))
					continuation.finish()
				}
			}
		}
	}
}
