# Share Feature Audit & Cleanup - Comprehensive Review

## Objective
Perform a deep audit of the share feature implementation in Purrplexed to identify and remove:
1. **Unused code** - Functions, properties, and files that are defined but never called/referenced
2. **Dead imports** - Import statements for unused modules/frameworks
3. **Orphaned files** - Files that are no longer integrated into the app
4. **Duplicate/overlapping implementations** - Multiple approaches to the same feature
5. **Leftover artifacts** from previous AI implementations

## Context
The share feature has been implemented, deleted, and re-implemented multiple times by AI agents. There are likely leftover artifacts causing context window bloat. The current WORKING implementation uses:
- `ShareEditorView.swift` - Main UI for share editor
- `ShareEditorViewModel.swift` - State management
- `ShareEditorContext.swift` - Data transfer object
- `ShareCardRenderer.swift` - UIKit-based image renderer

## Files to Audit

### Features/Share/ Directory
**Current files:**
- ShareCardRenderer.swift
- ShareEditorContext.swift
- ShareEditorView.swift
- ShareEditorViewModel.swift

**Action needed:**
- ✅ Verify each file is actually imported and used
- ✅ Check for unused functions/properties within each file
- ✅ Look for any additional files in this directory not listed above

### Features/StoryEditor/ Directory
**Suspicious files (potentially old/unused share implementation):**
- BubbleTheme.swift
- ExportManager.swift
- StoryCanvasView.swift
- StoryDocument.swift
- StoryEditorView.swift
- StoryItem.swift
- StoryTheme.swift
- TextKitEditorView.swift

**Known issue:**
- `shareDocument: StoryDocument?` property exists in `CaptureAnalysisViewModel.swift` (line 47)
- This property is SET in `prepareShareDocument()` method but NEVER USED in any view
- StoryEditor types are NOT referenced in `AppRouter.swift` navigation

**Questions to answer:**
1. Is the entire StoryEditor feature unused/orphaned?
2. If unused, can the entire `/Features/StoryEditor/` directory be deleted?
3. If unused, can `shareDocument` property and `prepareShareDocument()` method be removed from CaptureAnalysisViewModel?

### Integration Points to Verify

