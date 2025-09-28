//
//  StoryCanvasView.swift
//  Purrplexed
//
//  WYSIWYG story editor canvas rendering StoryDocument.
//

import SwiftUI
import UIKit

struct StoryCanvasView: View {
	@ObservedObject var document: StoryDocument
	@GestureState private var currentDrag: CGSize = .zero
	@GestureState private var currentMagnification: CGFloat = 1.0
	@GestureState private var currentRotation: Angle = .zero
	@State private var gestureBaselines: [UUID: StoryItemBaseline] = [:]
	@State private var activeItemID: UUID?
	@State private var viewportScale: CGFloat = 0.3

	private let minimumZoom: CGFloat = 0.2
	private let maximumZoom: CGFloat = 1.5

	var body: some View {
		GeometryReader { geometry in
			let scale = calculateViewportScale(container: geometry.size)
			ZStack {
				viewport(for: geometry.size, viewportScale: scale)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.background(Color.black.opacity(0.92))
		}
	}

	private func viewport(for containerSize: CGSize, viewportScale: CGFloat) -> some View {
		let canvasSize = document.canvasSize
		let scaledCanvasSize = CGSize(width: canvasSize.width * viewportScale, height: canvasSize.height * viewportScale)
		return VStack {
			canvas(scaledTo: viewportScale)
		}
		.frame(width: scaledCanvasSize.width, height: scaledCanvasSize.height)
	}

	private func canvas(scaledTo scaleFactor: CGFloat) -> some View {
		let baseCanvas = canvasContent()
		let magnification = document.zoomScale * scaleFactor
		return baseCanvas
			.frame(width: document.canvasSize.width, height: document.canvasSize.height)
			.scaleEffect(magnification)
			.offset(document.viewportOffset)
			.background(Color.black.opacity(0.01))
			.clipped()
			.gesture(viewportGestures())
	}

	private func canvasContent() -> some View {
		ZStack {
			if let background = document.backgroundPreview {
				Image(uiImage: background)
					.resizable()
					.scaledToFill()
					.frame(width: document.canvasSize.width, height: document.canvasSize.height)
					.clipped()
			} else {
				Color(.systemGray5)
			}
			ForEach(document.items.sorted(by: { $0.zIndex < $1.zIndex })) { item in
				storyItemView(for: item)
					.zIndex(Double(item.zIndex))
			}
		}
		.contentShape(Rectangle())
		.gesture(
			TapGesture()
				.onEnded {
					document.selectNone()
				}
		)
	}

	@ViewBuilder
	private func storyItemView(for item: StoryItem) -> some View {
		let position = item.position.cgPoint
		let scale = CGFloat(item.scale)
		let rotation = Angle(radians: item.rotation)
		let base = itemContent(for: item)
		return base
			.position(position)
			.scaleEffect(scale)
			.rotationEffect(rotation)
            .onTapGesture {
                document.select(item.id)
                document.endEditingText()
                Haptics.impact(.light)
            }
			.gesture(itemGesture(for: item))
			.overlay(selectionOverlay(for: item).rotationEffect(-rotation))
	}

	@ViewBuilder
	private func itemContent(for item: StoryItem) -> some View {
		switch item.kind {
		case .text:
			textItem(for: item)
		case .emoji:
			emojiItem(for: item)
		case .bubble:
			if let bubble = StoryTheme.bubbleStyle(for: item.bubbleStyleID) {
				bubbleItem(for: item, bubbleStyle: bubble)
			} else {
				textItem(for: item)
			}
		}
	}

	@ViewBuilder
	private func selectionOverlay(for item: StoryItem) -> some View {
		if item.isSelected {
			GeometryReader { proxy in
				let width = proxy.size.width
				let height = proxy.size.height
				ZStack {
					RoundedRectangle(cornerRadius: 12)
						.stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
					HandleView()
						.frame(width: width, height: height)
				}
			}
			.padding(EdgeInsets(top: -28, leading: -28, bottom: -28, trailing: -28))
		}
	}

	@ViewBuilder
	private func textItem(for item: StoryItem) -> some View {
		let fontStyle = StoryTheme.font(for: item.fontID)
		if document.isEditingText == item.id {
			TextKitEditorView(
				text: textBinding(for: item),
				font: fontStyle.uiFont(size: item.fontSize),
				textColor: item.color.uiColor,
				isFirstResponder: editingFocusBinding(for: item)
			)
			.multilineTextAlignment(.center)
			.frame(minWidth: 120, idealWidth: 480)
		} else {
			Text(item.text)
				.font(fontStyle.swiftUIFont(size: item.fontSize))
				.foregroundColor(item.color.swiftUIColor)
				.multilineTextAlignment(.center)
		}
	}

	@ViewBuilder
	private func emojiItem(for item: StoryItem) -> some View {
		EmojiImageCache.image(for: item.text, fontSize: CGFloat(item.fontSize))
			.resizable()
			.frame(width: CGFloat(item.fontSize) * 1.2, height: CGFloat(item.fontSize) * 1.2)
	}

	@ViewBuilder
	private func bubbleItem(for item: StoryItem, bubbleStyle: StoryBubbleStyle) -> some View {
		ZStack {
			SpeechBubbleShape(style: bubbleStyle)
				.fill(bubbleStyle.fillColor.swiftUIColor)
				.overlay(
					SpeechBubbleShape(style: bubbleStyle)
						.stroke(bubbleStyle.strokeColor.swiftUIColor, lineWidth: bubbleStyle.lineWidth)
				)
				.shadow(color: shadowColor(for: item, bubbleStyle: bubbleStyle), radius: shadowRadius(for: item), x: 0, y: 16)
			textItem(for: item)
				.padding(bubbleStyle.padding.edgeInsets)
		}
	}

	private func shadowColor(for item: StoryItem, bubbleStyle: StoryBubbleStyle) -> Color {
		item.isSelected ? bubbleStyle.fillColor.swiftUIColor.opacity(0.4) : bubbleStyle.fillColor.swiftUIColor.opacity(0.2)
	}

	private func shadowRadius(for item: StoryItem) -> CGFloat {
		item.isSelected ? 18 : 10
	}

	private func textBinding(for item: StoryItem) -> Binding<String> {
		Binding(
			get: { document.item(for: item.id)?.text ?? item.text },
			set: { newValue in
				document.update(itemID: item.id) { mutable in
					mutable.text = newValue
				}
			}
		)
	}

	private func editingFocusBinding(for item: StoryItem) -> Binding<Bool> {
		Binding(
			get: { document.isEditingText == item.id },
			set: { newValue in
				if newValue {
					document.beginEditingText(item.id)
				} else {
					document.endEditingText()
				}
			}
		)
	}

	private func itemGesture(for item: StoryItem) -> some Gesture {
		let drag = DragGesture()
			.updating($currentDrag) { value, state, _ in
				state = value.translation
			}
			.onChanged { value in
				document.select(item.id)
				if gestureBaselines[item.id] == nil {
					gestureBaselines[item.id] = StoryItemBaseline(position: item.position, scale: item.scale, rotation: item.rotation)
				}
				guard let baseline = gestureBaselines[item.id] else { return }
				let basePoint = baseline.position.cgPoint
				let newPoint = CGPoint(
					x: basePoint.x + value.translation.width,
					y: basePoint.y + value.translation.height
				)
				document.update(itemID: item.id) { mutable in
					mutable.position = StoryPoint(point: newPoint)
				}
			}
			.onEnded { _ in
				withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
					Haptics.impact(.light)
				}
				gestureBaselines[item.id] = nil
			}

		let magnification = MagnificationGesture()
			.updating($currentMagnification) { value, state, _ in
				state = value
			}
			.onChanged { value in
				document.select(item.id)
				if gestureBaselines[item.id] == nil {
					gestureBaselines[item.id] = StoryItemBaseline(position: item.position, scale: item.scale, rotation: item.rotation)
				}
				guard let baseline = gestureBaselines[item.id] else { return }
				let clamped = max(0.2, min(4.0, baseline.scale * value))
				document.update(itemID: item.id) { mutable in
					mutable.scale = Double(clamped)
				}
			}
			.onEnded { _ in
				withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
					Haptics.impact(.light)
				}
				gestureBaselines[item.id] = nil
			}

