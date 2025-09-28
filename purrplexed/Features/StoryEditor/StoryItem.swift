//
//  StoryItem.swift
//  Purrplexed
//
//  Model types used by the story editor canvas.
//

import SwiftUI
import UIKit

enum StoryItemKind: String, Codable {
	case text
	case emoji
	case bubble
}

struct StoryColor: Codable, Hashable {
	let red: Double
	let green: Double
	let blue: Double
	let alpha: Double

	init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
		self.red = red
		self.green = green
		self.blue = blue
		self.alpha = alpha
	}

	init(color: Color) {
		let ui = UIColor(color)
		var r: CGFloat = 0
		var g: CGFloat = 0
		var b: CGFloat = 0
		var a: CGFloat = 0
		ui.getRed(&r, green: &g, blue: &b, alpha: &a)
		self.init(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
	}

	var swiftUIColor: Color {
		Color(red: red, green: green, blue: blue, opacity: alpha)
	}

	var uiColor: UIColor {
		UIColor(red: red, green: green, blue: blue, alpha: alpha)
	}
}

struct StoryPoint: Codable, Hashable {
	var x: Double
	var y: Double

	init(x: Double, y: Double) {
		self.x = x
		self.y = y
	}

	init(point: CGPoint) {
		self.init(x: Double(point.x), y: Double(point.y))
	}

	var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

struct StoryBubbleStyle: Codable, Hashable, Identifiable {
	struct Padding: Codable, Hashable {
		let top: Double
		let leading: Double
		let bottom: Double
		let trailing: Double

		init(top: Double, leading: Double, bottom: Double, trailing: Double) {
			self.top = top
			self.leading = leading
			self.bottom = bottom
			self.trailing = trailing
		}

		var edgeInsets: EdgeInsets {
			EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
		}
	}

	enum TailDirection: String, Codable {
		case left
		case right
		case bottom
	}

	let id: String
	let displayName: String
	let fillColor: StoryColor
	let strokeColor: StoryColor
	let lineWidth: Double
	let cornerRadius: Double
	let tailDirection: TailDirection
	let tailSize: CGSize
	let padding: Padding

	init(
		id: String,
		displayName: String,
		fillColor: StoryColor,
		strokeColor: StoryColor,
		lineWidth: Double,
		cornerRadius: Double,
		tailDirection: TailDirection,
		tailSize: CGSize = CGSize(width: 40, height: 60),
		padding: EdgeInsets = EdgeInsets(top: 32, leading: 28, bottom: 32, trailing: 28)
	) {
		self.id = id
		self.displayName = displayName
		self.fillColor = fillColor
		self.strokeColor = strokeColor
		self.lineWidth = lineWidth
		self.cornerRadius = cornerRadius
		self.tailDirection = tailDirection
		self.tailSize = tailSize
		self.padding = Padding(
			top: padding.top,
			leading: padding.leading,
			bottom: padding.bottom,
			trailing: padding.trailing
		)
	}
}

struct StoryFontStyle: Codable, Hashable, Identifiable {
	let id: String
	let displayName: String
	let fontName: String
	let fallbackName: String
	let defaultSize: Double

	init(id: String, displayName: String, fontName: String, fallbackName: String = "", defaultSize: Double) {
		self.id = id
		self.displayName = displayName
		self.fontName = fontName
		self.fallbackName = fallbackName
		self.defaultSize = defaultSize
	}

	var font: Font { swiftUIFont(size: defaultSize) }

	var uiFont: UIFont { uiFont(size: defaultSize) }

	func swiftUIFont(size: Double) -> Font {
		if UIFont(name: fontName, size: size) != nil {
			return Font.custom(fontName, size: size)
		}
		if !fallbackName.isEmpty, UIFont(name: fallbackName, size: size) != nil {
			return Font.custom(fallbackName, size: size)
		}
		return .system(size: size, weight: .semibold, design: .rounded)
	}

	func uiFont(size: Double) -> UIFont {
		if let font = UIFont(name: fontName, size: size) {
			return font
		}
		if !fallbackName.isEmpty, let font = UIFont(name: fallbackName, size: size) {
			return font
		}
		return UIFont.systemFont(ofSize: size, weight: .semibold)
	}
}

struct StoryItem: Identifiable, Codable, Hashable {
	var id: UUID
	var kind: StoryItemKind
	var text: String
	var fontID: String
	var fontSize: Double
	var color: StoryColor
	var bubbleStyleID: String?
	var position: StoryPoint
	var scale: Double
	var rotation: Double
	var zIndex: Int
	var isSelected: Bool

	init(
		id: UUID = UUID(),
		kind: StoryItemKind,
		text: String,
		fontID: String,
		fontSize: Double,
		color: StoryColor,
		bubbleStyleID: String? = nil,
		position: StoryPoint,
		scale: Double = 1.0,
		rotation: Double = 0,
		zIndex: Int,
		isSelected: Bool = false
	) {
		self.id = id
		self.kind = kind
		self.text = text
		self.fontID = fontID
		self.fontSize = fontSize
		self.color = color
		self.bubbleStyleID = bubbleStyleID
		self.position = position
		self.scale = scale
		self.rotation = rotation
		self.zIndex = zIndex
		self.isSelected = isSelected
	}
}

