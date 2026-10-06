# iOS sheet chrome redesigned as a modern bottom popup (iOS 26+)

The iOS bottom sheet has been redesigned from the keyboard-matched style (ADR 0005 original) to a modern **system overlay bottom popup** aesthetic suitable for iOS 26+. This is a visual redesign, not a behavior change — the picker interaction (swipe-to-dismiss, tap-to-cancel, animation timing) remains identical.

## Visual changes

**Backdrop**: Semi-transparent dark overlay (`RGBA(0,0,0,0.4)`) with UIBlurEffect (`style: .dark`) behind the sheet, creating depth and focus without a full modal dim.

**Sheet background**: Dark surface `RGBA(30,30,32,0.95)` with increased corner radius (`16` instead of `12`) to match modern iOS design language.

**Toolbar + picker area**: Both use the same dark surface color for visual cohesion, separated by a subtle hairline divider (`RGBA(80,80,80,0.3)` dark / `RGBA(200,200,200,0.3)` light) to suggest structure without harshness.

**Picker wheel area**: Slightly darker background (`RGBA(40,40,42,1.0)`), set on a `datePickerContainer` wrapper rather than the `UIDatePicker` itself, for depth separation from the toolbar. The container stretches all the way to `sheetView`'s bottom edge; the picker inside it is inset only from the container's *safe-area* bottom. That makes the safe-area gap below the picker (home-indicator area) show the same container color rather than a seam.

An earlier version of this redesign added a separate 12pt "bottom strip" bar in the keycap color to fill that gap — on dark mode that rendered as a `RGB(106,106,106)` mid-grey bar, visibly brighter than the `RGBA(30,30,32)` sheet around it, which read as a stray bar rather than an anchor. Removed in favor of the container-color approach above, which has no visible seam at all.

## Why this approach

The keyboard-matched design (original ADR 0005) was historically accurate but visually limiting: it forced the sheet to look exactly like the system keyboard, which isn't a modal dialog but a keyboard accessory — different context, different design language. The new system overlay style signals "this is a focused modal choice," uses the darker surface typical of iOS 26+ modals (consistent with bottom sheets in Settings, Photos, Music), and the hairline divider reduces visual "flatness" that accumulated when all areas were the same color.

The blur backdrop (absent in the keyboard design) adds atmospheric depth; the semi-transparent overlay prevents the dimmed content from feeling too washed out while keeping the focus on the picker itself.

## Implementation notes

- `UIBlurEffect(style: .dark)` provides consistent blur across light/dark modes.
- The hairline divider uses a low-alpha color (0.3) to stay subtle and not compete with content.
- Animation curve and timing (`0.25s`, `UIView.AnimationOptions(rawValue: 7 << 16)`) remain unchanged from the keyboard-matched style.
- All colors are adaptive (`UIColor(traits in:)` closures), though the iOS 26 redesign targets dark-mode visuals primarily; light mode follows the same pattern with lighter surface/divider values.

## Future considerations

- The sampled RGB values are empirical snapshots of iOS 26's design language, not declared API. If future iOS versions shift the visual language, these constants may need updating.
- The blur style is locked to `.dark` for now; if the app gains a light theme option, consider `.extraLight` or `.light` as alternatives.
