//
//  CaptionGenerationService.swift
//  Purrplexed
//
//  Service for generating different styles of captions based on cat analysis data.
//

import Foundation

// MARK: - Protocol

protocol CaptionGenerationService: AnyObject, Sendable {
	func generateCaption(
		style: ShareCardStyle,
		emotionSummary: EmotionSummary?,
		bodyLanguageAnalysis: BodyLanguageAnalysis?,
		contextualEmotion: ContextualEmotion?,
		ownerAdvice: OwnerAdvice?,
		catJokes: CatJokes?
	) async throws -> String
}

// MARK: - Backend Implementation

final class HTTPCaptionGenerationService: CaptionGenerationService {
	private let baseURL: URL
	private let captionPath: String
	private let urlSession: URLSession
	
	init(baseURL: URL, captionPath: String = "/api/caption", urlSession: URLSession = .shared) {
		self.baseURL = baseURL
		self.captionPath = captionPath
		self.urlSession = urlSession
	}
	
	func generateCaption(
		style: ShareCardStyle,
		emotionSummary: EmotionSummary?,
		bodyLanguageAnalysis: BodyLanguageAnalysis?,
		contextualEmotion: ContextualEmotion?,
		ownerAdvice: OwnerAdvice?,
		catJokes: CatJokes?
	) async throws -> String {
		
		let url = baseURL.appendingPathComponent(captionPath)
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		
		let payload: [String: Any] = [
			"style": style.rawValue,
			"emotionSummary": try? emotionSummary?.asDictionary(),
			"bodyLanguageAnalysis": try? bodyLanguageAnalysis?.asDictionary(),
			"contextualEmotion": try? contextualEmotion?.asDictionary(),
			"ownerAdvice": try? ownerAdvice?.asDictionary(),
			"catJokes": try? catJokes?.asDictionary()
		].compactMapValues { $0 }
		
		let body = try JSONSerialization.data(withJSONObject: payload)
		let (data, response) = try await urlSession.upload(for: request, from: body)
		
		guard let http = response as? HTTPURLResponse, 
			  (200..<300).contains(http.statusCode) else {
			throw CaptionGenerationError.networkError("Caption generation failed")
		}
		
		struct CaptionResponse: Decodable {
			let caption: String
		}
		
		let decoded = try JSONDecoder().decode(CaptionResponse.self, from: data)
		return decoded.caption
	}
}

// MARK: - Local Implementation

final class LocalCaptionGenerationService: CaptionGenerationService {
	
	func generateCaption(
		style: ShareCardStyle,
		emotionSummary: EmotionSummary?,
		bodyLanguageAnalysis: BodyLanguageAnalysis?,
		contextualEmotion: ContextualEmotion?,
		ownerAdvice: OwnerAdvice?,
		catJokes: CatJokes?
	) async throws -> String {
		
		// Simulate network delay for realistic UX
		try await Task.sleep(nanoseconds: 300_000_000) // 0.3s
		
		let context = CaptionContext(
			emotion: emotionSummary?.emotion ?? "Content",
			intensity: emotionSummary?.intensity ?? "Moderate", 
			description: emotionSummary?.description ?? "A peaceful cat",
			emoji: emotionSummary?.emoji ?? "😸",
			moodType: emotionSummary?.moodType ?? "happy",
			bodyLanguage: bodyLanguageAnalysis,
			contextualEmotion: contextualEmotion,
			ownerAdvice: ownerAdvice,
			catJokes: catJokes
		)
		
		return generateCaptionForStyle(style, context: context)
	}
	
	private func generateCaptionForStyle(_ style: ShareCardStyle, context: CaptionContext) -> String {
		switch style {
		case .funny:
			return generateFunnyCaption(context: context)
		case .sweet:
			return generateSweetCaption(context: context)
		case .sassy:
			return generateSassyCaption(context: context)
		case .poetic:
			return generatePoeticCaption(context: context)
		case .haiku:
			return generateHaikuCaption(context: context)
		case .educational:
			return generateEducationalCaption(context: context)
		case .minimal:
			return generateMinimalCaption(context: context)
		}
	}
	
