//
//  ShareCardRenderer.swift
//  Purrplexed
//
//  Pure UIKit renderer that produces the final shareable image.
//

import UIKit

enum ShareCardRenderer {
	static func render(
		originalImage: UIImage,
		catDetectionResult: CatDetectionResult?,
		caption: String,
		brandingText: String = "Purrplexed 🐱",
		debug: Bool = false
	) async -> UIImage? {
		await Task.detached(priority: .userInitiated) {
			let targetSize = CGSize(width: 1080, height: 1350)
			let borderWidth: CGFloat = 15
			let captionHeight: CGFloat = 150
			let brandingHeight: CGFloat = 72
			let cornerRadius: CGFloat = 32
			let format = UIGraphicsImageRendererFormat.default()
			format.scale = 2.0
			let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
			return renderer.image { context in
				let ctx = context.cgContext
				ctx.setFillColor(UIColor.white.cgColor)
				ctx.fill(CGRect(origin: .zero, size: targetSize))
				let frameRect = CGRect(origin: .zero, size: targetSize)
				let roundedPath = UIBezierPath(roundedRect: frameRect, cornerRadius: cornerRadius)
				ctx.addPath(roundedPath.cgPath)
				ctx.clip()
				if let gradient = CGGradient(
					colorsSpace: CGColorSpaceCreateDeviceRGB(),
					colors: [UIColor.white.cgColor, UIColor(white: 0.97, alpha: 1).cgColor] as CFArray,
					locations: [0, 1]
				) {
					ctx.drawLinearGradient(
						gradient,
						start: CGPoint(x: 0, y: 0),
						end: CGPoint(x: 0, y: targetSize.height),
						options: []
					)
				}
				let squareSide = targetSize.width - 2 * borderWidth
				let imageArea = CGRect(
					x: borderWidth,
					y: borderWidth,
					width: squareSide,
					height: squareSide
				)
				let innerRadius: CGFloat = 24
				let imagePath = UIBezierPath(roundedRect: imageArea, cornerRadius: innerRadius)
				ctx.saveGState()
				ctx.addPath(imagePath.cgPath)
				ctx.clip()
				let focusTransform = CatFocusTransformCalculator.calculate(
					image: originalImage,
					containerSize: imageArea.size,
					catDetectionResult: catDetectionResult
				)
				if debug {
					Log.share.info("Share transform scale=\(focusTransform.extraScale, privacy: .public) offset=\(focusTransform.offset.debugDescription, privacy: .public)")
				}
				let drawingRect = focusTransform.drawingRect(for: originalImage.size)
				let adjustedRect = CGRect(
					x: imageArea.origin.x + drawingRect.origin.x,
					y: imageArea.origin.y + drawingRect.origin.y,
					width: drawingRect.size.width,
					height: drawingRect.size.height
				)
				originalImage.draw(in: adjustedRect)
				ctx.restoreGState()
			let captionArea = CGRect(
				x: borderWidth + 20,
				y: imageArea.maxY + 22,
				width: targetSize.width - 2 * borderWidth - 40,
				height: captionHeight
			)
			let paragraph = NSMutableParagraphStyle()
			paragraph.alignment = .center
			paragraph.lineBreakMode = .byWordWrapping
			let captionBackgroundRect = captionArea.insetBy(dx: -18, dy: -14)
			let captionBackgroundPath = UIBezierPath(roundedRect: captionBackgroundRect, cornerRadius: 28)
			ctx.saveGState()
			ctx.addPath(captionBackgroundPath.cgPath)
			ctx.clip()
			let gradientColors = [
				UIColor(white: 1.0, alpha: 0.82).cgColor,
				UIColor(white: 1.0, alpha: 0.45).cgColor
			] as CFArray
			if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors, locations: [0, 1]) {
				ctx.drawLinearGradient(
					gradient,
					start: CGPoint(x: captionBackgroundRect.minX, y: captionBackgroundRect.minY),
					end: CGPoint(x: captionBackgroundRect.minX, y: captionBackgroundRect.maxY),
					options: []
				)
			} else {
				ctx.setFillColor(UIColor(white: 1.0, alpha: 0.6).cgColor)
				ctx.fill(captionBackgroundRect)
			}
			ctx.restoreGState()
			let taglineText = "Purrplexed: The Cat Translator"
			let taglineHeight: CGFloat = 34
			let taglineSpacing: CGFloat = 6
			let captionBodyHeight = max(0, captionArea.height - taglineHeight - taglineSpacing)
			let captionBodyRect = CGRect(
				x: captionArea.minX,
				y: captionArea.minY,
				width: captionArea.width,
				height: captionBodyHeight
			)
			let taglineRect = CGRect(
				x: captionArea.minX,
				y: captionArea.minY + captionBodyHeight + taglineSpacing,
				width: captionArea.width,
				height: taglineHeight
			)
			let clampedCaption = String(caption.trimmingCharacters(in: .whitespacesAndNewlines).prefix(150))
			if captionBodyRect.height > 0 {
				let captionFont = fittingFont(
					for: clampedCaption,
					in: captionBodyRect,
					paragraphStyle: paragraph,
					maxFontSize: 58,
					minFontSize: 26, // Adjust this lower if we need to squeeze in even longer captions later.
					weight: .semibold,
					design: .rounded
				)
				let captionAttributes: [NSAttributedString.Key: Any] = [
					.font: captionFont,
					.foregroundColor: UIColor.black,
					.paragraphStyle: paragraph
				]
				clampedCaption.draw(in: captionBodyRect, withAttributes: captionAttributes)
			}
			let taglineParagraph = NSMutableParagraphStyle()
			taglineParagraph.alignment = .center
			taglineParagraph.lineBreakMode = .byTruncatingTail
			let taglineAttributes: [NSAttributedString.Key: Any] = [
				.font: roundedFont(ofSize: 24, weight: .medium),
				.foregroundColor: UIColor(white: 0.2, alpha: 0.8),
				.paragraphStyle: taglineParagraph
			]
			taglineText.draw(in: taglineRect, withAttributes: taglineAttributes)
			let brandingArea = CGRect(
				x: borderWidth,
				y: targetSize.height - borderWidth - brandingHeight,
				width: targetSize.width - 2 * borderWidth,
				height: brandingHeight
			)
			let footerPath = UIBezierPath(roundedRect: brandingArea, cornerRadius: 24)
			ctx.saveGState()
			ctx.addPath(footerPath.cgPath)
			let footerGradientColors = [
				UIColor(red: 0.93, green: 0.89, blue: 1.0, alpha: 0.95).cgColor,
				UIColor(red: 0.97, green: 0.94, blue: 1.0, alpha: 0.95).cgColor
			] as CFArray
			if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: footerGradientColors, locations: [0, 1]) {
				ctx.drawLinearGradient(
					gradient,
					start: CGPoint(x: brandingArea.minX, y: brandingArea.minY),
					end: CGPoint(x: brandingArea.minX, y: brandingArea.maxY),
					options: []
				)
			} else {
				ctx.setFillColor(UIColor(red: 0.96, green: 0.93, blue: 1.0, alpha: 0.9).cgColor)
				ctx.fillPath()
			}
			ctx.restoreGState()
			if let appIcon = brandingIcon() {
				let iconSize = CGSize(width: 48, height: 48)
				let iconRect = CGRect(
					x: brandingArea.minX + 24,
					y: brandingArea.midY - iconSize.height / 2,
					width: iconSize.width,
					height: iconSize.height
				)
				appIcon.draw(in: iconRect, blendMode: .normal, alpha: 0.8)
			}
			let brandingParagraph = NSMutableParagraphStyle()
			brandingParagraph.alignment = .left
			brandingParagraph.lineBreakMode = .byTruncatingTail
			let brandingAttributes: [NSAttributedString.Key: Any] = [
				.font: roundedFont(ofSize: 30, weight: .semibold),
				.foregroundColor: UIColor(red: 0.21, green: 0.17, blue: 0.33, alpha: 1),
				.paragraphStyle: brandingParagraph
			]
			let brandingTextRect = CGRect(
				x: brandingArea.minX + 96,
				y: brandingArea.minY + 12,
				width: brandingArea.width - 120,
				height: brandingArea.height / 2 - 6
			)
			brandingText.draw(in: brandingTextRect, withAttributes: brandingAttributes)
			let footerTaglineAttributes: [NSAttributedString.Key: Any] = [
				.font: roundedFont(ofSize: 22, weight: .medium),
				.foregroundColor: UIColor(red: 0.37, green: 0.31, blue: 0.52, alpha: 1),
				.paragraphStyle: brandingParagraph
			]
			let footerTaglineRect = CGRect(
				x: brandingTextRect.minX,
				y: brandingArea.midY + 4,
				width: brandingTextRect.width,
				height: brandingArea.height / 2 - 12
			)
			"Purrplexed: The Cat Translator".draw(in: footerTaglineRect, withAttributes: footerTaglineAttributes)
			if let icon = brandingIcon() {
				let watermarkSize = CGSize(width: 120, height: 120)
				let watermarkRect = CGRect(
					x: brandingArea.maxX - watermarkSize.width - 16,
					y: brandingArea.minY - watermarkSize.height - 16,
					width: watermarkSize.width,
					height: watermarkSize.height
				)
				icon.draw(in: watermarkRect, blendMode: .normal, alpha: 0.15)
			}
				ctx.addPath(roundedPath.cgPath)
				ctx.setStrokeColor(UIColor.white.cgColor)
				ctx.setLineWidth(borderWidth)
				ctx.strokePath()
			}
		}.value
	}
}