		let rotation = RotationGesture()
			.updating($currentRotation) { value, state, _ in
				state = value
			}
			.onChanged { value in
				document.select(item.id)
				if gestureBaselines[item.id] == nil {
					gestureBaselines[item.id] = StoryItemBaseline(position: item.position, scale: item.scale, rotation: item.rotation)
				}
				guard let baseline = gestureBaselines[item.id] else { return }
				document.update(itemID: item.id) { mutable in
					mutable.rotation = baseline.rotation + Double(value.radians)
				}
			}
			.onEnded { _ in
				withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
					Haptics.impact(.light)
				}
				gestureBaselines[item.id] = nil
			}

		return drag.simultaneously(with: magnification).simultaneously(with: rotation)
	}

	private func viewportGestures() -> some Gesture {
		let dragGesture = DragGesture()
			.updating($currentDrag) { value, state, _ in
				state = value.translation
			}
			.onChanged { value in
				document.viewportOffset = CGSize(
					width: value.translation.width,
					height: value.translation.height
				)
			}
			.onEnded { _ in
				withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
					document.viewportOffset = .zero
					Haptics.impact(.light)
				}
			}

		let magnificationGesture = MagnificationGesture()
			.updating($currentMagnification) { value, state, _ in
				state = value
			}
			.onChanged { value in
				let newScale = document.zoomScale * value
				document.zoomScale = min(maximumZoom, max(minimumZoom, newScale))
			}
			.onEnded { _ in
				withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
					Haptics.impact(.light)
				}
			}

		return dragGesture.simultaneously(with: magnificationGesture)
	}

	private func calculateViewportScale(container: CGSize) -> CGFloat {
		let canvasSize = document.canvasSize
		let widthScale = container.width / canvasSize.width
		let heightScale = container.height / canvasSize.height
		return min(widthScale, heightScale)
	}

	private struct BubbleView: View {
		let item: StoryItem
		let bubbleStyle: StoryBubbleStyle

		var body: some View {
			ZStack {
				SpeechBubbleShape(style: bubbleStyle)
					.fill(bubbleStyle.fillColor.swiftUIColor)
					.overlay(
						SpeechBubbleShape(style: bubbleStyle)
							.stroke(bubbleStyle.strokeColor.swiftUIColor, lineWidth: bubbleStyle.lineWidth)
					)
				Text(item.text)
					.font(StoryTheme.font(for: item.fontID).font)
					.foregroundColor(item.color.swiftUIColor)
					.padding(bubbleStyle.padding.edgeInsets)
			}
			.shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 16)
		}

		private var shadowColor: Color {
			item.isSelected ? bubbleStyle.fillColor.swiftUIColor.opacity(0.4) : bubbleStyle.fillColor.swiftUIColor.opacity(0.2)
		}

		private var shadowRadius: CGFloat { item.isSelected ? 18 : 10 }
	}

	private struct SpeechBubbleShape: Shape {
		let style: StoryBubbleStyle

		func path(in rect: CGRect) -> Path {
			var path = Path()
			switch style.tailDirection {
			case .left:
				path.addRoundedRect(in: rect.insetBy(dx: style.tailSize.width, dy: 0), cornerSize: CGSize(width: style.cornerRadius, height: style.cornerRadius))
				path = path.applying(CGAffineTransform(translationX: style.tailSize.width, y: 0))
				let tail = tailPath(rect: rect, direction: .left)
				path.addPath(tail)
			case .right:
				path.addRoundedRect(in: rect.insetBy(dx: style.tailSize.width, dy: 0), cornerSize: CGSize(width: style.cornerRadius, height: style.cornerRadius))
				let tail = tailPath(rect: rect, direction: .right)
				path.addPath(tail)
			case .bottom:
				path.addRoundedRect(in: rect.insetBy(dx: 0, dy: style.tailSize.height), cornerSize: CGSize(width: style.cornerRadius, height: style.cornerRadius))
				path = path.applying(CGAffineTransform(translationX: 0, y: style.tailSize.height / 2))
				let tail = tailPath(rect: rect, direction: .bottom)
				path.addPath(tail)
			}
			return path
		}

		private func tailPath(rect: CGRect, direction: StoryBubbleStyle.TailDirection) -> Path {
			var path = Path()
			let tailWidth = style.tailSize.width
			let tailHeight = style.tailSize.height
			let tailRect = rect.insetBy(dx: tailWidth, dy: tailHeight)
			let midY = tailRect.midY
			let midX = tailRect.midX

			switch direction {
			case .left:
				path.move(to: CGPoint(x: rect.minX, y: midY))
				path.addLine(to: CGPoint(x: rect.minX - tailWidth, y: midY - tailHeight / 2))
				path.addLine(to: CGPoint(x: rect.minX, y: midY - tailHeight))
				path.closeSubpath()
			case .right:
				path.move(to: CGPoint(x: rect.maxX, y: midY))
				path.addLine(to: CGPoint(x: rect.maxX + tailWidth, y: midY - tailHeight / 2))
				path.addLine(to: CGPoint(x: rect.maxX, y: midY - tailHeight))
				path.closeSubpath()
			case .bottom:
				path.move(to: CGPoint(x: midX, y: rect.maxY))
				path.addLine(to: CGPoint(x: midX - tailWidth / 2, y: rect.maxY + tailHeight))
				path.addLine(to: CGPoint(x: midX + tailWidth / 2, y: rect.maxY + tailHeight))
				path.closeSubpath()
			}
			return path
		}
	}
}

