import SwiftUI

// Efficient wrapping layout using SwiftUI's Layout protocol (iOS 16+)
struct WrapLayout: Layout {
    var spacing: CGSize = .init(width: 8, height: 8)

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let fallbackWidth = UIScreen.main.bounds.width - 32
        let maxWidth = proposal.width ?? fallbackWidth
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentRowWidth > 0, currentRowWidth + spacing.width + size.width > maxWidth {
                maxRowWidth = max(maxRowWidth, currentRowWidth)
                totalHeight += currentRowHeight + spacing.height
                currentRowWidth = 0
                currentRowHeight = 0
            }

            currentRowWidth = currentRowWidth == 0 ? size.width : currentRowWidth + spacing.width + size.width
            currentRowHeight = max(currentRowHeight, size.height)
        }

        maxRowWidth = max(maxRowWidth, currentRowWidth)
        totalHeight += currentRowHeight

        return CGSize(width: maxRowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x > bounds.minX, x + spacing.width + size.width > bounds.maxX {
                // wrap to next line
                x = bounds.minX
                y += currentRowHeight + spacing.height
                currentRowHeight = 0
            }

            let origin = CGPoint(x: x, y: y)
            subview.place(at: origin, proposal: .init(width: size.width, height: size.height))

            x = x == bounds.minX ? x + size.width : x + spacing.width + size.width
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}