	private func generateFunnyCaption(context: CaptionContext) -> String {
		let jokes = [
			"\(context.emoji) Current mood: Professional cat business",
			"\(context.emoji) Just contemplating my next 16-hour nap",
			"\(context.emoji) This is my 'I definitely didn't knock anything off the counter' face",
			"\(context.emoji) Plotting world domination, one purr at a time",
			"\(context.emoji) My human thinks they're in charge... how adorable",
			"\(context.emoji) Currently accepting belly rub applications (5-second limit strictly enforced)"
		]
		
		if let catJokes = context.catJokes, !catJokes.jokes.isEmpty {
			return "\(context.emoji) " + catJokes.jokes.randomElement()!
		}
		
		return jokes.randomElement()!
	}
	
	private func generateSweetCaption(context: CaptionContext) -> String {
		let sweetWords = ["precious", "adorable", "gentle", "loving", "sweet", "peaceful"]
		let sweetWord = sweetWords.randomElement()!
		
		let captions = [
			"\(context.emoji) Just being absolutely \(sweetWord)",
			"\(context.emoji) Pure love in feline form",
			"\(context.emoji) This little angel melts my heart",
			"\(context.emoji) Soft purrs and gentle dreams",
			"\(context.emoji) A moment of pure tenderness",
			"\(context.emoji) Home is wherever this sweetie is"
		]
		
		if context.moodType.lowercased().contains("happy") {
			return "\(context.emoji) Happiness looks like this perfect little soul"
		}
		
		return captions.randomElement()!
	}
	
	private func generateSassyCaption(context: CaptionContext) -> String {
		let captions = [
			"\(context.emoji) I woke up like this",
			"\(context.emoji) Serving looks and attitude",
			"\(context.emoji) Yes, I'm gorgeous. Next question?",
			"\(context.emoji) Main character energy 24/7",
			"\(context.emoji) Too cool for your treats",
			"\(context.emoji) Born to be fabulous, forced to be a house cat"
		]
		
		if context.intensity.lowercased().contains("high") {
			return "\(context.emoji) Peak confidence achieved"
		}
		
		return captions.randomElement()!
	}
	
	private func generatePoeticCaption(context: CaptionContext) -> String {
		let poeticDescriptions = [
			"In whispered moments of stillness,\nA feline spirit dances with light,\nEmbodying the gentle art of simply being.",
			
			"Like moonbeams caught in velvet fur,\nThis soul carries ancient wisdom\nIn every graceful breath.",
			
			"Here dwells a creature of pure poetry,\nWhose very presence transforms\nOrdinary moments into magic.",
			
			"In the cathedral of everyday life,\nThis gentle being offers communion\nWith the sacred art of contentment.",
			
			"Wrapped in fur and starlight,\nA living sonnet purrs\nThe sweet song of home."
		]
		
		return poeticDescriptions.randomElement()!
	}
	
	private func generateHaikuCaption(context: CaptionContext) -> String {
		let haikus = [
			"Whiskers twitch gently\nSunlight paints fur golden-soft\nPerfect peace achieved",
			
			"Eyes like autumn pools\nHold secrets of feline dreams\nWisdom purrs within",
			
			"Paws tucked neat and small\nThe art of being, mastered\nZen in feline form",
			
			"Tail curled like question\nAnswering life's mysteries\nWith simple presence",
			
			"Morning light dances\nOn fur that catches starbeams\nDivinity sleeps"
		]
		
		// Custom haiku based on emotion
		let emotion = context.emotion.lowercased()
		switch emotion {
		case let e where e.contains("content") || e.contains("peaceful"):
			return "In perfect stillness\n\(context.emotion.capitalized) radiates outward\nThe world holds its breath"
		case let e where e.contains("playful") || e.contains("alert"):
			return "Energy coiled tight\n\(context.emotion.capitalized) eyes track everything\nSpring ready to leap"
		default:
			break
		}
		
		return haikus.randomElement()!
	}
	
