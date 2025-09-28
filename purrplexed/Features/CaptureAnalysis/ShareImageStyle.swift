import SwiftUI
import UIKit

enum ShareImageStyle {
    static let captionFontSize: CGFloat = 32
    static let captionFontWeight: Font.Weight = .bold
    static let captionUIFont: UIFont = .systemFont(ofSize: captionFontSize, weight: .bold)
    static let captionPadding = EdgeInsets(top: 18, leading: 24, bottom: 18, trailing: 24)
    static let captionUIPadding = UIEdgeInsets(top: 18, left: 24, bottom: 18, right: 24)
    static let captionCornerRadius: CGFloat = 28
    static let captionMaxWidthRatio: CGFloat = 0.8
    static let captionSpacingFromWatermark: CGFloat = 28

    static let watermarkFontSize: CGFloat = 14
    static let watermarkUIFont: UIFont = .systemFont(ofSize: watermarkFontSize, weight: .medium)
    static let watermarkPadding = EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
    static let watermarkUIPadding = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
    static let watermarkCornerRadius: CGFloat = 18
    static let watermarkBottomMargin: CGFloat = 28

    static let captionBackgroundOpacity: CGFloat = 0.6
    static let watermarkBackgroundOpacity: CGFloat = 0.5

    static let maxCaptionWidthMultiplier: CGFloat = 0.8

    static let stickerWidthRatio: CGFloat = 0.08
    static let stickerMinFontSize: CGFloat = 32
    static let stickerReferenceWidth: CGFloat = 400

    // Export presets
    static let storyExportSize = CGSize(width: 1080, height: 1920)
    static let squareExportSize = CGSize(width: 1080, height: 1080)

    static let maxOriginalExportDimension: CGFloat = 4096
    static let preRenderMaxDimension: CGFloat = 2048
    static let maxRenderScale: CGFloat = 2.0
}
