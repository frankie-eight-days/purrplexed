import SwiftUI

struct ShareCardEditorView: View {
    @ObservedObject var viewModel: CaptureAnalysisViewModel
    let shareAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let data = viewModel.shareCardData {
                VStack(spacing: 12) {
                    ShareCardView(data: data)
                        .frame(width: previewWidth, height: previewWidth * 16 / 9)
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 8)
                    Text("Preview")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
            }
            Divider().padding(.vertical, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Customize share card")
                        .font(.title3.bold())
                    Text("Select the highlights you want to include.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let options = viewModel.shareCardOptions {
                        selectionSection(
                            title: "Context Highlights",
                            items: options.contextHighlights,
                            selection: $viewModel.selectedContextIndexes,
                            maxSelection: 3
                        )
                        selectionSection(
                            title: "Advice",
                            items: options.adviceHighlights,
                            selection: $viewModel.selectedAdviceIndexes,
                            maxSelection: 2
                        )
                    }
                    Button(action: shareAction) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Card")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }

    private func selectionSection(
        title: String,
        items: [String],
        selection: Binding<Set<Int>>,
        maxSelection: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            WrapLayout(spacing: CGSize(width: 12, height: 12)) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, value in
                    Chip(
                        label: value,
                        isSelected: selection.wrappedValue.contains(index)
                    ) {
                        toggle(index: index, selection: selection, maxSelection: maxSelection)
                    }
                }
            }
        }
    }

    private func toggle(
        index: Int,
        selection: Binding<Set<Int>>,
        maxSelection: Int
    ) {
        var current = selection.wrappedValue
        if current.contains(index) {
            current.remove(index)
        } else {
            if current.count < maxSelection {
                current.insert(index)
            } else if let first = current.first {
                current.remove(first)
                current.insert(index)
            }
        }
        selection.wrappedValue = current
    }

    private var previewWidth: CGFloat {
        min(UIScreen.main.bounds.width - 64, 220)
    }
}

private struct Chip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
                .foregroundColor(isSelected ? Color.accentColor : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

