//
//  ParallelAnalysisService.swift
//  Purrplexed
//
//  HTTP-backed parallel analysis service that uploads an image and performs parallel analyses.
//

import Foundation

struct UploadResponse: Decodable {
	let fileUri: String
	let mimeType: String?
	let expiresAt: String?
}

struct SingleAnalysisResponse: Decodable {
	let emotionSummary: EmotionSummary?
	let bodyLanguage: BodyLanguageAnalysis?
	let contextualEmotion: ContextualEmotion?
	let ownerAdvice: OwnerAdvice?
	
	private enum CodingKeys: String, CodingKey {
		case emotionSummary = "emotion_summary"
		case bodyLanguage = "body_language" 
		case contextualEmotion = "contextual_emotion"
		case ownerAdvice = "owner_advice"
	}
}

struct BackendParallelErrorResponse: Decodable {
	let error: String?
	let message: String?
}

final class HTTPParallelAnalysisService: ParallelAnalysisService {
	private let baseURL: URL
	private let uploadPath: String
	private let analyzePath: String
	private let urlSession: URLSession
	
	init(baseURL: URL, uploadPath: String = "/api/upload", analyzePath: String = "/api/analyze", urlSession: URLSession = .shared) {
		self.baseURL = baseURL
		self.uploadPath = uploadPath
		self.analyzePath = analyzePath
		self.urlSession = urlSession
	}
	
	// MARK: - Upload Photo
	
	func uploadPhoto(_ photo: CapturedPhoto) async throws -> String {
		let url = baseURL.appendingPathComponent(uploadPath)
		Log.network.info("POST \(url.absoluteString, privacy: .public)")
		
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		
		// Create multipart form data
		let boundary = "Boundary-\(UUID().uuidString)"
		request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
		
		let body = createMultipartBody(imageData: photo.imageData, boundary: boundary)
		
		let (data, response) = try await urlSession.upload(for: request, from: body)
		let status = (response as? HTTPURLResponse)?.statusCode ?? -1
		
		guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
			let bodyText = String(data: data, encoding: .utf8) ?? ""
			Log.network.error("Upload HTTP error statusCode=\(status) body=\(bodyText, privacy: .public)")
			if let err = try? JSONDecoder().decode(BackendParallelErrorResponse.self, from: data) {
				let message = err.message ?? err.error ?? "Upload server error"
				throw AnalysisError.serverError(message)
			} else {
				throw AnalysisError.networkError("Upload server error")
			}
		}
		
