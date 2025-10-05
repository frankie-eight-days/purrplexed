//
//  ShareAspectRatio.swift
//  Purrplexed
//
//  Shared layout definitions for share-card aspect ratios.
//

import CoreGraphics

enum ShareAspectRatio: String, CaseIterable, Identifiable, Hashable {
    case portrait4x5
    case square1x1
    case portrait9x16

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .portrait4x5:
            return "4:5"
        case .square1x1:
            return "1:1"
        case .portrait9x16:
            return "9:16"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .portrait4x5:
            return "Portrait four by five"
        case .square1x1:
            return "Square one by one"
        case .portrait9x16:
            return "Portrait nine by sixteen"
        }
    }

    var layout: ShareCardLayout {
        switch self {
        case .portrait4x5:
            return ShareCardLayout(
                targetSize: CGSize(width: 1080, height: 1350),
                borderWidth: 15,
                cornerRadius: 32,
                imageCornerRadius: 24,
                imageHeightStrategy: .aspect(1.0),
                spacingBelowImage: 22,
                captionHeight: 150,
                captionHorizontalInset: 20,
                captionBackgroundInsets: CGSize(width: 18, height: 14),
                captionBackgroundCornerRadius: 28,
                captionToBrandSpacing: 26,
                captionMaxFontSize: 58,
                captionMinFontSize: 26,
                taglineHeight: 34,
                taglineSpacing: 6,
                brandingHeight: 72,
                brandingCornerRadius: 24,
                brandingIconSize: CGSize(width: 48, height: 48),
                brandingIconLeadingInset: 24,
                brandingIconVerticalOffset: 0,
                brandingTextLeadingInset: 96,
                brandingTextTrailingInset: 24,
                brandingTextTopInset: 12,
                brandingTextBottomPadding: 6,
                footerTaglineTopOffset: 4,
                footerTaglineBottomPadding: 12,
                watermarkSize: CGSize(width: 120, height: 120),
                watermarkTrailingInset: 16,
                watermarkVerticalOffset: 16
            )
        case .square1x1:
            return ShareCardLayout(
                targetSize: CGSize(width: 1080, height: 1080),
                borderWidth: 15,
                cornerRadius: 32,
                imageCornerRadius: 24,
                imageHeightStrategy: .aspect(1.0),
                spacingBelowImage: 18,
                captionHeight: 130,
                captionHorizontalInset: 20,
                captionBackgroundInsets: CGSize(width: 16, height: 12),
                captionBackgroundCornerRadius: 26,
                captionToBrandSpacing: 18,
                captionMaxFontSize: 54,
                captionMinFontSize: 24,
                taglineHeight: 30,
                taglineSpacing: 5,
                brandingHeight: 68,
                brandingCornerRadius: 22,
                brandingIconSize: CGSize(width: 46, height: 46),
                brandingIconLeadingInset: 22,
                brandingIconVerticalOffset: 0,
                brandingTextLeadingInset: 92,
                brandingTextTrailingInset: 22,
                brandingTextTopInset: 10,
                brandingTextBottomPadding: 6,
                footerTaglineTopOffset: 4,
                footerTaglineBottomPadding: 10,
                watermarkSize: CGSize(width: 100, height: 100),
                watermarkTrailingInset: 16,
                watermarkVerticalOffset: 14
            )
        case .portrait9x16:
            return ShareCardLayout(
                targetSize: CGSize(width: 1080, height: 1920),
                borderWidth: 15,
                cornerRadius: 32,
                imageCornerRadius: 24,
                imageHeightStrategy: .fillAvailable,
                spacingBelowImage: 28,
                captionHeight: 170,
                captionHorizontalInset: 24,
                captionBackgroundInsets: CGSize(width: 18, height: 16),
                captionBackgroundCornerRadius: 30,
                captionToBrandSpacing: 40,
                captionMaxFontSize: 60,
                captionMinFontSize: 26,
                taglineHeight: 36,
                taglineSpacing: 8,
                brandingHeight: 88,
                brandingCornerRadius: 26,
                brandingIconSize: CGSize(width: 52, height: 52),
                brandingIconLeadingInset: 26,
                brandingIconVerticalOffset: 0,
                brandingTextLeadingInset: 106,
                brandingTextTrailingInset: 28,
                brandingTextTopInset: 14,
                brandingTextBottomPadding: 8,
                footerTaglineTopOffset: 6,
                footerTaglineBottomPadding: 14,
                watermarkSize: CGSize(width: 140, height: 140),
                watermarkTrailingInset: 20,
                watermarkVerticalOffset: 18
            )
        }
    }

    var aspect: CGFloat {
        layout.aspect
    }
}

struct ShareCardLayout {
    enum ImageHeightStrategy {
        case aspect(CGFloat)
        case fillAvailable
    }

    let targetSize: CGSize
    let borderWidth: CGFloat
    let cornerRadius: CGFloat
    let imageCornerRadius: CGFloat
    let imageHeightStrategy: ImageHeightStrategy
    let spacingBelowImage: CGFloat
    let captionHeight: CGFloat
    let captionHorizontalInset: CGFloat
    let captionBackgroundInsets: CGSize
    let captionBackgroundCornerRadius: CGFloat
    let captionToBrandSpacing: CGFloat
    let captionMaxFontSize: CGFloat
    let captionMinFontSize: CGFloat
    let taglineHeight: CGFloat
    let taglineSpacing: CGFloat
    let brandingHeight: CGFloat
    let brandingCornerRadius: CGFloat
    let brandingIconSize: CGSize
    let brandingIconLeadingInset: CGFloat
    let brandingIconVerticalOffset: CGFloat
    let brandingTextLeadingInset: CGFloat
    let brandingTextTrailingInset: CGFloat
    let brandingTextTopInset: CGFloat
    let brandingTextBottomPadding: CGFloat
    let footerTaglineTopOffset: CGFloat
    let footerTaglineBottomPadding: CGFloat
    let watermarkSize: CGSize
    let watermarkTrailingInset: CGFloat
    let watermarkVerticalOffset: CGFloat

    var aspect: CGFloat {
        guard targetSize.width > 0 else { return 1 }
        return targetSize.height / targetSize.width
    }

    func imageHeight(contentWidth: CGFloat) -> CGFloat {
        let availableHeight = max(0, targetSize.height - (2 * borderWidth + spacingBelowImage + captionHeight + captionToBrandSpacing + brandingHeight))
        let desiredHeight: CGFloat
        switch imageHeightStrategy {
        case .aspect(let ratio):
            desiredHeight = contentWidth * ratio
        case .fillAvailable:
            desiredHeight = availableHeight
        }
        if availableHeight <= 0 {
            return 0
        }
        return min(desiredHeight, availableHeight)
    }
}


