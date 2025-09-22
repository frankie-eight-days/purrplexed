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
	let catJokes: CatJokes?
	
	private enum CodingKeys: String, CodingKey {
		case emotionSummary = "emotion_summary"
		case bodyLanguage = "body_language" 
		case contextualEmotion = "contextual_emotion"
		case ownerAdvice = "owner_advice"
		case catJokes = "cat_jokes"
	}
	
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		// Handle emotion_summary - can be either array or single object
		if container.contains(.emotionSummary) {
			// Try to decode as array first, then fall back to single object
			if let emotionArray = try? container.decode([EmotionSummary].self, forKey: .emotionSummary) {
				self.emotionSummary = emotionArray.first
			} else {
				self.emotionSummary = try? container.decode(EmotionSummary.self, forKey: .emotionSummary)
			}
		} else {
			self.emotionSummary = nil
		}
		
		// Handle body_language - single object expected
		self.bodyLanguage = try? container.decode(BodyLanguageAnalysis.self, forKey: .bodyLanguage)
		
		// Handle contextual_emotion - single object expected  
		self.contextualEmotion = try? container.decode(ContextualEmotion.self, forKey: .contextualEmotion)
		
		// Handle owner_advice - single object expected
		self.ownerAdvice = try? container.decode(OwnerAdvice.self, forKey: .ownerAdvice)
		
		// Handle cat_jokes - single object expected
		self.catJokes = try? container.decode(CatJokes.self, forKey: .catJokes)
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
	private let appKey: String?
	private let urlSession: URLSession
	
	init(baseURL: URL, uploadPath: String = "/api/upload", analyzePath: String = "/api/analyze", appKey: String? = nil, urlSession: URLSession = .shared) {
		self.baseURL = baseURL
		self.uploadPath = uploadPath
		self.analyzePath = analyzePath
		self.appKey = appKey
		self.urlSession = urlSession
	}
	
	// MARK: - Upload Photo
	
	func uploadPhoto(_ photo: CapturedPhoto) async throws -> String {
		let startTime = CFAbsoluteTimeGetCurrent()
		let url = baseURL.appendingPathComponent(uploadPath)
		Log.network.info("POST \(url.absoluteString, privacy: .public)")
		
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		
		// Add API key authentication if available
		if let appKey = appKey {
			request.setValue("Bearer \(appKey)", forHTTPHeaderField: "Authorization")
		}
		
		// Create multipart form data
		let boundary = "Boundary-\(UUID().uuidString)"
		request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
		
		let body = createMultipartBody(imageData: photo.imageData, boundary: boundary)
		
		let (data, response) = try await urlSession.upload(for: request, from: body)
		let status = (response as? HTTPURLResponse)?.statusCode ?? -1
		
		// Log raw upload response for debugging
		let rawResponseString = String(data: data, encoding: .utf8) ?? "<unable to decode as UTF-8>"
		Log.network.info("Raw upload response (status=\(status)): \(rawResponseString, privacy: .public)")
		
		guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
			Log.network.error("Upload HTTP error statusCode=\(status) rawBody=\(rawResponseString, privacy: .public)")
			if let err = try? JSONDecoder().decode(BackendParallelErrorResponse.self, from: data) {
				let message = err.message ?? err.error ?? "Upload server error"
				throw AnalysisError.serverError(message)
			} else {
				throw AnalysisError.networkError("Upload server error")
			}
		}
		
		do {
			let decoded = try JSONDecoder().decode(UploadResponse.self, from: data)
			let duration = CFAbsoluteTimeGetCurrent() - startTime
			Log.network.info("Upload decode success fileUri=\(decoded.fileUri, privacy: .private(mask: .hash)) duration=\(String(format: "%.3f", duration))s")
			return decoded.fileUri
		} catch {
			let duration = CFAbsoluteTimeGetCurrent() - startTime
			Log.network.error("Failed to decode upload response: \(error) duration=\(String(format: "%.3f", duration))s")
			Log.network.error("Raw upload response that failed to decode: \(rawResponseString, privacy: .public)")
			throw AnalysisError.invalidResponse("Invalid upload response format")
		}
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
	
	func analyzeCatJokes(fileUri: String) async throws -> CatJokes {
		let response = try await performAnalysis(fileUri: fileUri, analysisType: "cat_jokes")
		guard let result = response.catJokes else {
			throw AnalysisError.invalidResponse("Missing cat_jokes in response")
		}
		return result
	}
	
	// MARK: - Parallel Analysis
	
	func analyzeParallel(photo: CapturedPhoto) async throws -> AsyncStream<ParallelAnalysisUpdate> {
		AsyncStream { continuation in
			Task {
				let overallStartTime = CFAbsoluteTimeGetCurrent()
				Log.network.info("Starting parallel analysis - overall timer started")
				do {
					// Step 1: Upload photo
					continuation.yield(.uploadStarted)
					let fileUri = try await uploadPhoto(photo)
					continuation.yield(.uploadCompleted(fileUri: fileUri))
					
					// Step 2: First, get emotion summary to determine mood-based analysis
					var emotionSummary: EmotionSummary?
					do {
						emotionSummary = try await self.analyzeEmotionSummary(fileUri: fileUri)
						continuation.yield(.emotionSummaryCompleted(emotionSummary!))
					} catch {
						Log.network.error("Emotion summary analysis failed: \(error.localizedDescription)")
						continuation.yield(.failed(message: "Emotion analysis failed"))
					}
					
					// Step 3: Run remaining analyses in parallel, including conditional mood-based analysis
					await withTaskGroup(of: Void.self) { group in
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
						
						// Cat Jokes - only if mood is happy
						if let emotionSummary = emotionSummary, emotionSummary.moodType.lowercased() == "happy" {
							group.addTask {
								do {
									let result = try await self.analyzeCatJokes(fileUri: fileUri)
									continuation.yield(.catJokesCompleted(result))
								} catch {
									Log.network.error("Cat jokes analysis failed: \(error.localizedDescription)")
									continuation.yield(.failed(message: "Cat jokes analysis failed"))
								}
							}
						}
					}
					
					let overallDuration = CFAbsoluteTimeGetCurrent() - overallStartTime
					Log.network.info("Parallel analysis completed successfully - total duration=\(String(format: "%.3f", overallDuration))s")
					continuation.finish()
					
				} catch {
					let overallDuration = CFAbsoluteTimeGetCurrent() - overallStartTime
					Log.network.error("Parallel analysis failed: \(error.localizedDescription) - total duration=\(String(format: "%.3f", overallDuration))s")
					continuation.yield(.failed(message: "Analysis failed"))
					continuation.finish()
				}
			}
		}
	}
	
	// MARK: - Private Helpers
	
	private func performAnalysis(fileUri: String, analysisType: String) async throws -> SingleAnalysisResponse {
		let startTime = CFAbsoluteTimeGetCurrent()
		let url = baseURL.appendingPathComponent(analyzePath)
		Log.network.info("POST \(url.absoluteString, privacy: .public) type=\(analysisType)")
		
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		
		// Add API key authentication if available
		if let appKey = appKey {
			request.setValue("Bearer \(appKey)", forHTTPHeaderField: "Authorization")
		}
		
		let payload: [String: Any] = [
			"fileUri": fileUri,
			"analysisType": analysisType
		]
		
		// Log the request payload for debugging
		if let payloadData = try? JSONSerialization.data(withJSONObject: payload),
		   let payloadString = String(data: payloadData, encoding: .utf8) {
			Log.network.info("Request payload: \(payloadString, privacy: .public)")
		}
		
		let body = try JSONSerialization.data(withJSONObject: payload)
		let (data, response) = try await urlSession.upload(for: request, from: body)
		let status = (response as? HTTPURLResponse)?.statusCode ?? -1
		
		// Log raw response data before any processing
		let rawResponseString = String(data: data, encoding: .utf8) ?? "<unable to decode as UTF-8>"
		Log.network.info("Raw API response (type=\(analysisType), status=\(status)): \(rawResponseString, privacy: .public)")
		
		guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
			let duration = CFAbsoluteTimeGetCurrent() - startTime
			Log.network.error("Analysis HTTP error statusCode=\(status) type=\(analysisType) duration=\(String(format: "%.3f", duration))s rawBody=\(rawResponseString, privacy: .public)")
			if let err = try? JSONDecoder().decode(BackendParallelErrorResponse.self, from: data) {
				let message = err.message ?? err.error ?? "Analysis server error"
				throw AnalysisError.serverError(message)
			} else {
				throw AnalysisError.networkError("Analysis server error")
			}
		}
		
		do {
			let decoded = try JSONDecoder().decode(SingleAnalysisResponse.self, from: data)
			let duration = CFAbsoluteTimeGetCurrent() - startTime
			Log.network.info("Analysis decode success type=\(analysisType) duration=\(String(format: "%.3f", duration))s")
			return decoded
		} catch {
			let duration = CFAbsoluteTimeGetCurrent() - startTime
			Log.network.error("Failed to decode analysis response (type=\(analysisType)): \(error) duration=\(String(format: "%.3f", duration))s")
			Log.network.error("Raw response that failed to decode: \(rawResponseString, privacy: .public)")
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
