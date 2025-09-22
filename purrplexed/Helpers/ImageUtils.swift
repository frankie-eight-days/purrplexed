//
//  ImageUtils.swift
//  Purrplexed
//
//  Helpers to resize/compress images for network upload and cropping.
//

import UIKit
import Vision

enum ImageUtils {
	/// Downscale and compress a UIImage to fit within maxDimension (longest side) and below targetBytes if possible.
	static func jpegDataFitting(_ image: UIImage, maxDimension: CGFloat = 1280, targetBytes: Int = 1_500_000, initialQuality: CGFloat = 0.8) -> Data? {
		let scaled = resize(image: image, maxDimension: maxDimension)
		var quality = initialQuality
		var data = scaled.jpegData(compressionQuality: quality)
		// Reduce quality iteratively if above target size
		var attempts = 0
		while let d = data, d.count > targetBytes, attempts < 5 {
			quality -= 0.15
			data = scaled.jpegData(compressionQuality: max(0.4, quality))
			attempts += 1
		}
		return data
	}
	
	private static func resize(image: UIImage, maxDimension: CGFloat) -> UIImage {
		let size = image.size
		let maxSide = max(size.width, size.height)
		guard maxSide > maxDimension else { return image }
		let scale = maxDimension / maxSide
		let newSize = CGSize(width: size.width * scale, height: size.height * scale)
		let format = UIGraphicsImageRendererFormat.default()
		format.scale = 1
		let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
		return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
	}
	
	/// Crop an image to focus on a specific bounding box, with padding
	static func cropToFocus(image: UIImage, boundingBox: CGRect, paddingRatio: CGFloat = 0.2) -> UIImage? {
		guard let cgImage = image.cgImage else { return nil }
		
		let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
		
		// Add padding around the bounding box
		let paddingX = boundingBox.width * paddingRatio
		let paddingY = boundingBox.height * paddingRatio
		
		var expandedBox = boundingBox.insetBy(dx: -paddingX, dy: -paddingY)
		
		// Ensure the expanded box stays within image bounds
		expandedBox = expandedBox.intersection(CGRect(origin: .zero, size: imageSize))
		
		// Crop the CGImage
		guard let croppedCGImage = cgImage.cropping(to: expandedBox) else { return nil }
		
		return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
	}
	
	/// Calculate optimal frame size to contain the cat while maintaining aspect ratio
	static func calculateOptimalFrame(for boundingBox: CGRect, in containerSize: CGSize, paddingRatio: CGFloat = 0.2) -> CGRect {
		// Add padding around the bounding box
		let paddingX = boundingBox.width * paddingRatio
		let paddingY = boundingBox.height * paddingRatio
		
		var targetBox = boundingBox.insetBy(dx: -paddingX, dy: -paddingY)
		
		// Ensure target box stays within container bounds
		targetBox = targetBox.intersection(CGRect(origin: .zero, size: containerSize))
		
		// Calculate scale factor to fit the target box optimally
		let scaleX = containerSize.width / targetBox.width
		let scaleY = containerSize.height / targetBox.height
		let scale = min(scaleX, scaleY, 2.0) // Cap at 2x zoom
		
		// Calculate final frame size
		let finalWidth = targetBox.width * scale
		let finalHeight = targetBox.height * scale
		
		// Center the frame in the container
		let x = (containerSize.width - finalWidth) / 2
		let y = (containerSize.height - finalHeight) / 2
		
		return CGRect(x: x, y: y, width: finalWidth, height: finalHeight)
	}
}
