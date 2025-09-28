//
//  StoryDocument.swift
//  Purrplexed
//
//  Single source of truth for story editing canvas.
//

import SwiftUI
import Combine

@MainActor
final class StoryDocument: ObservableObject, Identifiable {
	struct Snapshot: Codable, Equatable {
		var backgroundImageData: Data?
		var items: [StoryItem]
	}

	let id: UUID
	let canvasSize: CGSize

	@Published var backgroundPreview: UIImage?
	@Published private(set) var backgroundImage: UIImage?
	@Published private(set) var backgroundImageOriginal: UIImage?
	@Published private(set) var items: [StoryItem]
	@Published var zoomScale: CGFloat = 1.0
	@Published var viewportOffset: CGSize = .zero
	@Published var isEditingText: UUID?

	private(set) var snapshotHistory: [Snapshot] = []
	private(set) var redoStack: [Snapshot] = []

	init(id: UUID = UUID(), backgroundImage: UIImage? = nil, items: [StoryItem] = []) {
		self.id = id
		self.canvasSize = StoryTheme.canvasSize
		self.items = items
		self.backgroundImageOriginal = backgroundImage
		self.backgroundImage = backgroundImage.map { ImageUtils.resizeToFill(image: $0, targetSize: StoryTheme.canvasSize) }
		self.backgroundPreview = self.backgroundImage
		storeSnapshot()
	}

	convenience init(snapshot: Snapshot) {
		let image = snapshot.backgroundImageData.flatMap { UIImage(data: $0) }
		self.init(backgroundImage: image, items: snapshot.items)
	}

	func setBackgroundImage(_ image: UIImage?) {
		backgroundImageOriginal = image
		backgroundImage = image.map { ImageUtils.resizeToFill(image: $0, targetSize: StoryTheme.canvasSize) }
		backgroundPreview = backgroundImage
		storeSnapshot()
	}

	@discardableResult
	func addItem(kind: StoryItemKind, text: String) -> UUID {
		let font = StoryTheme.fonts[0]
		let newID = UUID()
		let defaultPosition = StoryPoint(
			x: Double(canvasSize.width / 2),
			y: Double(canvasSize.height / 2)
		)
		let color = StoryColor(color: .white)
		let bubbleStyleID = kind == .bubble ? StoryTheme.bubbles[0].id : nil
		let item = StoryItem(
			id: newID,
			kind: kind,
			text: text,
			fontID: font.id,
			fontSize: font.defaultSize,
			color: color,
			bubbleStyleID: bubbleStyleID,
			position: defaultPosition,
			scale: 1.0,
			rotation: 0,
			zIndex: (items.map { $0.zIndex }.max() ?? 0) + 1,
			isSelected: true
		)
		selectNone()
		items.append(item)
		storeSnapshot()
		return newID
	}

	func update(itemID: UUID, mutation: (inout StoryItem) -> Void) {
		guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
		mutation(&items[index])
		storeSnapshot()
	}

	func select(_ id: UUID?) {
		items = items.map { item in
			var copy = item
			copy.isSelected = item.id == id
			return copy
		}
		isEditingText = id
	}

	func selectNone() {
		items = items.map { item in
			var copy = item
			copy.isSelected = false
			return copy
		}
		isEditingText = nil
	}

	func beginEditingText(_ id: UUID) {
		select(id)
		isEditingText = id
	}

	func endEditingText() {
		isEditingText = nil
	}

	func updateSelectedItems(_ mutation: (inout StoryItem) -> Void) {
		var mutated = false
		for index in items.indices where items[index].isSelected {
			mutation(&items[index])
			mutated = true
		}
		if mutated { storeSnapshot() }
	}

	func item(for id: UUID) -> StoryItem? {
		items.first(where: { $0.id == id })
	}

	func set(_ item: StoryItem, at index: Int) {
		if items.indices.contains(index) {
			items[index] = item
		} else {
			items.append(item)
		}
		storeSnapshot()
	}

	func moveToFront(_ id: UUID) {
		guard let index = items.firstIndex(where: { $0.id == id }) else { return }
		let maxIndex = (items.map { $0.zIndex }.max() ?? 0) + 1
		items[index].zIndex = maxIndex
		storeSnapshot()
	}

	func deleteSelected() {
		let originalCount = items.count
		items.removeAll { $0.isSelected }
		if items.count < originalCount {
			storeSnapshot()
		}
		isEditingText = nil
	}

	func undo() {
		guard snapshotHistory.count > 1 else { return }
		let current = snapshotHistory.removeLast()
		redoStack.append(current)
		restoreSnapshot(snapshotHistory.last)
	}

	func redo() {
		guard let snapshot = redoStack.popLast() else { return }
		restoreSnapshot(snapshot)
		snapshotHistory.append(snapshot)
	}

	func snapshot() -> Snapshot {
		Snapshot(backgroundImageData: backgroundImage.flatMap { $0.pngData() }, items: items)
	}

	private func storeSnapshot() {
		redoStack.removeAll()
		let snapshot = snapshot()
		if snapshotHistory.last != snapshot {
			snapshotHistory.append(snapshot)
		}
	}

	private func restoreSnapshot(_ snapshot: Snapshot?) {
		guard let snapshot else { return }
		items = snapshot.items
		if let data = snapshot.backgroundImageData, let image = UIImage(data: data) {
			backgroundImage = image
			backgroundPreview = image
		} else {
			backgroundImage = nil
			backgroundImageOriginal = nil
			backgroundPreview = nil
		}
	}
}

