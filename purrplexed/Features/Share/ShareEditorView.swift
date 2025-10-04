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
				let analysisFrameHeight: CGFloat = 336
				let referenceAspect: CGFloat = proxy.size.width > 0 ? proxy.size.width / analysisFrameHeight : 1
				let availableWidth = proxy.size.width
				let maxPreviewHeight = proxy.size.height * 0.65
				let computedHeight = min(availableWidth / referenceAspect, maxPreviewHeight)
				let previewHeight = computedHeight
				VStack(spacing: 0) {
					previewSection
						.frame(height: previewHeight)
					Divider()
					captionEditor
					Spacer()
					Divider()
					shareSection
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.background(DS.Color.background)
			}
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

	private var previewSection: some View {
		ZStack {
			if let image = viewModel.previewImage {
				Image(uiImage: image)
					.resizable()
					.scaledToFit()
					.cornerRadius(24)
					.shadow(color: Color.black.opacity(0.1), radius: 16, x: 0, y: 8)
			} else if viewModel.isLoading {
				ProgressView()
					.progressViewStyle(.circular)
			} else {
				Text("Preparing preview…")
					.font(DS.Typography.bodyFont())
					.foregroundColor(.secondary)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.padding(.bottom, DS.Spacing.m)
	}

	private var captionEditor: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: DS.Spacing.m) {
				captionField
				if !viewModel.bodyLanguageChips.isEmpty {
					chipSection(title: "Body Language", chips: viewModel.bodyLanguageChips, category: .bodyLanguage)
				}
				if !viewModel.contextualChips.isEmpty {
					chipSection(title: "Contextual Analysis", chips: viewModel.contextualChips, category: .contextual)
				}
				if !viewModel.adviceChips.isEmpty {
					chipSection(title: "Owner Advice", chips: viewModel.adviceChips, category: .advice)
				}
				if !viewModel.jokeChips.isEmpty {
					chipSection(title: "Cat Jokes", chips: viewModel.jokeChips, category: .jokes)
				}
				chipSection(title: "Emoji", chips: viewModel.emojiChips, category: .emoji)
			}
			.padding()
		}
		.frame(maxWidth: .infinity)
	}

	private var captionField: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Caption")
				.font(.caption)
				.foregroundColor(.secondary)
			TextEditor(text: Binding(
				get: { viewModel.caption },
				set: { viewModel.updateCaption($0) }
			))
				.font(DS.Typography.bodyFont())
				.frame(minHeight: 80, maxHeight: 120)
				.overlay(
					RoundedRectangle(cornerRadius: 12)
						.stroke(Color.secondary.opacity(0.2), lineWidth: 1)
				)
			Text("\(viewModel.caption.count)/150 characters")
				.font(.caption)
				.foregroundColor(.secondary)
		}
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

