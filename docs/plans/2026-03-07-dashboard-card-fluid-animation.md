# Dashboard Card Fluid Animation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Improve the expand and collapse motion of the eight profile dashboard cards so the hero transition feels more continuous, native, and visually calm.

**Architecture:** Keep the card background responsible for the matched-geometry frame morph only, and move overlay chrome/content into a separate staged animation layer. Introduce centralized animation tokens and a short-lived closing state in `ProfileView` so the overlay can fade its content out while the card background returns to the grid smoothly.

**Tech Stack:** SwiftUI, matchedGeometryEffect, interactiveSpring, Swift concurrency `Task.sleep`, NotificationCenter.

---

### Task 1: Add explicit animation state for expanded card lifecycle

**Files:**
- Modify: `WhatToEat/ProfileView.swift`

**Step 1: Add local overlay lifecycle state**
- Add a `closingExpandedCardId` state alongside the existing `expandedCardId` source.
- Add a dedicated hero animation token for expand/collapse.

**Step 2: Route overlay rendering through active-or-closing card id**
- Render `ExpandedCardOverlay` when either the live expanded card or a closing card exists.
- Pass an `isClosing` flag into the overlay.

**Step 3: Add an explicit close request method**
- Animate `expandedCardId` back to `nil`.
- Keep the closing overlay alive for one animation beat, then clear `closingExpandedCardId`.

### Task 2: Rework `ExpandableCard` tap feedback to remove split timing artifacts

**Files:**
- Modify: `WhatToEat/ExpandableCard.swift`

**Step 1: Centralize animation tokens**
- Define press, hero, settle, and backdrop animations in one place.

**Step 2: Replace `DispatchQueue.main.asyncAfter` press timing**
- Use `Task.sleep` and unified animation tokens.
- Keep the press feedback subtle so it does not fight the hero transition.

### Task 3: Rebuild expanded overlay presentation choreography

**Files:**
- Modify: `WhatToEat/ExpandableCard.swift`

**Step 1: Separate geometry from content choreography**
- Remove idle `cardScale` / `cardYOffset` entrance transforms so matched geometry owns the frame morph.
- Keep drag-driven offset/scale only while dragging.

**Step 2: Add staged header/content animation**
- Fade and slightly offset the header and detail content in after the card frame lands.
- Fade them out immediately on close before removing the overlay.

**Step 3: Improve backdrop timing**
- Use a softer backdrop fade in/out.
- Disable hit testing while closing.

### Task 4: Validate behavior and document outcome

**Files:**
- Modify: `docs/plans/2026-03-07-dashboard-card-fluid-animation.md`

**Step 1: Run a build smoke test**
- Use the existing `xcodebuild` command.
- Record whether any issues are code-related or environment-related.

**Step 2: Summarize subjective validation points**
- Verify repeated open/close gestures do not jitter.
- Verify content no longer appears to “pop in” ahead of the card frame.
