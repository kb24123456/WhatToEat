# Profile Dashboard Card Animation Rebuild Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rebuild the 8 dashboard preview-card to detail-card expansion/collapse animation from scratch so it behaves like a stable iOS-native shared card transition.

**Architecture:** Replace the current multi-layer card animation stack with a single shell transition driven by one matched geometry source and one destination. Preview cards keep their shell in place as the source, the expanded overlay owns the destination shell plus adaptive-height detail content, and backdrop blur plus tab bar hiding are treated as separate secondary effects. Internal staggered detail animations are disabled for this presentation mode to avoid fighting the shell transition.

**Tech Stack:** SwiftUI, matchedGeometryEffect, PreferenceKey-based offscreen measurement, NotificationCenter tab bar visibility hooks.

---

### Task 1: Remove the current dashboard card animation stack

**Files:**
- Modify: `WhatToEat/ExpandableCard.swift`

**Step 1: Delete the current staged animation states**
- Remove the internal overlay states for backdrop opacity, card scale, card Y offset, staged header/content opacity, delayed dismissal tasks, and drag-dismiss animation choreography.
- Remove any transition logic that scales or offsets the overlay card independently from the shell transition.

**Step 2: Rebuild the preview card shell**
- Keep only a lightweight press feedback on tap.
- Make the preview card shell the sole matched-geometry source for each card ID.
- Keep preview content visible only while the card is not expanded.

**Step 3: Rebuild the expanded overlay shell**
- Make the overlay card shell the sole matched-geometry destination.
- Keep the overlay centered, clipped, and adaptive in height.
- Remove drag-to-dismiss from this flow; only close button and backdrop tap should dismiss.

**Step 4: Keep backdrop and tab bar side effects separate**
- Fade in the backdrop with blur + darkening.
- Keep tab bar hide/restore notifications in overlay appear/disappear only.

### Task 2: Measure detail content before expansion

**Files:**
- Modify: `WhatToEat/ProfileView.swift`

**Step 1: Add pending expansion state and cached heights**
- Track a pending card ID before expansion.
- Cache measured detail content heights keyed by card ID.

**Step 2: Add an offscreen measurement layer**
- Render the target detail content offscreen at the final overlay width.
- Measure height via a dedicated PreferenceKey.
- Once measured, promote pending card ID into the real expanded card ID inside one spring animation.

**Step 3: Use cached heights for immediate re-open**
- If a card has already been measured, open it immediately using the cached target height.

### Task 3: Parent-managed transition orchestration

**Files:**
- Modify: `WhatToEat/ProfileView.swift`

**Step 1: Restore namespace-driven shell animation**
- Pass the profile namespace back into the dashboard cards and expanded overlay.
- Keep only one expanded overlay active at a time.

**Step 2: Simplify the overlay transition**
- Use opacity only for the full-screen overlay container.
- Let the matched geometry shell own position and size changes.

**Step 3: Keep close behavior direct**
- Clicking close or backdrop should immediately animate the expanded card ID back to nil.
- Do not keep any temporary closing shell state.

### Task 4: Neutralize internal detail animations during card presentation

**Files:**
- Modify: `WhatToEat/CardAnimationSystem.swift`
- Modify: `WhatToEat/ProfileCards/ConsumptionCard.swift`

**Step 1: Add an environment-controlled disable flag for staggered detail animations**
- When disabled, `staggeredAnimation` should be a no-op.

**Step 2: Apply the disable flag inside the expanded dashboard overlay**
- Ensure detail subviews do not run their old staged presentation while the shell is animating.

**Step 3: Remove the extra chart delayed animation from the consumption detail card**
- The consumption chart should render directly in detail mode without a delayed show/hide sequence.

### Task 5: Validate stability and document known environment blockers

**Files:**
- No code changes required beyond previous tasks.

**Step 1: Run a workspace-local build**
Run:
```bash
xcodebuild -project WhatToEat.xcodeproj -scheme WhatToEat -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath .codex-build-ios-local CODE_SIGNING_ALLOWED=NO build
```
Expected:
- Swift sources compile through `ProfileView.swift` and `ExpandableCard.swift`.
- If build fails, capture whether it is a known `actool/CoreSimulator` environment issue or a new Swift compile error.

**Step 2: Manual validation checklist**
- Tap any of the 8 preview cards: shell expands from the original card position to the center.
- Background blur fades in without the shell jumping.
- Tab bar hides quickly and feels absorbed into the backdrop.
- Tap close or blank backdrop: shell collapses back to the exact preview card position.
- No blank shell remains on screen after dismissal.
- No runtime warnings about multiple matched geometry sources.

**Step 3: Record residual risks**
- First open may wait one layout pass for measurement if no cached height exists.
- Build verification may still be blocked by local CoreSimulator/actool environment issues unrelated to the animation code.
