//
//  ShareEditorViewModel.swift
//  Purrplexed
//
//  Main state holder for the share editor flow.
//

import Foundation
import SwiftUI
import UIKit

@MainActor
final class ShareEditorViewModel: ObservableObject {
	@Published private(set) var context: ShareEditorContext
	@Published var caption: String
	@Published var selectedCategory: CaptionCategory? = nil
	@Published var selectedChip: String? = nil
	@Published var selectedEmojis: [String] = []
	@Published private(set) var previewImage: UIImage? = nil
	@Published var isLoading: Bool = false
	@Published var showError: Bool = false
	@Published var shareItem: ShareableItem? = nil

	private var cachedRenderedImage: UIImage? = nil
	private var cachedCaption: String = ""
	private var cachedEmojis: [String] = []
	private var renderTask: Task<Void, Never>? = nil
	private var currentShareURL: URL? = nil

	private(set) var bodyLanguageChips: [String] = []
	private(set) var contextualChips: [String] = []
	private(set) var adviceChips: [String] = []
	private(set) var jokeChips: [String] = []

	let emojiChips: [String] = ["😸", "😹", "😻", "😼", "😽", "🙀", "😿", "😾", "🐱", "🐈", "🐈‍⬛"]

	init(context: ShareEditorContext) {
		self.context = context
		self.caption = ShareEditorViewModel.defaultCaption(from: context)
		self.cachedCaption = caption
		loadChips()
		scheduleRender(force: true)
	}

	func selectChip(_ chip: String, category: CaptionCategory) {
		if selectedChip == chip && selectedCategory == category {
			selectedChip = nil
			selectedCategory = nil
			caption = applyEmojis(to: "")
		} else {
			selectedChip = chip
			selectedCategory = category
			caption = applyEmojis(to: chip)
		}
		Haptics.impact(.light)
		scheduleRender(force: true)
	}

	func toggleEmoji(_ emoji: String) {
		if let index = selectedEmojis.firstIndex(of: emoji) {
			selectedEmojis.remove(at: index)
		} else {
			selectedEmojis.append(emoji)
		}
		let base = selectedChip ?? captionWithoutEmojis()
		caption = applyEmojis(to: base)
		Haptics.impact(.light)
		scheduleRender(force: true)
	}

	func updateCaption(_ text: String) {
		let clamped = String(text.prefix(150))
		caption = clamped
		selectedChip = nil
		selectedCategory = nil
		scheduleRender(force: true)
	}

	func prepareAndShare() {
		Task { [weak self] in
			await self?.performShare()
		}
	}

