# Purrplexed O3 Audit Report

## Executive Summary
- Overall readiness score: 4/10
- Critical issues: 2
- High issues: 3
- Medium issues: 4
- Low issues: 3
- Estimated remediation effort: ~36 engineer hours (iOS 24h, backend 8h, QA 4h)

## Critical Issues 🔴
- **Hidden debug menu bypasses usage/paywall limits** — Tap gesture in `SettingsView` reveals tools that reset usage limits and toggle premium, violating [Guideline 3.1.1](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase).
```45:62:purrplexed/Features/Settings/SettingsView.swift
			Section("Debug Tools") {
				Button("🔄 Reset Usage Counter") {
					viewModel.resetUsage()
...
				Button("⬇️ Demote to Free") {
					viewModel.demoteToFree()
```
```48:90:purrplexed/Features/Settings/SettingsViewModel.swift
	func resetUsage() {
		Task {
			let keychain = KeychainHelper()
			_ = keychain.delete(for: "usage_consumed")
...
```

## High Priority Issues 🟠
- **Missing privacy/legal disclosures** — Paywall lacks Privacy Policy, Terms/EULA, and manage subscription guidance; violates [Guideline 5.1](https://developer.apple.com/app-store/review/guidelines/#privacy) & [3.1.2](https://developer.apple.com/app-store/review/guidelines/#subscriptions).
```174:205:purrplexed/Features/Paywall/PaywallView.swift
			Button("Restore Purchases") {
...
			Text("Cancel anytime • 7-day free trial")
```
- **Free trial claim without configured offer** — UI promises “7-day free trial” but StoreKit flow never configures an introductory offer (Guideline 2.3).
- **Backend auth relies on leaked static key** — `validateApiKey` only checks the exposed string; once leaked, backend fails open.
```13:72:purrplexed_backend/purrplexed_backend/lib/auth.ts
export function validateApiKey(request: NextRequest): AuthResult {
...
  if (token !== appKey) {
```

## Medium Priority Issues 🟡
- **No manage-subscription entry point** — User cannot access subscription management from app (Guideline 3.1.2).
- **App Info.plist not available** — Required `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` cannot be verified; missing keys would cause rejection (Guideline 2.1).
- **Debug `print` statements in production paths** — Release builds leak telemetry; replace with `Logger` or guard for debug.
```121:140:purrplexed/Features/CaptureAnalysis/CaptureAnalysisViewModel.swift
			print("🔢 Refreshing usage status - used: \(newUsedCount), remaining: \(remaining), premium: \(premium)")
...
			print("🔢 Starting analysis - isPremium: \(isPremium)")
```
- **Unused `featureSavePremium` flag** — Potential risk that sharing features remain ungated; audit and enforce paywall expectations.

## Low Priority Issues 🟢
- **Hard-coded strings** — Large portions of UI (paywall, settings, onboarding) lack localization.
- **Emoji-rich logging** — Cosmetic, but consider removing for cleaner release diagnostics.
- **Paywall value messaging sparse** — Add more premium feature highlights to reinforce upgrade value.

## Positive Findings ✅
- StoreKit 2 integration validates transactions via `Transaction.updates` and `checkVerified` safeguards.
- Usage metering actor properly reserves/commits usage to avoid double spends.
- Parallel analysis service handles partial failures with rollbacks and progressive streaming updates.
- Paywall already includes "Maybe Later" and "Restore Purchases" actions, avoiding coercive flows.

## Remediation Plan
### Prioritized Issue List
- [ ] Remove or debug-gate hidden settings menu that resets usage or toggles premium (`SettingsView.swift`, `SettingsViewModel.swift`).
- [ ] Eliminate bundled `APP_KEY`; adopt a secure token exchange (device-bound or per-session).
- [ ] Add Paywall footer links for Privacy Policy, Terms/EULA, and Manage Subscription instructions.
- [ ] Align free-trial messaging with actual StoreKit introductory offer configuration.
- [ ] Verify and commit Info.plist with required privacy usage descriptions.
- [ ] Replace `print` statements with `Logger` or guard behind `#if DEBUG`.
- [ ] Confirm share/export features are properly gated by premium entitlement.

### Fix Implementation Plan
- **Debug menu**
  - Wrap debug section in `#if DEBUG` or remove for release.
  - Ensure production builds cannot call `resetUsage()` or `demoteToFree()`.
  - QA: confirm gesture no longer surfaces tools on TestFlight.
- **Secure backend auth**
  - Remove `APP_KEY` from `Env.plist`; fetch rotating tokens after trusted handshake (e.g., DeviceCheck, signed JWT).
  - Update `validateApiKey` to reject missing/invalid tokens and rate-limit failures.
  - QA/Pen-test: attempt to call API with decompiled app; ensure failure.
- **Legal disclosures**
  - Add buttons/links on paywall and settings to hosted Privacy Policy & Terms/EULA, plus "Manage Subscription" pointing to `https://apps.apple.com/account/subscriptions`.
  - Provide short disclosure of billing cycle and cancellation window.
  - QA: verify links open successfully on device.
- **Free trial messaging**
  - Configure introductory offer in App Store Connect and surface localized price/trial copy from `Product.subscription?.introductoryOffer`, or remove the trial text.
  - QA: StoreKit sandbox purchase reflects accurate trial info.
- **Info.plist audit**
  - Ensure `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, and any microphone entries exist with user-friendly language.
  - QA: fresh install prompts show expected messaging.
- **Logging cleanup**
  - Replace noisy `print` statements with `Log.*` or remove; guard verbose logs with `#if DEBUG`.
  - QA: review device logs on release build for leakage.
- **Premium gating review**
  - Ensure share/export flows respect premium entitlement; add guard rails if necessary.
  - QA: test free vs premium account paths.

### Paywall-Specific Fixes
- [ ] Update paywall copy or configure real intro pricing before launch.
- [ ] Add Privacy Policy, Terms/EULA, and Manage Subscription links to paywall.
- [ ] Clarify billing cadence, trial conversion, and cancellation instructions.
- [ ] Verify "Maybe Later" keeps free-tier features accessible without friction.

### Timeline Estimate
| Task | Hours | Owner |
| --- | --- | --- |
| Remove debug menu in release builds | 4 | iOS |
| Secure backend auth (no bundled secrets) | 8 | Backend + iOS |
| Paywall legal disclosures & UX copy | 6 | iOS/Design |
| Trial messaging alignment | 2 | iOS/PM |
| Info.plist verification & QA | 4 | iOS/QA |
| Logging cleanup | 2 | iOS |
| Premium gating validation | 4 | iOS |
| Regression & compliance QA pass | 6 | QA |

Recommended order: debug menu → backend auth → paywall/legal updates → trial messaging → plist/logging → premium gating → QA sweep.

### Pre-Submission Checklist
- [ ] Confirm release build hides all debug/usage-reset tooling.
- [ ] Verify paywall/legal copy matches App Store Connect configuration.
- [ ] Ensure permission prompts display correct localized text on fresh install.
- [ ] Validate premium gating for analyze/share flows in free vs premium states.
- [ ] Run StoreKit sandbox purchase, restore, and cancellation scenarios.
- [ ] Security smoke test: decompile IPA to ensure no secrets remain; API rejects unauthorized calls.
- [ ] Update App Store metadata & screenshots to reflect final paywall messaging.
- [ ] Execute UI/QA regression across onboarding → analyze → paywall → share flows.
