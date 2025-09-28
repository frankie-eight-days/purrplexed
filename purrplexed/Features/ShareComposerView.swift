import SwiftUI
import UIKit

struct ShareComposerView: View {
    @ObservedObject var viewModel: CaptureAnalysisViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    
    // State for the currently selected caption text
    @State private var selectedCaptionText: String = ""
    
    // State for presenting the share sheet
    @State private var isSharing: Bool = false
    @State private var sharedImage: UIImage?
    
    // MARK: - Gesture State for the Caption
    @State private var captionOffset: CGSize = .zero
    @State private var captionAngle: Angle = .zero
    @State private var captionScale: CGFloat = 1.0
    @State private var previewCanvasSize: CGSize = .zero
    
    // The view that will be rendered into an image for sharing
    @ViewBuilder
    private var shareableContent: some View {
        // Ensure we have valid image data to create a UIImage
        if let data = viewModel.thumbnailData, let image = UIImage(data: data) {
            ShareableImageCanvas(
                image: image,
                caption: selectedCaptionText,
                offset: $captionOffset,
                angle: $captionAngle,
                scale: $captionScale
            )
        } else {
            // Provide a fallback view if the image data is missing
            Text("Image not available")
        }
    }
    
    private var captionOptions: [String] {
        var options: [String] = []
        if let summary = viewModel.emotionSummary {
            options.append("\(summary.emoji) \(summary.description)")
        }
        if let bodyLanguage = viewModel.bodyLanguageAnalysis {
            options.append(bodyLanguage.overallMood)
        }
        if let contextual = viewModel.contextualEmotion?.emotionalMeaning.first {
            options.append(contextual)
        }
        if let advice = viewModel.ownerAdvice?.immediateActions.first {
            options.append("Pro-tip: \(advice)")
        }
        if let jokes = viewModel.catJokes?.jokes {
            options.append(contentsOf: jokes)
        }
        
        // Fallback option
        if options.isEmpty {
            options.append("My cat is a mystery wrapped in fur.")
        }
        
        return options
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 1. Live Preview of the Shareable Image
                shareableContent
                    .readSize { size in
                        // We'll use this to normalize gesture offsets when
                        // exporting the high-resolution image.
                        previewCanvasSize = size
                    }
                    .cornerRadius(16)
                    .shadow(radius: 5)
                    .padding(.horizontal)
                
                // 2. Caption Chips
                VStack(alignment: .leading) {
                    Text("Choose a Caption")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    FlowLayout(captionOptions, spacing: CGSize(width: 8, height: 8)) { caption in
                        Button(action: {
                            self.selectedCaptionText = caption
                        }) {
                            Text(caption)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedCaptionText == caption ? Color.accentColor : Color.secondary.opacity(0.2))
                                .foregroundColor(selectedCaptionText == caption ? .white : .primary)
                                .cornerRadius(20)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Create & Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share") { generateAndShare() }
                        .disabled(selectedCaptionText.isEmpty)
                }
            }
            .onAppear {
                if selectedCaptionText.isEmpty {
                    selectedCaptionText = captionOptions.first ?? ""
                }

                // Reset transformation state when entering the screen so every
                // share starts from a consistent baseline.
                captionOffset = .zero
                captionAngle = .zero
                captionScale = 1.0
            }
            .sheet(isPresented: $isSharing, onDismiss: {
                sharedImage = nil
            }) {
                if let image = sharedImage {
                    ActivityView(activityItems: [image])
                }
            }
        }
    }

    private func generateAndShare() {
        guard let data = viewModel.thumbnailData, let image = UIImage(data: data) else {
            print("Error: Missing image data for sharing.")
            return
        }

        let input = ShareImageRenderer.Input(
            baseImage: image,
            caption: selectedCaptionText,
            captionOffset: convertOffsetToImageSpace(for: image),
            captionRotation: captionAngle,
            captionScale: captionScale
        )

        guard let renderedImage = ShareImageRenderer.render(from: input) else {
            print("Error: Could not render share image.")
            return
        }

        sharedImage = renderedImage
        isSharing = true
    }

    private func convertOffsetToImageSpace(for image: UIImage) -> CGSize {
        let displaySize = previewCanvasSize == .zero ? CGSize(width: image.size.width, height: image.size.height) : previewCanvasSize
        guard displaySize.width > 0, displaySize.height > 0 else { return captionOffset }
        let scaleX = image.size.width / displaySize.width
        let scaleY = image.size.height / displaySize.height
        return CGSize(width: captionOffset.width * scaleX,
                      height: captionOffset.height * scaleY)
    }
}