	@MainActor
	private func performShare() async {
		guard !isLoading else { return }
		isLoading = true
		defer { isLoading = false }
		guard let image = await renderPreviewIfNeeded(force: false) else {
			showError = true
			Haptics.error()
			return
		}
		guard let pngData = image.pngData() else {
			showError = true
			return
		}
		cleanupShareArtifacts()
		let tempURL = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString)
			.appendingPathExtension("png")
		do {
			try pngData.write(to: tempURL, options: [.atomic])
			guard FileManager.default.fileExists(atPath: tempURL.path) else {
				throw ShareError.writeFailed
			}
			shareItem = ShareableItem(imageURL: tempURL)
			currentShareURL = tempURL
			Haptics.success()
		} catch {
			showError = true
			Haptics.error()
		}
	}

	func shareSheetDismissed() {
		cleanupShareArtifacts()
	}

	func handleViewDisappear() {
		renderTask?.cancel()
		cleanupShareArtifacts()
	}

	@discardableResult
	private func renderPreviewIfNeeded(force: Bool) async -> UIImage? {
		if !force, cachedRenderedImage != nil, cachedCaption == caption, cachedEmojis == selectedEmojis {
			return cachedRenderedImage
		}
		guard let catImage = await makeCroppedImage() else {
			cachedRenderedImage = nil
			return nil
		}
		let captionToRender = caption.isEmpty ? ShareEditorViewModel.defaultCaption(from: context) : caption
		cachedCaption = captionToRender
		cachedEmojis = selectedEmojis
		let rendered = await ShareCardRenderer.render(catImage: catImage, caption: captionToRender)
		await MainActor.run { [weak self] in
			self?.cachedRenderedImage = rendered
			self?.previewImage = rendered
		}
		return rendered
	}

	private func scheduleRender(force: Bool) {
		renderTask?.cancel()
		renderTask = Task { [weak self] in
			guard let self else { return }
			await self.renderPreviewIfNeeded(force: force)
		}
	}

	private func applyEmojis(to base: String) -> String {
		guard !selectedEmojis.isEmpty else { return String(base.prefix(150)) }
		let emojiString = selectedEmojis.joined(separator: " ")
		let combined = [base, emojiString].filter { !$0.isEmpty }.joined(separator: " ")
		return String(combined.prefix(150))
	}

	private func captionWithoutEmojis() -> String {
		let emojiSet = Set(emojiChips)
		let words = caption
			.split(separator: " ")
			.filter { !emojiSet.contains(String($0)) }
		return words.joined(separator: " ").trimmingCharacters(in: .whitespaces)
	}

	private func makeCroppedImage() async -> UIImage? {
		guard let image = UIImage(data: context.originalImageData) else { return nil }
		if let catResult = context.catDetectionResult,
		   let cropped = ImageUtils.cropToFocus(image: image, boundingBox: catResult.boundingBox, paddingRatio: 0.2) {
			return cropped
		}
		return image
	}

	private func loadChips() {
		if let body = context.bodyLanguageAnalysis {
			bodyLanguageChips = ShareEditorViewModel.extractBodyLanguageChips(from: body)
		}
		if let contextual = context.contextualEmotion {
			contextualChips = ShareEditorViewModel.extractContextualEmotionChips(from: contextual)
		}
		if let advice = context.ownerAdvice {
			adviceChips = ShareEditorViewModel.extractOwnerAdviceChips(from: advice)
		}
		if let jokes = context.catJokes?.jokes {
			jokeChips = jokes.filter { !$0.isEmpty }
		}
	}

	static func defaultCaption(from context: ShareEditorContext) -> String {
		if let summary = context.emotionSummary {
			return "\(summary.emoji) \(summary.emotion)"
		}
		return "Feline feelings decoded"
	}

	static func extractBodyLanguageChips(from analysis: BodyLanguageAnalysis) -> [String] {
		[
			"Ears: \(analysis.ears)",
			"Tail: \(analysis.tail)",
			analysis.overallMood.isEmpty ? nil : analysis.overallMood.capitalized,
			analysis.eyes.isEmpty ? nil : "Eyes show \(analysis.eyes.prefix(30))…",
			analysis.posture.isEmpty ? nil : "Posture: \(analysis.posture.prefix(30))…"
		].compactMap { $0 }
	}

	static func extractContextualEmotionChips(from analysis: ContextualEmotion) -> [String] {
		let combined = (analysis.emotionalMeaning + analysis.contextClues)
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
		return combined.prefix(5).map { String($0.prefix(50)) }
	}

	static func extractOwnerAdviceChips(from advice: OwnerAdvice) -> [String] {
		let combined = (advice.immediateActions + advice.longTermSuggestions)
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
		return combined.prefix(5).map { String($0.prefix(60)) }
	}

	deinit {
		renderTask?.cancel()
	}

	@MainActor
	private func cleanupShareArtifacts() {
		if let url = currentShareURL {
			try? FileManager.default.removeItem(at: url)
		}
		currentShareURL = nil
		shareItem = nil
	}

	enum CaptionCategory: Hashable {
		case bodyLanguage
		case contextual
		case advice
		case jokes
		case emoji
	}

	enum ShareError: Error {
		case writeFailed
	}
}

struct ShareableItem: Identifiable, Equatable {
	let id = UUID()
	let imageURL: URL
}


