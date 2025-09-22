//
//  ShareCardView.swift
//  Purrplexed
//
//  Share card creation with different caption styles and polished design.
//

import SwiftUI
import UIKit

struct ShareCardView: View {
	@ObservedObject var viewModel: ShareCardViewModel
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		NavigationView {
			VStack(spacing: 0) {
				// Share card preview
				ScrollView {
					shareCardPreview
						.padding()
				}
				
				// Style selection chips
				VStack(spacing: DS.Spacing.m) {
					Text("Choose Your Style")
						.font(DS.Typography.titleFont())
						.padding(.top)
					
					LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DS.Spacing.s) {
						ForEach(ShareCardStyle.allCases, id: \.self) { style in
							StyleChip(
								style: style,
								isSelected: viewModel.selectedStyle == style,
								isGenerating: viewModel.generatingStyle == style
							) {
								viewModel.selectStyle(style)
							}
						}
					}
					.padding(.horizontal)
				}
				.padding(.bottom, DS.Spacing.l)
				
				// Action buttons
				HStack(spacing: DS.Spacing.m) {
					Button("Cancel") {
						dismiss()
					}
					.font(DS.Typography.buttonFont())
					.buttonStyle(.bordered)
					
					Button("Share") {
						viewModel.shareCard()
					}
					.font(DS.Typography.buttonFont())
					.buttonStyle(.borderedProminent)
					.disabled(viewModel.isGeneratingCard)
				}
				.padding()
			}
		}
		.navigationTitle("Share Card")
		.navigationBarTitleDisplayMode(.inline)
		.onAppear {
			viewModel.generateInitialCard()
		}
		.sheet(isPresented: $viewModel.showShareSheet) {
			if let shareImage = viewModel.shareImage {
				ShareSheet(items: [shareImage])
			}
		}
	}
	
	private var shareCardPreview: some View {
		VStack(spacing: 0) {
			// Cat photo section
			if let imageData = viewModel.catImageData,
			   let uiImage = UIImage(data: imageData) {
				Image(uiImage: uiImage)
					.resizable()
					.scaledToFill()
					.frame(height: 300)
					.clipped()
			} else {
				Rectangle()
					.fill(Color.gray.opacity(0.3))
					.frame(height: 300)
					.overlay(
						Text("Photo")
							.font(DS.Typography.bodyFont())
							.foregroundColor(.secondary)
					)
			}
			
			// Caption and branding section
			VStack(alignment: .leading, spacing: DS.Spacing.m) {
				if viewModel.isGeneratingCard || viewModel.generatingStyle != nil {
					HStack {
						ProgressView()
							.progressViewStyle(CircularProgressViewStyle(tint: DS.Color.accent))
							.scaleEffect(0.8)
						Text(viewModel.generatingStyle != nil ? 
							"Generating \(viewModel.generatingStyle?.displayName.lowercased() ?? "") caption..." : 
							"Creating share card...")
							.font(DS.Typography.bodyFont())
							.foregroundColor(.secondary)
					}
				} else if let caption = viewModel.currentCaption {
					Text(caption)
						.font(DS.Typography.bodyFont())
						.lineLimit(nil)
						.multilineTextAlignment(.leading)
						.transition(.opacity)
				}
				
				Spacer()
				
				// Subtle branding
				HStack {
					Spacer()
					Text("Made with ")
						.font(.caption)
						.foregroundColor(.secondary)
					+ Text("Purrplexed")
						.font(.caption.weight(.semibold))
						.foregroundColor(DS.Color.accent)
				}
			}
			.padding(DS.Spacing.m)
			.frame(minHeight: 120)
		}
		.frame(width: 350) // Standard social media card width
		.background(DS.Color.background)
		.clipShape(RoundedRectangle(cornerRadius: 16))
		.shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
		.animation(.spring(response: 0.6), value: viewModel.currentCaption)
	}
}

struct StyleChip: View {
	let style: ShareCardStyle
	let isSelected: Bool
	let isGenerating: Bool
	let action: () -> Void
	
	var body: some View {
		Button(action: action) {
			HStack(spacing: 6) {
				Text(style.emoji)
					.font(.title3)
				
				if isGenerating {
					ProgressView()
						.progressViewStyle(CircularProgressViewStyle(tint: isSelected ? .white : DS.Color.accent))
						.scaleEffect(0.6)
				}
				
				Text(style.displayName)
					.font(.subheadline.weight(.medium))
			}
			.padding(.horizontal, DS.Spacing.m)
			.padding(.vertical, DS.Spacing.s)
			.frame(maxWidth: .infinity)
			.background(isSelected ? DS.Color.accent : DS.Color.pillBackground)
			.foregroundColor(isSelected ? .white : .primary)
			.clipShape(Capsule())
		}
		.disabled(isGenerating)
		.animation(.spring(response: 0.4), value: isSelected)
	}
}

enum ShareCardStyle: String, CaseIterable, Sendable {
	case funny = "funny"
	case sweet = "sweet"
	case sassy = "sassy"
	case poetic = "poetic"
	case haiku = "haiku"
	case educational = "educational"
	case minimal = "minimal"
	
	var displayName: String {
		switch self {
		case .funny: return "Funny"
		case .sweet: return "Sweet"
		case .sassy: return "Sassy"
		case .poetic: return "Poetic"
		case .haiku: return "Haiku"
		case .educational: return "Educational"
		case .minimal: return "Minimal"
		}
	}
	
	var emoji: String {
		switch self {
		case .funny: return "😹"
		case .sweet: return "🥺"
		case .sassy: return "😼"
		case .poetic: return "🎭"
		case .haiku: return "🌸"
		case .educational: return "🧠"
		case .minimal: return "✨"
		}
	}
	
	var description: String {
		switch self {
		case .funny: return "Humorous and playful captions that highlight funny cat behaviors"
		case .sweet: return "Heartwarming and adorable captions that capture tender moments"
		case .sassy: return "Bold and confident captions with attitude and personality"
		case .poetic: return "Artistic and expressive captions with beautiful language"
		case .haiku: return "Traditional Japanese poetry format capturing the moment"
		case .educational: return "Informative captions explaining cat behavior and psychology"
		case .minimal: return "Clean, simple captions that let the photo speak"
		}
	}
}

private struct ShareSheet: UIViewControllerRepresentable {
	let items: [Any]
	
	func makeUIViewController(context: Context) -> UIActivityViewController {
		UIActivityViewController(activityItems: items, applicationActivities: nil)
	}
	
	func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
	let mockViewModel = ShareCardViewModel(
		catImageData: nil,
		emotionSummary: EmotionSummary(
			emotion: "Content",
			intensity: "Moderate",
			description: "The cat appears relaxed and comfortable",
			emoji: "😌",
			moodType: "happy",
			warningMessage: nil
		),
		bodyLanguageAnalysis: nil,
		contextualEmotion: nil,
		ownerAdvice: nil,
		catJokes: nil,
		captionService: MockCaptionGenerationService()
	)
	
	return ShareCardView(viewModel: mockViewModel)
}