**AppRouter.swift**
- ✅ Verify ONLY `.shareEditor(ShareEditorContext)` route is needed for share feature
- ❌ Check for any orphaned routes (e.g., storyEditor route that doesn't exist)
- Line 16: `case shareEditor(ShareEditorContext)` - IS THIS USED?

**AppRootView.swift**
- Line 77-78: ShareEditorView is instantiated in route switch
- ✅ Verify this is the ONLY place share feature is accessed

**CaptureAnalysisView.swift**
- Line 438-440: `presentShareEditor()` function triggers share flow
- Line 548: `viewModel.makeShareEditorContext()` creates context
- ✅ Verify these are the ONLY entry points to share feature

**CaptureAnalysisViewModel.swift**
- Line 47: `@Published var shareDocument: StoryDocument? = nil` - **SUSPICIOUS: NEVER USED IN VIEWS**
- Line 259: `shareDocument = nil` - Reset in cleanup
- Line 491-576: `prepareShareDocument()` - **SUSPICIOUS: NEVER CALLED**
- Line 857-868: `makeShareEditorContext()` - **THIS IS USED** (verified in CaptureAnalysisView)

### Helpers Directory

**CatFocusTransformCalculator.swift**
- Used in ShareCardRenderer.swift (line 59)
- Also used in CaptureAnalysisView.swift (line 808)
- ✅ Shared utility - KEEP

**Log.swift**
- Line 15: `static let share = Logger(subsystem: "com.purrplexed.app", category: "Share")`
- Used in ShareCardRenderer and ShareEditorViewModel
- ✅ KEEP

### Components to Check
- ImagePickers.swift - Used for photo selection (not share-specific)
- StickerPaletteView.swift - Name suggests stickers/sharing?
- FlowLayout.swift, WrapLayout.swift - Layout helpers, may be unused

## Specific Cleanup Tasks

### Task 1: Determine StoryEditor Fate
**Hypothesis:** StoryEditor is an old/abandoned share implementation

**Verification steps:**
1. Search entire codebase for references to:
   - `StoryEditor` (case-insensitive)
   - `StoryDocument` (excluding CaptureAnalysisViewModel)
   - `StoryCanvas`
   - `StoryItem`
   - `StoryTheme`
   - `BubbleTheme`
   - `ExportManager`

2. Check if ANY of these are:
   - Imported in active view files
   - Referenced in AppRouter or navigation
   - Used in any UI that's actually presented

3. If NO active references found:
   - **DELETE** entire `/Features/StoryEditor/` directory
   - **REMOVE** `shareDocument` property from CaptureAnalysisViewModel
   - **REMOVE** `prepareShareDocument()` method from CaptureAnalysisViewModel
   - **REMOVE** any imports of StoryDocument/StoryEditor types

### Task 2: Audit ShareEditor Implementation
**Verify current share feature is minimal and complete:**

1. **ShareCardRenderer.swift**
   - Check all imports are used
   - Verify `render()` method is called from ShareEditorViewModel
   - Check for any unused helper methods

2. **ShareEditorContext.swift**
   - Verify all properties are used in ShareEditorViewModel
   - Check if any properties are always nil/unused

3. **ShareEditorView.swift**
   - Check for unused @State variables
   - Verify all methods are called
   - Look for commented-out code
   - Check `ActivityViewController` is only share sheet wrapper needed

4. **ShareEditorViewModel.swift**
   - Most complex file - highest risk of leftover code
   - Check for unused methods (e.g., experimental render functions)
   - Verify all @Published properties are observed in view
   - Look for duplicate/alternate implementations
   - Check for debug/experimental code that should be removed

### Task 3: Remove Dead Imports
For each file in `/Features/Share/`:
- Remove any `import` statements for frameworks/modules not actually used
- Common culprits: UIKit features, Vision, CoreImage, AVFoundation

### Task 4: Check Components Directory
**Files to examine:**
1. **StickerPaletteView.swift**
   - Name suggests stickers for sharing?
   - Is this used? If not, DELETE

2. **FlowLayout.swift** & **WrapLayout.swift**
   - Are these used in ShareEditor? Or anywhere?
   - If unused, DELETE

3. **ImagePickers.swift**
   - Used for photo capture (not share-specific)
   - ✅ Probably needed - but verify

4. **UsageMeterPill.swift**
   - Premium/usage tracking UI
   - ✅ Definitely needed - not share-specific

### Task 5: Analyze SHARE_FEATURE_PROMPT.md
- This is a 441-line implementation guide
- **Question:** Is this just documentation or is code referencing it?
- If it's just a reference document, consider:
  - Archiving it (rename to `.archived/`)
  - Or DELETE if implementation is complete and stable
  - Keep if it documents intentional design decisions

## Audit Checklist

For each file you examine, answer:
- [ ] Is this file imported anywhere?
- [ ] Are all its public types/functions called?
- [ ] Are all its dependencies actually used?
- [ ] Is this a duplicate of functionality elsewhere?
- [ ] Is this part of an old/abandoned implementation?

For each property/method you examine:
- [ ] Is this property observed/read anywhere?
- [ ] Is this method called anywhere?
- [ ] Is this method part of a protocol requirement?
- [ ] Could this be simplified/consolidated?

## Output Format

Please provide your audit results in this format:

### Files to DELETE (Completely Unused)
```
path/to/file.swift
- Reason: Not imported or referenced anywhere
- Confirmed by: [your verification method]
```

### Code to REMOVE (Within Files to Keep)
```
File: path/to/file.swift
Lines: XX-YY
Code: [property/method name]
- Reason: Defined but never called/observed
- Confirmed by: [your verification method]
```

### Imports to REMOVE
```
File: path/to/file.swift
Import: [import statement]
- Reason: Framework features not used in file
```

### Files to KEEP (Verified as Active)
```
path/to/file.swift
- Used by: [list of files that import/use it]
- Key functions: [list of actively-used functions]
```

### Warnings/Uncertainties
```
path/to/file.swift
- Issue: [describe ambiguous situation]
- Recommendation: [your suggested action]
- Needs manual verification: [what to check]
```

## Success Criteria

After cleanup:
1. ✅ Share feature still works perfectly (no regressions)
2. ✅ All files in `/Features/Share/` are actively used
3. ✅ No orphaned StoryEditor code remains
4. ✅ No unused properties in CaptureAnalysisViewModel
5. ✅ All imports in share-related files are necessary
6. ✅ Context window is reduced by removing dead code

## Testing After Cleanup

Verify these workflows still work:
1. Complete an analysis → See share button → Tap share button → Opens ShareEditorView
2. ShareEditorView shows preview with cat image + frame
3. Caption chips work (selecting, emoji adding)
4. Share button renders final image and opens iOS share sheet
5. Shared image matches preview exactly
6. No crashes or missing symbol errors

## Notes

- Be aggressive in removal - if something isn't clearly used, it should probably go
- Prioritize clarity over theoretical reusability
- When in doubt, verify by searching for symbol usage across entire codebase
- Check both exact matches AND case variations (e.g., ShareEditor vs shareEditor)
- Look in comment blocks too - commented code should be deleted

---

## Key Suspicions to Investigate

Based on my initial review, I believe:

1. **HIGH CONFIDENCE: DELETE StoryEditor** - Entire `/Features/StoryEditor/` directory appears to be an old/abandoned implementation that's been replaced by ShareEditor
   - No navigation routes to it
   - `shareDocument` property is set but never used
   - `prepareShareDocument()` is never called

2. **MEDIUM CONFIDENCE: StickerPaletteView unused** - Name suggests sharing feature but not referenced in current ShareEditor implementation

3. **LOW CONFIDENCE: SHARE_FEATURE_PROMPT.md** - May be useful documentation or may be outdated prompt artifact

Please verify these suspicions and provide comprehensive cleanup recommendations.