	private func generateEducationalCaption(context: CaptionContext) -> String {
		var educational = "\(context.emoji) "
		
		// Start with the main emotion and what it means
		educational += "This expression shows a cat in a \(context.emotion.lowercased()) state. "
		
		// Add body language insights if available
		if let bodyLanguage = context.bodyLanguage {
			if bodyLanguage.ears.lowercased().contains("forward") {
				educational += "Forward-facing ears indicate alertness and interest. "
			}
			if bodyLanguage.tail.lowercased().contains("still") {
				educational += "A still tail suggests calm confidence. "
			}
			if bodyLanguage.eyes.lowercased().contains("half") {
				educational += "Half-closed eyes are a sign of trust and relaxation. "
			}
		}
		
		// Add contextual insights
		if let contextual = context.contextualEmotion {
			if !contextual.environmentalFactors.isEmpty {
				educational += "Environmental factors like \(contextual.environmentalFactors.first?.lowercased() ?? "familiar surroundings") contribute to this emotional state."
			}
		}
		
		return educational
	}
	
	private func generateMinimalCaption(context: CaptionContext) -> String {
		let minimalOptions = [
			"\(context.emoji)",
			"\(context.emoji) \(context.emotion.lowercased())",
			"\(context.emoji) mood",
			"✨ \(context.emotion.lowercased())",
			"\(context.emoji) vibes",
			"just \(context.emotion.lowercased()) \(context.emoji)"
		]
		
		return minimalOptions.randomElement()!
	}
}

// MARK: - Mock Implementation

final class MockCaptionGenerationService: CaptionGenerationService {
	func generateCaption(
		style: ShareCardStyle,
		emotionSummary: EmotionSummary?,
		bodyLanguageAnalysis: BodyLanguageAnalysis?,
		contextualEmotion: ContextualEmotion?,
		ownerAdvice: OwnerAdvice?,
		catJokes: CatJokes?
	) async throws -> String {
		try await Task.sleep(nanoseconds: 200_000_000)
		
		let emoji = emotionSummary?.emoji ?? "😸"
		
		switch style {
		case .funny:
			return "\(emoji) Just contemplating my next 16-hour nap"
		case .sweet:
			return "\(emoji) Pure love in feline form"
		case .sassy:
			return "\(emoji) I woke up like this"
		case .poetic:
			return "In whispered moments of stillness,\nA feline spirit dances with light \(emoji)"
		case .haiku:
			return "Whiskers twitch softly\nSunlight paints fur golden-warm\nPerfect peace achieved"
		case .educational:
			return "\(emoji) This expression shows a cat in a relaxed state, with forward ears indicating alertness"
		case .minimal:
			return "\(emoji) vibes"
		}
	}
}

// MARK: - Supporting Types

struct CaptionContext {
	let emotion: String
	let intensity: String
	let description: String
	let emoji: String
	let moodType: String
	let bodyLanguage: BodyLanguageAnalysis?
	let contextualEmotion: ContextualEmotion?
	let ownerAdvice: OwnerAdvice?
	let catJokes: CatJokes?
}

enum CaptionGenerationError: Error, LocalizedError {
	case networkError(String)
	case invalidResponse
	
	var errorDescription: String? {
		switch self {
		case .networkError(let message):
			return message
		case .invalidResponse:
			return "Invalid response from caption service"
		}
	}
}

// MARK: - Codable Extensions

extension EmotionSummary {
	func asDictionary() throws -> [String: Any] {
		let data = try JSONEncoder().encode(self)
		return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
	}
}

extension BodyLanguageAnalysis {
	func asDictionary() throws -> [String: Any] {
		let data = try JSONEncoder().encode(self)
		return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
	}
}

extension ContextualEmotion {
	func asDictionary() throws -> [String: Any] {
		let data = try JSONEncoder().encode(self)
		return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
	}
}

extension OwnerAdvice {
	func asDictionary() throws -> [String: Any] {
		let data = try JSONEncoder().encode(self)
		return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
	}
}

extension CatJokes {
	func asDictionary() throws -> [String: Any] {
		let data = try JSONEncoder().encode(self)
		return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
	}
}
