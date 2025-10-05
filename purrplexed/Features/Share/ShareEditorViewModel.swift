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
	@Published var selectedAspect: ShareAspectRatio = .square1x1 {
		didSet {
			scheduleRender(force: true)
		}
	}
	@Published var isLoading: Bool = false
	@Published var showError: Bool = false
	@Published var shareItem: ShareableItem? = nil

	private var cachedRenderedImage: UIImage? = nil
	private var cachedCaption: String = ""
	private var cachedEmojis: [String] = []
	private var renderTask: Task<Void, Never>? = nil
	private var currentShareURL: URL? = nil
	private lazy var originalImage: UIImage? = UIImage(data: context.originalImageData)
	private lazy var originalImagePixelSize: CGSize? = {
		guard let cgImage = originalImage?.cgImage else { return nil }
		return CGSize(width: cgImage.width, height: cgImage.height)
	}()

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
		guard let baseImage = originalImage else {
			cachedRenderedImage = nil
			return nil
		}
		let captionToRender = caption.isEmpty ? ShareEditorViewModel.defaultCaption(from: context) : caption
		cachedCaption = captionToRender
		cachedEmojis = selectedEmojis
		let rendered = await ShareCardRenderer.render(
			originalImage: baseImage,
			catDetectionResult: adjustedCatDetectionResult(for: baseImage),
			caption: captionToRender,
			aspect: selectedAspect,
			debug: true
		)
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

	private func adjustedCatDetectionResult(for image: UIImage) -> CatDetectionResult? {
		guard var result = context.catDetectionResult else { return nil }
		guard
			let detectionImageSize = originalImagePixelSize,
			detectionImageSize.width > 0,
			detectionImageSize.height > 0
		else {
			return result
		}
		let targetPixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
		guard targetPixelSize.width > 0, targetPixelSize.height > 0 else { return result }

		if detectionImageSize == result.imageSize {
			return result
		}

		let scaleX = targetPixelSize.width / max(result.imageSize.width, 1)
		let scaleY = targetPixelSize.height / max(result.imageSize.height, 1)
		let transformedBox = CGRect(
			x: result.boundingBox.origin.x * scaleX,
			y: result.boundingBox.origin.y * scaleY,
			width: result.boundingBox.width * scaleX,
			height: result.boundingBox.height * scaleY
		)

		result = CatDetectionResult(
			boundingBox: transformedBox,
			confidence: result.confidence,
			imageSize: targetPixelSize
		)
		Log.share.info("Adjusted detection bounding box from \(String(describing: detectionImageSize)) to \(String(describing: targetPixelSize))")
		return result
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


