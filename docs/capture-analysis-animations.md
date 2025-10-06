# Capture Analysis Reveal Animation — Implementation Brief

Goal: polish the post-analysis reveal. Today we blank the results area, then inject each tray when its data arrives; users experience a dead pause followed by abrupt slide-ins. We want a cohesive entrance: trays are staged immediately and then slide in with alternating directions, easing, and placeholder states—without breaking existing logic or analytics.

## Constraints & Context
- Entry point: `CaptureAnalysisView` → `ParallelAnalysisResultsView`.
- Analysis payload lives on `CaptureAnalysisViewModel`; updates arrive via `handleParallelAnalysisUpdate`.
- Do **not** regress cat detection, usage accounting, or share sheet prep.
- Respect Reduce Motion; fall back to fade-only if enabled.

## Implementation Steps
1. **State scaffolding**
   - In `ParallelAnalysisResultsView`, add:
     ```swift
     struct RevealItem: Identifiable { ... phase enum ... direction enum }
     @State private var revealItems: [RevealItem] = []
     @State private var activeRunID = UUID()
     ```
   - Derive desired order `[emotionSummary, bodyLanguage, contextualEmotion, ownerAdvice, catJokes?]`, alternating `.leading/.trailing`.

2. **Lifecycle hooks**
   - When `viewModel.isAnalyzing` flips true, reset `revealItems` with placeholders (phase `.loading` and `isVisible = false`).
   - When `viewModel` receives first non-nil section, use `withAnimation` to flip that item into `.revealing`. Kick off a `Task.detached` that sequentially toggles remaining items with `await Task.sleep(0.12s)` between each (cancel if `activeRunID` changes).

3. **Tray rendering**
   - Always render each `RevealItem`, independent of data availability.
   - Inside `AnalysisTrayCard`, add conditional placeholder content (`ProgressView` rows or redacted text) for `phase != .ready`.
   - Apply `offset(x:)` tied to `phase` (`loading` = off-screen, `revealing` = animate to zero, `ready` = steady). Combine with `opacity` and a subtle `scaleEffect(0.98→1.0)`.

4. **Emotion summary**
   - Wrap summary card in same staging system. Give it a longer spring (`response: 0.7, damping: 0.8`) and optional glow (background accent with `.opacity` animation).

5. **Outer container**
   - Replace the guard in `analysisResultsView`: keep a `ZStack` mounted even while waiting. Show a `ProgressView`/copy until reveal kicks off so there’s never an empty space.

6. **Reduce Motion**
   - Gate all `withAnimation` calls through helper that checks `UIAccessibility.isReduceMotionEnabled`. If true, skip offsets and only fade.

7. **Testing**
   - Run on simulator with `MockParallelAnalysisService` to validate sequencing, repeated analyses, and cat jokes optionality.
   - Verify no regressions for share button visibility and classic fallback.
   - Check Reduce Motion by toggling in Settings → Accessibility.

## Deliverables
- Updated `CaptureAnalysisView.swift` (outer container).
- Updated `ParallelAnalysisResultsView` & `AnalysisTrayCard`.
- Optional new helper `RevealAnimationModifier`.
- Unit/UI tests if feasible (snapshot/preview updates acceptable fallback).