		let decoded = try JSONDecoder().decode(UploadResponse.self, from: data)
		Log.network.info("Upload success fileUri=\(decoded.fileUri, privacy: .private(mask: .hash))")
		return decoded.fileUri
	}
	
	// MARK: - Individual Analysis Methods
	
	func analyzeEmotionSummary(fileUri: String) async throws -> EmotionSummary {
		let response = try await performAnalysis(fileUri: fileUri, analysisType: "emotion_summary")
		guard let result = response.emotionSummary else {
			throw AnalysisError.invalidResponse("Missing emotion_summary in response")
		}
		return result
	}
	
	func analyzeBodyLanguage(fileUri: String) async throws -> BodyLanguageAnalysis {
		let response = try await performAnalysis(fileUri: fileUri, analysisType: "body_language")
		guard let result = response.bodyLanguage else {
			throw AnalysisError.invalidResponse("Missing body_language in response")
		}
		return result
	}
	
	func analyzeContextualEmotion(fileUri: String) async throws -> ContextualEmotion {
		let response = try await performAnalysis(fileUri: fileUri, analysisType: "contextual_emotion")
		guard let result = response.contextualEmotion else {
			throw AnalysisError.invalidResponse("Missing contextual_emotion in response")
		}
		return result
	}
	
	func analyzeOwnerAdvice(fileUri: String) async throws -> OwnerAdvice {
		let response = try await performAnalysis(fileUri: fileUri, analysisType: "owner_advice")
		guard let result = response.ownerAdvice else {
			throw AnalysisError.invalidResponse("Missing owner_advice in response")
		}
		return result
	}
	
	// MARK: - Parallel Analysis
	
	func analyzeParallel(photo: CapturedPhoto) async throws -> AsyncStream<ParallelAnalysisUpdate> {
		AsyncStream { continuation in
			Task {
				do {
					// Step 1: Upload photo
					continuation.yield(.uploadStarted)
					let fileUri = try await uploadPhoto(photo)
					continuation.yield(.uploadCompleted(fileUri: fileUri))
					
					// Step 2: Run parallel analyses
					await withTaskGroup(of: Void.self) { group in
						// Emotion Summary
						group.addTask {
							do {
								let result = try await self.analyzeEmotionSummary(fileUri: fileUri)
								continuation.yield(.emotionSummaryCompleted(result))
							} catch {
								Log.network.error("Emotion summary analysis failed: \(error.localizedDescription)")
								continuation.yield(.failed(message: "Emotion analysis failed"))
							}
						}
						
						// Body Language  
						group.addTask {
							do {
								let result = try await self.analyzeBodyLanguage(fileUri: fileUri)
								continuation.yield(.bodyLanguageCompleted(result))
							} catch {
								Log.network.error("Body language analysis failed: \(error.localizedDescription)")
								continuation.yield(.failed(message: "Body language analysis failed"))
							}
						}
						
						// Contextual Emotion
						group.addTask {
							do {
								let result = try await self.analyzeContextualEmotion(fileUri: fileUri)
								continuation.yield(.contextualEmotionCompleted(result))
							} catch {
								Log.network.error("Contextual emotion analysis failed: \(error.localizedDescription)")
								continuation.yield(.failed(message: "Contextual analysis failed"))
							}
						}
						
						// Owner Advice
						group.addTask {
							do {
								let result = try await self.analyzeOwnerAdvice(fileUri: fileUri)
								continuation.yield(.ownerAdviceCompleted(result))
							} catch {
								Log.network.error("Owner advice analysis failed: \(error.localizedDescription)")
								continuation.yield(.failed(message: "Owner advice analysis failed"))
							}
						}
					}
					
					continuation.finish()
					
				} catch {
					Log.network.error("Parallel analysis failed: \(error.localizedDescription)")
					continuation.yield(.failed(message: "Analysis failed"))
					continuation.finish()
				}
			}
		}
	}
	
	// MARK: - Private Helpers
	
	private func performAnalysis(fileUri: String, analysisType: String) async throws -> SingleAnalysisResponse {
		let url = baseURL.appendingPathComponent(analyzePath)
		Log.network.info("POST \(url.absoluteString, privacy: .public) type=\(analysisType)")
		
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		
		let payload: [String: Any] = [
			"fileUri": fileUri,
			"analysisType": analysisType
		]
		
		let body = try JSONSerialization.data(withJSONObject: payload)
		let (data, response) = try await urlSession.upload(for: request, from: body)
		let status = (response as? HTTPURLResponse)?.statusCode ?? -1
		
		guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
			let bodyText = String(data: data, encoding: .utf8) ?? ""
			Log.network.error("Analysis HTTP error statusCode=\(status) body=\(bodyText, privacy: .public)")
			if let err = try? JSONDecoder().decode(BackendParallelErrorResponse.self, from: data) {
				let message = err.message ?? err.error ?? "Analysis server error"
				throw AnalysisError.serverError(message)
			} else {
				throw AnalysisError.networkError("Analysis server error")
			}
		}
		
		do {
			let decoded = try JSONDecoder().decode(SingleAnalysisResponse.self, from: data)
			Log.network.info("Analysis success type=\(analysisType)")
			return decoded
		} catch {
			Log.network.error("Failed to decode analysis response: \(error)")
			throw AnalysisError.invalidResponse("Invalid response format")
		}
	}
	
	private func createMultipartBody(imageData: Data, boundary: String) -> Data {
		var body = Data()
		
		// Add file field
		body.append("--\(boundary)\r\n".data(using: .utf8)!)
		body.append("Content-Disposition: form-data; name=\"file\"; filename=\"cat_image.jpg\"\r\n".data(using: .utf8)!)
		body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
		body.append(imageData)
		body.append("\r\n".data(using: .utf8)!)
		
		// Close boundary
		body.append("--\(boundary)--\r\n".data(using: .utf8)!)
		
		return body
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
