# iOS DateTime Picker UI Redesign (iOS 26+)

## Overview

The iOS bottom sheet picker has been redesigned from a keyboard-matched aesthetic to a modern **system overlay popup** style. This creates a more contemporary, focused modal experience suitable for iOS 26+ while maintaining all existing interaction behavior.

## Visual Changes

### 1. **Backdrop & Blur Effect**
- Added `UIBlurEffect(style: .dark)` behind the entire sheet
- Semi-transparent dark overlay (`RGBA(0,0,0,0.4)`) to create depth and focus
- No longer uses a clear backdrop — now has atmospheric weight like modern iOS modals

### 2. **Sheet Background**
- **Old**: Keyboard-matched colors (`RGB(209,212,217)` light / `RGB(44,44,44)` dark)
- **New**: Dark surface `RGBA(30,30,32,0.95)` consistent across modes
- Corner radius increased from `12` to `16` for modern iOS design language

### 3. **Toolbar**
- Matches sheet background for visual cohesion
- Added **hairline divider** (`RGBA(80,80,80,0.3)` dark / `RGBA(200,200,200,0.3)` light) below the toolbar to suggest structure without harshness

### 4. **Picker Wheel Area**
- Slightly darker background (`RGBA(40,40,42,1.0)`) than the toolbar for depth separation
- Set on a `datePickerContainer` wrapper (not the `UIDatePicker` itself), which stretches to the sheet's bottom edge; the picker inside is inset only from the container's safe-area bottom
- The safe-area gap below the picker (home-indicator area) is filled by the same container color — no separate bar, no visible seam
- Creates visual hierarchy: toolbar → divider → picker (color bleeds into safe-area gap)

> **Revision**: An earlier version of this change added a separate 12pt "bottom strip" bar in the keycap color (`RGB(106,106,106)` dark / `RGB(255,255,255)` light) to fill the safe-area gap. On dark mode this rendered as a visibly brighter grey bar against the darker sheet — reported as a stray "light grey bar," not an anchor — and was removed in favor of the container-color approach above.

## Why This Design

| Aspect | Keyboard-Matched | System Overlay |
|--------|------------------|-----------------|
| **Context** | Keyboard accessory feel | Focused modal choice |
| **Backdrop** | Invisible, no dim | Blurred + semi-transparent |
| **Depth** | Flat, single-color areas | Layered surfaces with dividers |
| **Modern feel** | Historical accuracy | Contemporary iOS 26+ language |
| **Visual anchors** | Single color throughout | Divided zones, picker color bleeds into safe area |

The new design signals "this is a deliberate choice moment" rather than "this is like typing." It's consistent with Settings, Photos, Music, and other iOS 26+ native modals.

## Implementation Details

### Files Changed
- `ios/DTPickerBottomSheetController.swift` — added blur, updated colors, added divider, wrapped picker in a color-bleeding container
- `docs/adr/0005-keyboard-matched-sheet-chrome.md` — updated decision record

### Key Additions
1. **Blur + Overlay Layers** in `viewDidLoad()`:
   ```swift
   let blurEffect = UIBlurEffect(style: .dark)
   let blurView = UIVisualEffectView(effect: blurEffect)
   let overlayView = UIView()
   overlayView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.4)
   ```

2. **Hairline Divider** in `makeToolbar()`:
   - 1pt line with adaptive color (0.3 alpha for subtlety)
   - Separates toolbar from picker without visual weight

3. **Picker container** in `viewDidLoad()`:
   - `datePickerContainer` wraps `datePicker`, colored `RGBA(40,40,42,1.0)`, stretching to `sheetView.bottomAnchor`
   - `datePicker` itself is inset only from `datePickerContainer.safeAreaLayoutGuide.bottomAnchor`, so the safe-area gap below it shows the container's own color — no separate bar

### Color Constants
- `overlayBackgroundColor`: Semi-transparent dark for backdrop
- `dividerColor`: Subtle separator (0.3 alpha, adaptive)

## Behavior (Unchanged)
- Swipe-to-dismiss still works (pan gesture threshold: 80pt or 500pt/s velocity)
- Tap-to-cancel on backdrop still works
- Animation timing and curve unchanged (`0.25s`, keyboard curve `7 << 16`)
- All date constraints and timezone handling unchanged

## Testing Notes
- TypeScript builds clean ✓
- Nitrogen (Nitro codegen) runs clean ✓
- Swift compilation: No DTPickerBottomSheetController errors (build environment warnings are from transitive Expo dependencies, not our code) ✓

## Future Considerations
- The blur style is locked to `.dark` for now; consider `.extraLight` or `.light` alternatives if app gains light-theme-first option
- RGB values are empirical snapshots of iOS 26's design language; future iOS versions may require updates

## Addendum: `cancelText`/`confirmText` removed (public API)

As a follow-up to this redesign, `cancelText`/`confirmText` were removed entirely from `PickOptions`, the Nitro boundary, and both native implementations — not just restyled. Grilled with the user first (see `mattpocock-skills:grilling` session) since this touches the public API.

**Why**: iOS 26's Liquid Glass auto-renders `UIBarButtonItem(barButtonSystemItem: .cancel/.done)` as icons (✕/✓) when no custom title is given, but a custom-titled item never gets that treatment on any iOS version. Keeping the override meant a caller who set `confirmText: "Submit"` would see that text looking inconsistent next to otherwise icon-styled chrome — a real "I set X, I get drift depending on OS version" problem, not acceptable for a prop whose contract is "show this exact text." Full removal (both platforms, not iOS-only) was chosen over trying to carry the override forward with a new guarantee, since the package was unpublished (no git tags, 404 on npm) — a clean breaking change with zero existing consumers to carry compatibility for.

**What changed**:
- `src/PickMode.ts` / `src/DatetimePickerPrompt.nitro.ts` — fields removed from `PickOptions`/`NitroPickOptions`
- `ios/DatetimePickerPrompt.swift` / `ios/DTPickerBottomSheetController.swift` — no more `cancelText`/`confirmText` params; toolbar always uses system items
- `android/.../DatetimePickerPrompt.kt` — `applyButtonLabels()` removed; dialogs always use native OS-default button labels
- `docs/design/dtpicker-api.md`, `docs/adr/0006-...md`, `README.md` — updated to document the removal and reasoning
- Nitrogen codegen regenerated (`yarn nitrogen`) to match the trimmed `NitroPickOptions` struct
