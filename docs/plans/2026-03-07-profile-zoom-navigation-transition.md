# Profile Dashboard Zoom Navigation Transition Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the custom dashboard card expand/collapse overlay system in `ProfileView` with native SwiftUI `.navigationTransition(.zoom)` navigation.

**Architecture:** The dashboard preview cards become native navigation sources using `NavigationLink` and `matchedTransitionSource`. The detail state becomes a standard pushed destination screen inside a `NavigationStack`, removing the old overlay, blur backdrop, delayed close logic, and height-measurement orchestration. The destination screen is a stable scrollable page container so the transition is owned by the system rather than custom geometry code.

**Tech Stack:** SwiftUI, NavigationStack, NavigationLink, navigationTransition(.zoom), matchedTransitionSource

---

### Task 1: Replace dashboard overlay architecture with native navigation

**Files:**
- Modify: `WhatToEat/ProfileView.swift`
- Modify: `WhatToEat/ProfileViewModel.swift`
- Modify: `WhatToEat/ExpandableCard.swift`

**Step 1: Remove old expanded-card overlay state and helper methods from `ProfileView`**
Delete `expandedCardContentHeights`, overlay render branches, `expandedCardOverlay`, close/presentation helpers, and offscreen measurement plumbing.

**Step 2: Add a dedicated navigation container for `ProfileView`**
Wrap the profile root scene in a `NavigationStack` and wire destination routing for dashboard cards.

**Step 3: Convert dashboard cards to native navigation sources**
Turn each dashboard card into a `NavigationLink`-based source that uses `matchedTransitionSource` for zoom.

**Step 4: Build a stable destination screen wrapper**
Render each detail card inside a normal page layout with a title, scroll container, and system-owned zoom transition.

### Task 2: Remove obsolete expansion state from the view model

**Files:**
- Modify: `WhatToEat/ProfileViewModel.swift`

**Step 1: Delete unused `expandedCardId` state and methods**
Remove expansion state and close/open helpers that only served the custom overlay implementation.

**Step 2: Verify dependent code paths compile after removal**
Update `ProfileView` call sites so there are no remaining references to the removed API.

### Task 3: Simplify the reusable card component

**Files:**
- Modify: `WhatToEat/ExpandableCard.swift`

**Step 1: Remove overlay-only animation logic**
Delete keyboard observers, backdrop blur, shell measurement, and close callbacks.

**Step 2: Keep only preview card shell + native navigation source wiring**
Expose a compact reusable card that owns the preview styling and zoom transition source registration.

### Task 4: Smoke-test buildability and runtime assumptions

**Files:**
- Modify: none

**Step 1: Run a build smoke test**
Run `xcodebuild -project WhatToEat.xcodeproj -scheme WhatToEat -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`.

**Step 2: Record remaining environment blockers**
If build still fails at `actool/CoreSimulator`, record that separately from Swift compile status.
