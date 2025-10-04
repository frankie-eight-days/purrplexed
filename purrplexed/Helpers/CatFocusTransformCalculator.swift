//
//  CatFocusTransformCalculator.swift
//  Purrplexed
//
//  Shared helper to align cat image framing across analysis and share flows.
//

import CoreGraphics
import UIKit

struct CatFocusTransform {
    let containerSize: CGSize
    let fillScale: CGFloat
    let extraScale: CGFloat
    let offset: CGSize

    var effectiveScale: CGFloat { fillScale * extraScale }

    func finalImageSize(for imageSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let baseWidth = imageSize.width * fillScale
        let baseHeight = imageSize.height * fillScale
        return CGSize(width: baseWidth * extraScale, height: baseHeight * extraScale)
    }

    func drawingRect(for imageSize: CGSize) -> CGRect {
        let finalSize = finalImageSize(for: imageSize)
        let origin = CGPoint(
            x: (containerSize.width - finalSize.width) / 2 + offset.width,
            y: (containerSize.height - finalSize.height) / 2 + offset.height
        )
        return CGRect(origin: origin, size: finalSize)
    }
}

enum CatFocusTransformCalculator {
    static func calculate(
        image: UIImage,
        containerSize: CGSize,
        catDetectionResult: CatDetectionResult?,
        paddingRatio: CGFloat = 0.3,
        maxZoom: CGFloat = 1.8
    ) -> CatFocusTransform {
        guard containerSize.width > 0, containerSize.height > 0 else {
            return CatFocusTransform(
                containerSize: containerSize,
                fillScale: 1,
                extraScale: 1,
                offset: .zero
            )
        }

        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CatFocusTransform(
                containerSize: containerSize,
                fillScale: 1,
                extraScale: 1,
                offset: .zero
            )
        }

        let scaleX = containerSize.width / imageSize.width
        let scaleY = containerSize.height / imageSize.height
        let fillScale = max(scaleX, scaleY)

        guard let catResult = catDetectionResult else {
            return CatFocusTransform(
                containerSize: containerSize,
                fillScale: fillScale,
                extraScale: 1,
                offset: .zero
            )
        }

        let boundingWidth = catResult.boundingBox.width
        let boundingHeight = catResult.boundingBox.height
        let imagePixelWidth = max(catResult.imageSize.width, 1)
        let imagePixelHeight = max(catResult.imageSize.height, 1)

        let widthRatio = boundingWidth / imagePixelWidth
        let heightRatio = boundingHeight / imagePixelHeight
        let boundingAspect = boundingWidth / max(boundingHeight, 1)
        let containerAspect = containerSize.width / max(containerSize.height, 1)

        if widthRatio > 0.85 && heightRatio > 0.6 {
            return CatFocusTransform(
                containerSize: containerSize,
                fillScale: fillScale,
                extraScale: 1,
                offset: .zero
            )
        }

        let aspectRatioDifference = boundingAspect / max(containerAspect, 0.01)
        if aspectRatioDifference < 0.45 || aspectRatioDifference > 1.8 {
            return CatFocusTransform(
                containerSize: containerSize,
                fillScale: fillScale,
                extraScale: 1,
                offset: .zero
            )
        }

        let pixelToPointScale = image.scale
        let catBoxInPoints = CGRect(
            x: catResult.boundingBox.minX / pixelToPointScale,
            y: catResult.boundingBox.minY / pixelToPointScale,
            width: boundingWidth / pixelToPointScale,
            height: boundingHeight / pixelToPointScale
        )

        let paddingX = catBoxInPoints.width * paddingRatio
        let paddingY = catBoxInPoints.height * paddingRatio
        var targetBox = catBoxInPoints.insetBy(dx: -paddingX, dy: -paddingY)
        targetBox = targetBox.intersection(CGRect(origin: .zero, size: imageSize))

        let scaledTargetWidth = targetBox.width * fillScale
        let scaledTargetHeight = targetBox.height * fillScale

        let additionalScaleX = containerSize.width / max(scaledTargetWidth, 1)
        let additionalScaleY = containerSize.height / max(scaledTargetHeight, 1)
        let additionalScale = min(additionalScaleX, additionalScaleY)
        let clampedScale = min(additionalScale, maxZoom)

        if clampedScale <= 1.05 {
            return CatFocusTransform(
                containerSize: containerSize,
                fillScale: fillScale,
                extraScale: 1,
                offset: .zero
            )
        }

        let scaledImageWidth = imageSize.width * fillScale
        let scaledImageHeight = imageSize.height * fillScale
        let finalImageWidth = scaledImageWidth * clampedScale
        let finalImageHeight = scaledImageHeight * clampedScale

        let catCenterInImage = CGPoint(
            x: targetBox.midX * fillScale * clampedScale,
            y: targetBox.midY * fillScale * clampedScale
        )

        let imageCenter = CGPoint(
            x: finalImageWidth / 2,
            y: finalImageHeight / 2
        )

        var offset = CGSize(
            width: imageCenter.x - catCenterInImage.x,
            height: imageCenter.y - catCenterInImage.y
        )

        let maxOffsetX = abs(finalImageWidth - containerSize.width) / 2
        let maxOffsetY = abs(finalImageHeight - containerSize.height) / 2

        if maxOffsetX > 0 {
            offset.width = max(-maxOffsetX, min(maxOffsetX, offset.width))
        } else {
            offset.width = 0
        }

        if maxOffsetY > 0 {
            offset.height = max(-maxOffsetY, min(maxOffsetY, offset.height))
        } else {
            offset.height = 0
        }

        return CatFocusTransform(
            containerSize: containerSize,
            fillScale: fillScale,
            extraScale: clampedScale,
            offset: offset
        )
    }
}


