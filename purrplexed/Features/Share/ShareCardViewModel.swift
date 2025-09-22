//
//  ShareCardViewModel.swift
//  Purrplexed
//
//  ViewModel for share card creation with different caption styles.
//

import Foundation
import SwiftUI
import UIKit

@MainActor
final class ShareCardViewModel: ObservableObject {
	@Published var selectedStyle: ShareCardStyle = .funny
	@Published var currentCaption: String? = nil
	@Published var isGeneratingCard: Bool = false
	@Published var generatingStyle: ShareCardStyle? = nil
	@Published var showShareSheet: Bool = false
	@Published var shareImage: UIImage? = nil
	
	let catImageData: Data?
	let emotionSummary: EmotionSummary?
	let bodyLanguageAnalysis: BodyLanguageAnalysis?
	let contextualEmotion: ContextualEmotion?
	let ownerAdvice: OwnerAdvice?
	let catJokes: CatJokes?
	
	private let captionService: CaptionGenerationService
	private var generatedCaptions: [ShareCardStyle: String] = [:]
	
	init(
		catImageData: Data?,
		emotionSummary: EmotionSummary?,
		bodyLanguageAnalysis: BodyLanguageAnalysis?,
		contextualEmotion: ContextualEmotion?,
		ownerAdvice: OwnerAdvice?,
		catJokes: CatJokes?,
		captionService: CaptionGenerationService
	) {
		self.catImageData = catImageData
		self.emotionSummary = emotionSummary
		self.bodyLanguageAnalysis = bodyLanguageAnalysis
		self.contextualEmotion = contextualEmotion
		self.ownerAdvice = ownerAdvice
		self.catJokes = catJokes
		self.captionService = captionService
	}
	
	func generateInitialCard() {
		selectStyle(.funny) // Start with funny style
	}
	
	func selectStyle(_ style: ShareCardStyle) {
		selectedStyle = style
		
		// If we already have a caption for this style, use it
		if let existingCaption = generatedCaptions[style] {
			currentCaption = existingCaption
			return
		}
		
		// Generate new caption for this style
		generateCaption(for: style)
	}
	
	private func generateCaption(for style: ShareCardStyle) {
		generatingStyle = style
		
		Task {
			do {
				let caption = try await captionService.generateCaption(
					style: style,
					emotionSummary: emotionSummary,
					bodyLanguageAnalysis: bodyLanguageAnalysis,
					contextualEmotion: contextualEmotion,
					ownerAdvice: ownerAdvice,
					catJokes: catJokes
				)
				
				generatedCaptions[style] = caption
				
				// Only update current caption if this style is still selected
				if selectedStyle == style {
					currentCaption = caption
				}
			} catch {
				Log.analysis.error("Caption generation failed: \(error.localizedDescription)")
				// Fallback to a simple caption
				let fallbackCaption = generateFallbackCaption(for: style)
				generatedCaptions[style] = fallbackCaption
				if selectedStyle == style {
					currentCaption = fallbackCaption
				}
			}
			
			generatingStyle = nil
		}
	}
	
	private func generateFallbackCaption(for style: ShareCardStyle) -> String {
		let emotion = emotionSummary?.emotion ?? "Content"
		let emoji = emotionSummary?.emoji ?? "😸"
		
		switch style {
		case .funny:
			return "\(emoji) Current mood: peak cat energy!"
		case .sweet:
			return "\(emoji) Just being absolutely precious"
		case .sassy:
			return "\(emoji) I woke up like this"
		case .poetic:
			return "In this moment,\nA feline soul reveals\nIts inner \(emotion.lowercased()) \(emoji)"
		case .haiku:
			return "Cat in the moment\nPure \(emotion.lowercased()) radiates here\nNature's perfect art"
		case .educational:
			return "\(emoji) This expression shows a cat in a \(emotion.lowercased()) state"
		case .minimal:
			return "\(emoji)"
		}
	}
	
	func shareCard() {
		isGeneratingCard = true
		
		Task {
			do {
				// Generate the share card image
				let cardImage = try await generateShareCardImage()
				shareImage = cardImage
				showShareSheet = true
			} catch {
				Log.analysis.error("Share card generation failed: \(error.localizedDescription)")
			}
			
			isGeneratingCard = false
		}
	}
	
	private func generateShareCardImage() async throws -> UIImage {
		// Create a SwiftUI view and convert it to UIImage
		let cardView = ShareCardImageView(
			catImageData: catImageData,
			caption: currentCaption ?? "😸",
			style: selectedStyle
		)
		
		let renderer = ImageRenderer(content: cardView)
		renderer.scale = UIScreen.main.scale
		
		guard let image = renderer.uiImage else {
			throw ShareCardError.imageGenerationFailed
		}
		
		return image
	}
}

// MARK: - Share Card Image Generation

struct ShareCardImageView: View {
	let catImageData: Data?
	let caption: String
	let style: ShareCardStyle
	
	var body: some View {
		VStack(spacing: 0) {
			// Cat photo
			if let imageData = catImageData,
			   let uiImage = UIImage(data: imageData) {
				Image(uiImage: uiImage)
					.resizable()
					.scaledToFill()
					.frame(width: 400, height: 300)
					.clipped()
			} else {
				Rectangle()
					.fill(Color.gray.opacity(0.3))
					.frame(width: 400, height: 300)
			}
			
			// Caption section
			VStack(alignment: .leading, spacing: 16) {
				Text(caption)
					.font(.system(.body, design: .rounded))
					.lineLimit(nil)
					.multilineTextAlignment(.leading)
					.foregroundColor(.primary)
				
				Spacer()
				
				HStack {
					Spacer()
					Text("Made with ")
						.font(.caption)
						.foregroundColor(.secondary)
					+ Text("Purrplexed")
						.font(.caption.weight(.semibold))
						.foregroundColor(.accentColor)
				}
			}
			.padding(20)
			.frame(width: 400)
			.frame(minHeight: 140)
			.background(Color(.systemBackground))
		}
		.frame(width: 400, height: 440)
		.background(Color(.systemBackground))
		.clipShape(RoundedRectangle(cornerRadius: 16))
	}
}

enum ShareCardError: Error, LocalizedError {
	case imageGenerationFailed
	
	var errorDescription: String? {
		switch self {
		case .imageGenerationFailed:
			return "Failed to generate share card image"
		}
	}
}
