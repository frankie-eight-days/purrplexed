//
//  ShareEditorView.swift
//  Purrplexed
//
//  Main UI for composing and sharing viral cat cards.
//

import SwiftUI
import UIKit

struct ShareEditorView: View {
	@ObservedObject var viewModel: ShareEditorViewModel
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			GeometryReader { proxy in
				let selectedAspect = viewModel.selectedAspect
				let availableWidth = proxy.size.width
				let maxPreviewHeight = proxy.size.height * 0.65
				let desiredHeight = availableWidth > 0 ? availableWidth * selectedAspect.aspect : 0
				let previewHeight = max(0, min(desiredHeight, maxPreviewHeight))
				VStack(spacing: 0) {
					previewSection(aspectRatio: selectedAspect)
						.frame(height: previewHeight, alignment: .top)
						.padding(.bottom, DS.Spacing.s)
					Divider()
					captionEditor
					Spacer()
					Divider()
					shareSection
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
				.background(DS.Color.background)
			}
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button("Close") { dismiss() }
						.foregroundColor(.primary)
				}
				ToolbarItem(placement: .principal) {
					Text("Share Card")
						.font(DS.Typography.titleFont())
				}
		}
			.alert("Unable to Share", isPresented: $viewModel.showError, actions: {
				Button("OK", role: .cancel) {}
			}, message: {
				Text("We couldn’t prepare your share image. Please try again.")
			})
	.sheet(item: $viewModel.shareItem, onDismiss: {
		viewModel.shareSheetDismissed()
	}) { item in
				ActivityViewController(activityItems: [item.imageURL])
			}
		.onDisappear {
			viewModel.handleViewDisappear()
		}
		}
	}

	private func previewSection(aspectRatio: ShareAspectRatio) -> some View {
		Group {
			if let image = viewModel.previewImage {
				Image(uiImage: image)
					.resizable()
					.aspectRatio(aspectRatio.aspect, contentMode: .fit)
					.shadow(color: Color.black.opacity(0.1), radius: 16, x: 0, y: 8)
			} else {
				// Maintain consistent aspect ratio for loading/placeholder states
				Color.clear
					.aspectRatio(aspectRatio.aspect, contentMode: .fit)
					.overlay {
						if viewModel.isLoading {
							ProgressView()
								.progressViewStyle(.circular)
						} else {
							Text("Preparing preview…")
								.font(DS.Typography.bodyFont())
								.foregroundColor(.secondary)
						}
					}
			}
		}
		.frame(maxWidth: .infinity)
	}

	private var captionEditor: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: DS.Spacing.m) {
				if !viewModel.jokeChips.isEmpty {
					chipSection(title: "Cat Jokes", chips: viewModel.jokeChips, category: .jokes)
				}
				if !viewModel.bodyLanguageChips.isEmpty {
					chipSection(title: "Body Language", chips: viewModel.bodyLanguageChips, category: .bodyLanguage)
				}
				if !viewModel.contextualChips.isEmpty {
					chipSection(title: "Contextual Analysis", chips: viewModel.contextualChips, category: .contextual)
				}
				if !viewModel.adviceChips.isEmpty {
					chipSection(title: "Owner Advice", chips: viewModel.adviceChips, category: .advice)
				}
				chipSection(title: "Emoji", chips: viewModel.emojiChips, category: .emoji)
			}
			.padding()
		}
		.frame(maxWidth: .infinity)
	}


	private func chipSection(title: String, chips: [String], category: ShareEditorViewModel.CaptionCategory) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(title)
				.font(.caption)
				.foregroundColor(.secondary)
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 10) {
					ForEach(chips, id: \.self) { chip in
						ChipView(
							title: chip,
							type: category,
							isSelected: isChipSelected(chip, category: category),
							action: { handleChipTap(chip, category: category) }
						)
					}
				}
			}
		}
	}

	private func isChipSelected(_ chip: String, category: ShareEditorViewModel.CaptionCategory) -> Bool {
		switch category {
		case .emoji:
			return viewModel.selectedEmojis.contains(chip)
		default:
			return viewModel.selectedChip == chip && viewModel.selectedCategory == category
		}
	}

	private func handleChipTap(_ chip: String, category: ShareEditorViewModel.CaptionCategory) {
		switch category {
		case .emoji:
			viewModel.toggleEmoji(chip)
		default:
			viewModel.selectChip(chip, category: category)
		}
	}

	private var shareSection: some View {
		VStack(spacing: 12) {
			Button {
				viewModel.prepareAndShare()
			} label: {
				HStack {
					if viewModel.isLoading {
						ProgressView()
							.progressViewStyle(CircularProgressViewStyle(tint: .white))
					} else {
						Image(systemName: "square.and.arrow.up")
					}
					Text(viewModel.isLoading ? "Preparing…" : "Share Now")
				}
				.font(DS.Typography.buttonFont())
				.foregroundColor(.white)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 14)
				.background(DS.Color.accent)
				.clipShape(RoundedRectangle(cornerRadius: 14))
			}
			.buttonStyle(.plain)
			.disabled(viewModel.isLoading)
			.padding(.horizontal)
		}
		.padding(.top, DS.Spacing.m)
	}
}

private struct ChipView: View {
	let title: String
	let type: ShareEditorViewModel.CaptionCategory
	let isSelected: Bool
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			Text(title)
				.font(.callout)
				.fontWeight(.medium)
				.padding(.horizontal, 14)
				.padding(.vertical, 8)
				.background(isSelected ? DS.Color.accent.opacity(0.25) : Color.gray.opacity(0.12))
				.foregroundColor(isSelected ? DS.Color.accent : .primary)
				.clipShape(Capsule())
		}
		.buttonStyle(.plain)
		.accessibilityLabel("Caption option \(title)")
	}
}

struct ActivityViewController: UIViewControllerRepresentable {
	let activityItems: [Any]

	func makeUIViewController(context: Context) -> UIActivityViewController {
		UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
	}

	func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview("Share Editor") {
	let context = ShareEditorContext(
		originalImageData: Data(),
		catDetectionResult: nil,
		emotionSummary: nil,
		bodyLanguageAnalysis: nil,
		contextualEmotion: nil,
		ownerAdvice: nil,
		catJokes: nil
	)
	return ShareEditorView(viewModel: ShareEditorViewModel(context: context))
}

