//
//  StoryEditorView.swift
//  Purrplexed
//
//  Primary interface for composing stories.
//

import SwiftUI

struct StoryEditorView: View {
	@StateObject private var document: StoryDocument
	private let exportManager: ExportManager

	@State private var isExporting = false
	@State private var showingImagePicker = false
	@State private var exportedURL: URL?
	@State private var selectedFontID: String
	@State private var selectedBubbleID: String
	@State private var isShowingFontPicker = false
	@State private var isShowingBubblePicker = false

	init(document: StoryDocument, exportManager: ExportManager = ExportManager()) {
		_document = StateObject(wrappedValue: document)
		_selectedFontID = State(initialValue: StoryTheme.font(for: document.items.first?.fontID ?? StoryTheme.fonts.first?.id ?? "rounded").id)
		_selectedBubbleID = State(initialValue: document.items.first?.bubbleStyleID ?? StoryTheme.bubbles.first?.id ?? "daydream")
		self.exportManager = exportManager
	}

	init(initialImage: UIImage? = nil, presetItems: [StoryItem] = [], exportManager: ExportManager = ExportManager()) {
		let doc = StoryDocument(backgroundImage: initialImage, items: presetItems)
		_document = StateObject(wrappedValue: doc)
		_selectedFontID = State(initialValue: StoryTheme.fonts.first?.id ?? "rounded")
		_selectedBubbleID = State(initialValue: StoryTheme.bubbles.first?.id ?? "daydream")
		self.exportManager = exportManager
	}

	var body: some View {
		NavigationStack {
			VStack(spacing: 0) {
				canvas
				controls
			}
			.background(Color.black.opacity(0.92))
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					Button(action: { showingImagePicker = true }) {
						Label("Replace Background", systemImage: "photo.on.rectangle")
					}
				}
				ToolbarItemGroup(placement: .navigationBarTrailing) {
					Button(action: exportStory) {
						Label("Export", systemImage: "square.and.arrow.down")
					}
					.disabled(isExporting)
				}
			}
			.sheet(isPresented: $showingImagePicker) { imagePicker }
			.onDisappear { cleanExportedURL() }
		}
	}

	private var canvas: some View {
		StoryCanvasView(document: document)
			.frame(maxWidth: .infinity)
			.padding(.vertical, 16)
	}

	private var controls: some View {
		VStack(spacing: 16) {
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 12) {
					ForEach(StoryTheme.fonts) { font in
						Button {
							selectFont(font)
						} label: {
							Text(font.displayName)
								.font(font.font)
								.padding(.horizontal, 12)
								.padding(.vertical, 8)
								.background(selectedFontID == font.id ? Color.accentColor.opacity(0.2) : Color.clear)
								.clipShape(Capsule())
						}
					}
				}
				.padding(.horizontal)
			}
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 12) {
					ForEach(StoryTheme.bubbles) { bubble in
						Button {
							selectBubble(bubble)
						} label: {
							Text(bubble.displayName)
								.padding(.horizontal, 12)
								.padding(.vertical, 8)
								.background(selectedBubbleID == bubble.id ? Color.accentColor.opacity(0.2) : Color.clear)
								.clipShape(Capsule())
						}
					}
				}
				.padding(.horizontal)
			}
		}
		.padding(.bottom)
	}

	private var gestureHandles: some View {
		GeometryReader { geometry in
			Color.clear
		}
	}

	private func selectFont(_ font: StoryFontStyle) {
		selectedFontID = font.id
		document.updateSelectedItems { mutable in
			mutable.fontID = font.id
			mutable.fontSize = font.defaultSize
		}
	}

	private func selectBubble(_ bubble: StoryBubbleStyle) {
		selectedBubbleID = bubble.id
		document.updateSelectedItems { mutable in
			mutable.bubbleStyleID = bubble.id
		}
	}

	private func addTextItem() {
		let id = document.addItem(kind: .text, text: "New Caption")
		document.select(id)
		selectedFontID = document.item(for: id)?.fontID ?? selectedFontID
	}

	private func addEmojiItem() {
		let id = document.addItem(kind: .emoji, text: "😺")
		document.select(id)
	}

	private func addBubbleItem() {
		let id = document.addItem(kind: .bubble, text: "I am majestic")
		document.select(id)
		document.update(itemID: id) { mutable in
			mutable.bubbleStyleID = selectedBubbleID
		}
	}

	private func exportStory() {
		Task {
			guard !isExporting else { return }
			isExporting = true
			do {
				let url = try await exportManager.export(document: document)
				exportedURL = url
				Haptics.success()
			} catch {
				Haptics.error()
			}
			isExporting = false
		}
	}

	private var imagePicker: some View {
		PhotoLibraryPicker { image in
			guard let image else { return }
			DispatchQueue.global(qos: .userInitiated).async {
				let scaled = ImageUtils.resizeToFill(image: image, targetSize: StoryTheme.canvasSize)
				DispatchQueue.main.async {
					document.setBackgroundImage(scaled)
				}
			}
		}
	}

	private func cleanExportedURL() {
		if let url = exportedURL {
			try? FileManager.default.removeItem(at: url)
			exportedURL = nil
		}
	}
}

