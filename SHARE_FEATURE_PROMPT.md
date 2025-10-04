# Implement Viral Share Feature for Purrplexed

## Context & Objectives

You are an expert Swift/SwiftUI developer implementing a viral share feature for Purrplexed, a cat emotion analysis app. This feature allows users to create and share beautifully framed cat images with AI-generated captions to social media platforms (TikTok, Instagram, etc.).

## Current Architecture (Critical to Understand)

### Analysis Flow
- **CaptureAnalysisView**: Main UI showing photo picker and analysis results
- **CaptureAnalysisViewModel**: Contains analysis state and results:
  - `thumbnailData: Data?` - compressed image used for analysis
  - `originalImageData: Data?` - original high-quality image
  - `catDetectionResult: CatDetectionResult?` - contains bounding box of cat in image
  - `emotionSummary: EmotionSummary?`
  - `bodyLanguageAnalysis: BodyLanguageAnalysis?`
  - `contextualEmotion: ContextualEmotion?`
  - `ownerAdvice: OwnerAdvice?`
  - `catJokes: CatJokes?` (optional)

### Cat Detection System
The app uses Vision framework to detect cats and stores:
```swift
struct CatDetectionResult {
    let boundingBox: CGRect  // In pixel coordinates
    let confidence: Double
    let imageSize: CGSize    // Original image size in pixels
}
```

### Navigation & Routing
- **AppRouter**: Centralized navigation using enum-based routes
- Routes are presented as modals via `.sheet(item: $route)`

### Image Utilities
- **ImageUtils**: Provides `cropToFocus()`, `resizeToFill()`, `resizeToFit()`
- **ExportManager**: Actor-based image rendering from SwiftUI views

### Design System
- **DS (DesignSystem)**: Typography, Color, and Spacing constants
- Rounded design aesthetic throughout

## Feature Requirements

### 1. Share Button Placement
- Add a "Share" button/card in `CaptureAnalysisView` after the last analysis section
- Position: After "Owner Advice" OR after "Cat Jokes" (if cat jokes generated)
- Style: Match existing `AnalysisTrayCard` design with share icon
- Should only appear when core analysis is complete

### 2. Share Editor View (New File: `ShareEditorView.swift`)

**Layout Structure:**
```
┌─────────────────────────────┐
│  Navigation Bar (Close)     │
├─────────────────────────────┤
│                             │
│     Preview Window          │
│        (50%)                │
│   [Framed Cat Image]        │
│                             │
├─────────────────────────────┤
│                             │
│   Caption Editor (40%)      │
│   [Scrollable Chips]        │
│                             │
├─────────────────────────────┤
│   Share Button (10%)        │
└─────────────────────────────┘
```

### 3. Preview Window Requirements

**CRITICAL - Image Cropping Consistency:**
The preview must EXACTLY match the final shared image. Previous implementations failed here.

**Implementation Strategy:**
1. Use `viewModel.originalImageData` (high quality) as source
2. Apply cat detection bounding box from `viewModel.catDetectionResult` to crop
3. Use `ImageUtils.cropToFocus()` with 20% padding
4. Render the complete framed image ONCE and cache it
5. Display the cached image in both preview AND share sheet

**Frame Design:**
- White rounded rectangle border (15pt) around cropped cat image
- Caption text at bottom (inside frame, above branding)
- "Purrplexed 🐱" branding at very bottom of frame
- Frame dimensions: Optimize for Instagram (1080x1350 or 1080x1080)

### 4. Caption Editor Requirements

**Chip Categories:**
Create horizontally scrollable chip sections for each category:
- **Body Language**: Extract 3-5 short phrases from `bodyLanguageAnalysis`
  - Examples: "Ears forward", "Relaxed posture", "Content eyes"
- **Contextual Analysis**: Extract 3-5 phrases from `contextualEmotion.emotionalMeaning`
- **Owner Advice**: Extract 3-5 actionable phrases from `ownerAdvice.immediateActions`
- **Cat Jokes**: Extract jokes from `catJokes.jokes` (if available)
- **Emoji**: Provide selection of cat emojis: 😸 😹 😻 😼 😽 🙀 😿 😾 🐱 🐈 🐈‍⬛

**Chip Behavior:**
- Chips are selectable (toggle on/off with accent color background)
- Selected caption appears in the preview window immediately
- Only one caption active at a time (selecting new chip replaces current)
- Emoji chips can be appended to existing caption
- Maximum caption length: 150 characters

