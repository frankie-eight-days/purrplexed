//
//  ShareAspectRatio.swift
//  Purrplexed
//
//  Shared layout definitions for share-card aspect ratios.
//

import CoreGraphics

enum ShareAspectRatio: String, CaseIterable, Identifiable, Hashable {
    case square1x1

    var id: String { rawValue }

    var displayName: String {
        return "1:1"
    }

    var accessibilityLabel: String {
        return "Square one by one"
    }

    var layout: ShareCardLayout {
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


