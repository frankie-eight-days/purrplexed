import SwiftUI

struct FlowLayout<Data, RowContent>: View where Data: RandomAccessCollection, RowContent: View, Data.Element: Hashable {
    private let data: Data
    private let spacing: CGSize
    private let rowContent: (Data.Element) -> RowContent

    @State private var availableWidth: CGFloat = 0

    init(_ data: Data, spacing: CGSize, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent) {
        self.data = data
        self.spacing = spacing
        self.rowContent = rowContent
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(height: 1)
                .readSize { size in
                    availableWidth = size.width
                }

            VStack(alignment: .leading, spacing: spacing.height) {
                ForEach(computeRows(), id: \.self) { rowElements in
                    HStack(spacing: spacing.width) {
                        ForEach(rowElements, id: \.self) { element in
                            rowContent(element)
                        }
                    }
                }
            }
        }
    }

    private func computeRows() -> [[Data.Element]] {
        var rows: [[Data.Element]] = []
        var currentRow: [Data.Element] = []
        var currentRowWidth: CGFloat = 0
        let effectiveSpacing = spacing.width

        for element in data {
            let elementView = rowContent(element)
            let elementSize = UIHostingController(rootView: elementView).view.intrinsicContentSize
            
            if currentRowWidth + elementSize.width + effectiveSpacing > availableWidth, !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = [element]
                currentRowWidth = elementSize.width
            } else {
                currentRow.append(element)
                currentRowWidth += elementSize.width + effectiveSpacing
            }
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }
}

extension View {
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geometryProxy in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometryProxy.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}
