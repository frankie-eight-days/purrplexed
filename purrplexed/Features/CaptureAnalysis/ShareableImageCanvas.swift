import SwiftUI

struct ShareableImageCanvas: View {
    let image: UIImage
    let caption: String
    
    // State for gesture interactions
    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    
    // Combined gesture for dragging and zooming
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = value.translation
            }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = value
            }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
            
            // Caption Text
            Text(caption)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(dragGesture, magnificationGesture)
                )
                .padding(.bottom, 80) // Adjust positioning
            
            // Branding Watermark
            Text("Made with Purrplexed")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .padding(6)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
                .padding(.bottom, 10)
        }
    }
}