**Caption Extraction Logic:**
```swift
// Example for Body Language
func extractBodyLanguageChips(from analysis: BodyLanguageAnalysis) -> [String] {
    return [
        "Ears: \(analysis.ears)",
        "Tail: \(analysis.tail)",
        analysis.overallMood,
        "Eyes show \(analysis.eyes.prefix(30))...",
        "Posture: \(analysis.posture.prefix(30))..."
    ].compactMap { $0.isEmpty ? nil : $0 }
}
```

### 5. Share Button Implementation

**CRITICAL - Prevent Blank Share Sheet:**
```swift
// Pre-render and cache the final image BEFORE showing share sheet
private func prepareAndShare() {
    Task { @MainActor in
        isLoading = true
        
        // 1. Render the complete framed image
        guard let finalImage = await renderFinalShareImage() else {
            isLoading = false
            showError = true
            return
        }
        
        // 2. Write to temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        
        guard let pngData = finalImage.pngData() else {
            isLoading = false
            return
        }
        
        try? pngData.write(to: tempURL)
        
        // 3. Ensure file exists before presenting
        guard FileManager.default.fileExists(atPath: tempURL.path) else {
            isLoading = false
            return
        }
        
        // 4. Now show share sheet
        isLoading = false
        shareItem = ShareableItem(imageURL: tempURL)
    }
}
```

**Share Sheet Presentation:**
```swift
.sheet(item: $shareItem) { item in
    ActivityViewController(activityItems: [item.imageURL])
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
```

### 6. Image Rendering Strategy

**Create a ShareCardRenderer (New File: `ShareCardRenderer.swift`):**
```swift
struct ShareCardRenderer {
    static func render(
        catImage: UIImage,
        caption: String,
        brandingText: String = "Purrplexed 🐱"
    ) async -> UIImage? {
        return await Task.detached {
            let targetSize = CGSize(width: 1080, height: 1350) // Instagram portrait
            let borderWidth: CGFloat = 15
            let captionHeight: CGFloat = 120
            let brandingHeight: CGFloat = 40
            
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 2.0 // Retina quality
            
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            
            return renderer.image { context in
                let ctx = context.cgContext
                
                // 1. White background
                ctx.setFillColor(UIColor.white.cgColor)
                ctx.fill(CGRect(origin: .zero, size: targetSize))
                
                // 2. Cat image area
                let imageArea = CGRect(
                    x: borderWidth,
                    y: borderWidth,
                    width: targetSize.width - 2 * borderWidth,
                    height: targetSize.height - 2 * borderWidth - captionHeight - brandingHeight
                )
                
                // Draw cat image (aspect fill)
                let scaledImage = ImageUtils.resizeToFill(
                    image: catImage, 
                    targetSize: imageArea.size
                )
                scaledImage.draw(in: imageArea)
                
                // 3. Caption text
                let captionArea = CGRect(
                    x: borderWidth + 20,
                    y: imageArea.maxY + 10,
                    width: targetSize.width - 2 * borderWidth - 40,
                    height: captionHeight - 20
                )
                
                let captionStyle = NSMutableParagraphStyle()
                captionStyle.alignment = .center
                
                let captionAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 28, weight: .semibold),
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: captionStyle
                ]
                
                caption.draw(in: captionArea, withAttributes: captionAttrs)
                
                // 4. Branding
                let brandingArea = CGRect(
                    x: borderWidth,
                    y: captionArea.maxY + 10,
                    width: targetSize.width - 2 * borderWidth,
                    height: brandingHeight
                )
                
                let brandingAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 18, weight: .medium),
                    .foregroundColor: UIColor.gray,
                    .paragraphStyle: captionStyle
                ]
                
                brandingText.draw(in: brandingArea, withAttributes: brandingAttrs)
            }
        }.value
    }
}
```

### 7. Data Flow

```
CaptureAnalysisView
    │
    ├─> [Share Button Tapped]
    │
    └─> AppRouter.present(.shareEditor(context))
            │
            ├─> ShareEditorView(context: ShareEditorContext)
            │       │
            │       ├─> ShareEditorViewModel
            │       │       ├─> Initialize with analysis data
            │       │       ├─> Extract chips from analysis
            │       │       ├─> Track selected caption & emojis
            │       │       └─> Pre-render final image
            │       │
            │       ├─> Preview Window
            │       │       └─> Display cached rendered image
            │       │
            │       └─> Caption Editor
            │               └─> Chip selection updates preview
            │
            └─> Share Button
                    └─> Present UIActivityViewController
```

### 8. Required New Files

1. **ShareEditorView.swift**: Main share editor UI
2. **ShareEditorViewModel.swift**: State management for share editor
3. **ShareEditorContext.swift**: Data transfer object containing:
   - Original image data
   - Cat detection result
   - All analysis results