private struct HandleView: View {
    private let handleSize: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                handleCircle
                    .position(x: 0, y: 0)
                handleCircle
                    .position(x: proxy.size.width, y: 0)
                handleCircle
                    .position(x: 0, y: proxy.size.height)
                handleCircle
                    .position(x: proxy.size.width, y: proxy.size.height)
                rotationHandle
                    .position(x: proxy.size.width / 2, y: -handleSize * 1.5)
            }
        }
    }

    private var handleCircle: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: handleSize, height: handleSize)
            .shadow(radius: 2)
    }

    private var rotationHandle: some View {
        VStack(spacing: 4) {
            Capsule()
                .fill(Color.accentColor.opacity(0.6))
                .frame(width: 4, height: handleSize * 1.2)
            Circle()
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .background(Circle().fill(Color.white))
                .frame(width: handleSize, height: handleSize)
                .shadow(radius: 2)
        }
    }
}

private struct StoryItemBaseline {
	let position: StoryPoint
	let scale: Double
	let rotation: Double
}

private enum EmojiImageCache {
	private static let cache = NSCache<NSString, UIImage>()

	static func image(for emoji: String, fontSize: CGFloat) -> Image {
		let key = cacheKey(for: emoji, size: fontSize)
		if let cached = cache.object(forKey: key as NSString) {
			return Image(uiImage: cached)
		}
		let rendered = renderEmoji(emoji, size: fontSize)
		cache.setObject(rendered, forKey: key as NSString)
		return Image(uiImage: rendered)
	}

	private static func cacheKey(for emoji: String, size: CGFloat) -> String {
		"\(emoji)_\(Int(size))"
	}

	private static func renderEmoji(_ emoji: String, size: CGFloat) -> UIImage {
		let font = UIFont.systemFont(ofSize: size)
		let attributed = NSAttributedString(string: emoji, attributes: [.font: font])
		let bounds = attributed.boundingRect(with: CGSize(width: size * 2, height: size * 2), options: .usesLineFragmentOrigin, context: nil)
		let format = UIGraphicsImageRendererFormat.default()
		format.scale = 1
		let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)
		return renderer.image { context in
			UIColor.clear.setFill()
			context.fill(CGRect(origin: .zero, size: bounds.size))
			attributed.draw(at: .zero)
		}
	}
}