private extension ShareCardRenderer {
	static func fittingFont(
		for text: String,
		in rect: CGRect,
		paragraphStyle: NSParagraphStyle,
		maxFontSize: CGFloat,
		minFontSize: CGFloat,
		weight: UIFont.Weight,
		design: UIFontDescriptor.SystemDesign = .default
	) -> UIFont {
		guard !text.isEmpty else {
			return roundedFont(ofSize: maxFontSize, weight: weight, design: design)
		}
		let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
		var low = min(minFontSize, maxFontSize)
		var high = max(maxFontSize, minFontSize)
		var bestFont = roundedFont(ofSize: low, weight: weight, design: design)
		while high - low > 0.5 {
			let mid = (low + high) / 2
			let font = roundedFont(ofSize: mid, weight: weight, design: design)
			let attributes: [NSAttributedString.Key: Any] = [
				.font: font,
				.paragraphStyle: paragraphStyle
			]
			let boundingBox = text.boundingRect(
				with: CGSize(width: rect.width, height: CGFloat.greatestFiniteMagnitude),
				options: options,
				attributes: attributes,
				context: nil
			).integral
			if boundingBox.height <= rect.height {
				bestFont = font
				low = mid
			} else {
				high = mid
			}
		}
		return bestFont
	}

	static func roundedFont(ofSize size: CGFloat, weight: UIFont.Weight, design: UIFontDescriptor.SystemDesign = .rounded) -> UIFont {
		if let descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(design) {
			return UIFont(descriptor: descriptor, size: size)
		}
		return UIFont.systemFont(ofSize: size, weight: weight)
	}

	static func brandingIcon() -> UIImage? {
		if let asset = UIImage(named: "AppIcon-ShareBranding") {
			return asset
		}
		if let marketingIcon = UIImage(named: "AppIcon-512") {
			return marketingIcon
		}
		return UIImage(named: "AppIcon")
	}
}


