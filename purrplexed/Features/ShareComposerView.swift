import SwiftUI
import UIKit

struct ShareComposerView: View {
    @ObservedObject var viewModel: CaptureAnalysisViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    
    // State for the currently selected caption text
    @State private var selectedCaptionText: String = ""
    
    // The view that will be rendered into an image for sharing
    @ViewBuilder
    private var shareableContent: some View {
        // Ensure we have valid image data to create a UIImage
        if let data = viewModel.thumbnailData, let image = UIImage(data: data) {
            ShareableImageCanvas(image: image, caption: selectedCaptionText)
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
                    Button("Share") { share() }
                        .disabled(selectedCaptionText.isEmpty)
                }
            }
            .onAppear {
                // Set initial caption
                if selectedCaptionText.isEmpty {
                    selectedCaptionText = captionOptions.first ?? ""
                }
            }
        }
    }
    
    private func share() {
        // TODO: Update this to render `shareableContent` to an image
        let renderer = ImageRenderer(content: shareableContent)
        renderer.scale = UIScreen.main.scale
        guard let image = renderer.uiImage else {
            print("Failed to render image")
            return
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.keyWindow?.rootViewController else { return }

        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        root.present(activityVC, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            dismiss()
        }
    }
}