4. **ShareCardRenderer.swift**: Pure rendering logic for final image

### 9. Modifications to Existing Files

**AppRouter.swift:**
```swift
enum Route: Equatable, Identifiable {
    case paywall
    case settings
    case onboarding
    case shareEditor(ShareEditorContext)  // ADD THIS
    
    var id: String {
        switch self {
        case .paywall: return "paywall"
        case .settings: return "settings"
        case .onboarding: return "onboarding"
        case .shareEditor: return "shareEditor"  // ADD THIS
        }
    }
}
```

**CaptureAnalysisView.swift** (in `ParallelAnalysisResultsView`):
Add share button after the last analysis section:
```swift
// After the ForEach of AnalysisTrayCard sections
if shouldShowShareButton() {
    Button {
        presentShareEditor()
    } label: {
        HStack {
            Image(systemName: "square.and.arrow.up")
                .foregroundColor(.blue)
            Text("Share")
                .font(DS.Typography.bodyFont())
                .fontWeight(.medium)
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private func shouldShowShareButton() -> Bool {
    // Show when core analysis is complete
    return viewModel.emotionSummary != nil && 
           viewModel.bodyLanguageAnalysis != nil &&
           viewModel.contextualEmotion != nil &&
           viewModel.ownerAdvice != nil
}
```

## Critical Implementation Notes

### Preventing Blank Share Sheet Issue
1. **Always pre-render**: Never pass a SwiftUI view directly to share sheet
2. **Write to disk**: Use temporary file, verify it exists before presenting
3. **Use high-quality source**: Start from `originalImageData`, not `thumbnailData`
4. **Add delay if needed**: If render is async, wait for completion before presenting

### Preventing Preview/Share Mismatch
1. **Single render path**: Use SAME rendering function for preview and share
2. **Cache the render**: Don't re-render for share sheet
3. **Exact coordinates**: Use the same cat bounding box calculations
4. **Same image source**: Always use same source data (originalImageData)

### Performance Considerations
1. Render share image on background thread
2. Show loading indicator during render
3. Cache rendered image until caption changes
4. Optimize image size for social media (1080px width)

### Error Handling
1. Handle missing cat detection gracefully (use full image)
2. Provide default captions if analysis incomplete
3. Show error alert if render fails
4. Clean up temporary files on view dismissal

## Testing Checklist

- [ ] Share button appears after analysis completes
- [ ] Share button appears in correct position (after owner advice or cat jokes)
- [ ] Preview shows framed image with caption and branding
- [ ] Changing caption updates preview immediately
- [ ] Adding emoji appends to caption
- [ ] Multiple emoji can be added
- [ ] Chips toggle on/off correctly
- [ ] Share sheet shows correct image on FIRST tap
- [ ] Shared image EXACTLY matches preview
- [ ] Image quality is high (no pixelation)
- [ ] Cat is properly framed (not cut off)
- [ ] Works with images that have no cat detection
- [ ] Works when cat jokes are present
- [ ] Works when cat jokes are absent
- [ ] Temporary files are cleaned up
- [ ] Works on different iOS versions (16+)
- [ ] Works on different device sizes

## Code Style Guidelines

1. Follow existing patterns in CaptureAnalysisView for UI structure
2. Use DS (DesignSystem) constants for typography, spacing, colors
3. Use Haptics for feedback (Haptics.success(), Haptics.error())
4. Use Log.analysis.info() for logging
5. Use @MainActor for view models
6. Use Task { } for async operations
7. Follow Swift naming conventions (camelCase)
8. Add descriptive comments for complex logic

## Success Criteria

1. Users can create shareable images in under 10 seconds
2. Preview ALWAYS matches shared image (100% accuracy)
3. Share sheet never appears blank (0% failure rate)
4. Image quality is Instagram-ready (1080px+)
5. Feature works reliably across all supported iOS versions
6. Code is maintainable and follows app architecture patterns

---

## Additional Context

**Why Previous Implementations Failed:**
1. **Preview mismatch**: Used different rendering paths for preview vs share
2. **Blank share sheet**: Passed SwiftUI views instead of pre-rendered images
3. **Cropping inconsistency**: Applied transformations differently in preview vs final
4. **Timing issues**: Presented share sheet before render completed

**Solution Approach:**
1. Single source of truth: Pre-render ONCE, use everywhere
2. Synchronous presentation: Only show share sheet after render completes
3. Explicit image pipeline: originalImageData → crop → frame → render → cache → share
4. Verification steps: Check file exists, check data not nil, check dimensions correct

Good luck! 🚀

