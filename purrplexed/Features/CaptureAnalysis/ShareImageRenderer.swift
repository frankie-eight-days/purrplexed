import CoreGraphics
import UIKit
import SwiftUI

struct ShareImageRenderer {
    struct Input {
        let baseImage: UIImage
        let caption: String
        let captionOffset: CGSize
        let captionRotation: Angle
        let captionScale: CGFloat
    }

    static func render(from input: Input) -> UIImage? {
        let baseImage = input.baseImage
        let canvasSize = baseImage.size
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = baseImage.scale
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 1. Draw the base cat image
            baseImage.draw(at: .zero)
            
            // 2. Draw the caption with transformations
            drawCaption(
                input.caption,
                in: cgContext,
                canvasSize: canvasSize,
                offset: input.captionOffset,
                scale: input.captionScale,
                rotation: input.captionRotation
            )
            
            // 3. Draw the watermark
            drawWatermark(in: cgContext, canvasSize: canvasSize)
        }
    }
    
    private static func drawCaption(
        _ text: String,
        in context: CGContext,
        canvasSize: CGSize,
        offset: CGSize,
        scale: CGFloat,
        rotation: Angle
    ) {
        // Calculate caption dimensions
        let maxWidth = canvasSize.width * ShareImageStyle.maxCaptionWidthMultiplier
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: ShareImageStyle.captionUIFont,
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textBounds = attributedString.boundingRect(
            with: CGSize(width: maxWidth - ShareImageStyle.captionUIPadding.left - ShareImageStyle.captionUIPadding.right,
                        height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        // Create bubble size with padding
        let bubbleSize = CGSize(
            width: textBounds.width + ShareImageStyle.captionUIPadding.left + ShareImageStyle.captionUIPadding.right,
            height: textBounds.height + ShareImageStyle.captionUIPadding.top + ShareImageStyle.captionUIPadding.bottom
        )
        
        // Calculate default position (bottom center, above watermark)
        let defaultY = canvasSize.height - ShareImageStyle.watermarkBottomMargin - 50 - ShareImageStyle.captionSpacingFromWatermark - bubbleSize.height
        let centerPoint = CGPoint(
            x: canvasSize.width / 2 + offset.width,
            y: defaultY + bubbleSize.height / 2 + offset.height
        )
        
        // Save context state
        context.saveGState()
        
        // Apply transformations
        context.translateBy(x: centerPoint.x, y: centerPoint.y)
        context.scaleBy(x: scale, y: scale)
        context.rotate(by: CGFloat(rotation.radians))
        context.translateBy(x: -bubbleSize.width / 2, y: -bubbleSize.height / 2)
        
        // Draw bubble background
        let bubblePath = UIBezierPath(
            roundedRect: CGRect(origin: .zero, size: bubbleSize),
            cornerRadius: ShareImageStyle.captionCornerRadius
        )
        context.setFillColor(UIColor.black.withAlphaComponent(ShareImageStyle.captionBackgroundOpacity).cgColor)
        context.addPath(bubblePath.cgPath)
        context.fillPath()
        
        // Draw text
        let textRect = CGRect(
            x: ShareImageStyle.captionUIPadding.left,
            y: ShareImageStyle.captionUIPadding.top,
            width: textBounds.width,
            height: textBounds.height
        )
        attributedString.draw(in: textRect)
        
        // Restore context state
        context.restoreGState()
    }
    
    private static func drawWatermark(in context: CGContext, canvasSize: CGSize) {
        let watermarkText = "Made with Purrplexed"
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: ShareImageStyle.watermarkUIFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.85),
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: watermarkText, attributes: attributes)
        let textBounds = attributedString.boundingRect(
            with: CGSize(width: canvasSize.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            context: nil
        )
        
        // Create watermark bubble size with padding
        let bubbleSize = CGSize(
            width: textBounds.width + ShareImageStyle.watermarkUIPadding.left + ShareImageStyle.watermarkUIPadding.right,
            height: textBounds.height + ShareImageStyle.watermarkUIPadding.top + ShareImageStyle.watermarkUIPadding.bottom
        )
        
        // Position at bottom center
        let bubbleRect = CGRect(
            x: (canvasSize.width - bubbleSize.width) / 2,
            y: canvasSize.height - ShareImageStyle.watermarkBottomMargin - bubbleSize.height,
            width: bubbleSize.width,
            height: bubbleSize.height
        )
        
        // Draw bubble background
        let bubblePath = UIBezierPath(
            roundedRect: bubbleRect,
            cornerRadius: ShareImageStyle.watermarkCornerRadius
        )
        context.setFillColor(UIColor.black.withAlphaComponent(ShareImageStyle.watermarkBackgroundOpacity).cgColor)
        context.addPath(bubblePath.cgPath)
        context.fillPath()
        
        // Draw text
        let textRect = CGRect(
            x: bubbleRect.minX + ShareImageStyle.watermarkUIPadding.left,
            y: bubbleRect.minY + ShareImageStyle.watermarkUIPadding.top,
            width: textBounds.width,
            height: textBounds.height
        )
        attributedString.draw(in: textRect)
    }
}
