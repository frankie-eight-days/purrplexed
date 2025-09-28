import SwiftUI

struct StickerPaletteView: View {
    var emojis: [String]
    var onAdd: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(action: { onAdd(emoji) }) {
                        Text(emoji)
                            .font(.system(size: 34))
                            .frame(width: 52, height: 52)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 72)
    }
}

