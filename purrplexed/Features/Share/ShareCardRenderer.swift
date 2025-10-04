//
//  ShareCardRenderer.swift
//  Purrplexed
//
//  Pure UIKit renderer that produces the final shareable image.
//

import UIKit

enum ShareCardRenderer {
	static func render(
		catImage: UIImage,
		caption: String,
		brandingText: String = "Purrplexed 🐱"
	) async -> UIImage? {
		await Task.detached(priority: .userInitiated) {
			let targetSize = CGSize(width: 1080, height: 1350)
			let borderWidth: CGFloat = 15
			let captionHeight: CGFloat = 120
			let brandingHeight: CGFloat = 40
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
				let imageArea = CGRect(
					x: borderWidth,
					y: borderWidth,
					width: targetSize.width - 2 * borderWidth,
					height: targetSize.height - 2 * borderWidth - captionHeight - brandingHeight
				)
				let innerRadius: CGFloat = 24
				let imagePath = UIBezierPath(roundedRect: imageArea, cornerRadius: innerRadius)
				ctx.saveGState()
				ctx.addPath(imagePath.cgPath)
				ctx.clip()
				let scaledImage = ImageUtils.resizeToFill(image: catImage, targetSize: imageArea.size)
				scaledImage.draw(in: imageArea)
				ctx.restoreGState()
				let captionArea = CGRect(
					x: borderWidth + 20,
					y: imageArea.maxY + 10,
					width: targetSize.width - 2 * borderWidth - 40,
					height: captionHeight - 20
				)
				let paragraph = NSMutableParagraphStyle()
				paragraph.alignment = .center
				paragraph.lineBreakMode = .byWordWrapping
				let captionAttributes: [NSAttributedString.Key: Any] = [
					.font: UIFont.systemFont(ofSize: 28, weight: .semibold),
					.foregroundColor: UIColor.black,
					.paragraphStyle: paragraph
				]
				let clampedCaption = String(caption.trimmingCharacters(in: .whitespacesAndNewlines).prefix(150))
				clampedCaption.draw(in: captionArea, withAttributes: captionAttributes)
				let brandingArea = CGRect(
					x: borderWidth,
					y: captionArea.maxY + 10,
					width: targetSize.width - 2 * borderWidth,
					height: brandingHeight
				)
				let brandingAttributes: [NSAttributedString.Key: Any] = [
					.font: UIFont.systemFont(ofSize: 20, weight: .medium),
					.foregroundColor: UIColor.gray,
					.paragraphStyle: paragraph
				]
				brandingText.draw(in: brandingArea, withAttributes: brandingAttributes)
				ctx.addPath(roundedPath.cgPath)
				ctx.setStrokeColor(UIColor.white.cgColor)
				ctx.setLineWidth(borderWidth)
				ctx.strokePath()
			}
		}.value
	}
}


