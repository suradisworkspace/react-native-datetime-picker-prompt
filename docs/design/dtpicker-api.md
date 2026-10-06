# DTPicker.pick() — implementation spec

Status: implemented (TS public API, Nitro boundary, iOS bottom sheet, Android chained dialogs). Compiled and smoke-tested on both platforms via the example app; see the `## Verification` section below.

See [`CONTEXT.md`](../../CONTEXT.md) for terminology (Pick, PickMode, Cancel, Dismiss, Result) and `docs/adr/0001`–`0008` for why these choices were made.

## Public API

```ts
export enum PickMode {
  Date = 'date',
  Time = 'time',
  DateTime = 'datetime',
}
type PickModeType = `${PickMode}`; // 'date' | 'time' | 'datetime'

export interface PickOptions {
  mode: PickModeType; // required — no default
  minimumDate?: string; // ISO 8601 UTC string — see ADR 0007
  maximumDate?: string; // ISO 8601 UTC string
  defaultValue?: string; // ISO 8601 UTC string — picker opens to this instead of "now"
  timezone?: string; // IANA identifier; omitted = device's current local timezone
  iosDisplay?: 'wheel' | 'inline'; // iOS only, default 'wheel' — UIDatePickerStyle.wheels/.inline
}

export const DTPicker: {
  pick(options: PickOptions): Promise<string | null>;
  dismiss(): void;
};
```

## Nitro boundary (`src/DatetimePickerPrompt.nitro.ts`)

```ts
export interface NitroPickOptions {
  mode: 'date' | 'time' | 'datetime';
  minimumDate?: string;
  maximumDate?: string;
  defaultValue?: string;
  timezone?: string;
  iosDisplay?: 'wheel' | 'inline';
}

export interface DatetimePickerPrompt extends HybridObject<{
  ios: 'swift';
  android: 'kotlin';
}> {
  pick(options: NitroPickOptions): Promise<string | null>;
  dismiss(): void;
}
```

Struct-based options (not positional params) — switched once the parameter count grew past a couple of fields. Plain string-literal union for `mode` within the struct, not the `PickMode` enum — see ADR 0003.

## Behavior

| Scenario                                                            | Outcome                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| User confirms a value                                               | Resolves a full combined-format ISO 8601 string, UTC (`Z`). Unused part (time for `'date'`, date for `'time'`) is defaulted — see ADR 0002.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| User cancels (Cancel button, backdrop tap, swipe-down)              | Resolves `null`. Never rejects for this case — see ADR 0001.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `dismiss()` called while a picker is open                           | Force-closes it; its pending promise resolves `null`, same as Cancel.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `dismiss()` called while nothing is open                            | No-op.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `pick()` called while one is already open                           | The **second** call's promise rejects with an `Error` carrying a `code` field (e.g. `E_ALREADY_VISIBLE`). The first call is unaffected.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| Native failure (e.g. no active Activity/window on Android)          | Rejects with an `Error` carrying a distinguishing `code`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| Android `'datetime'` mode: date confirmed, then time step cancelled | Whole call resolves `null` — not a partial result with a defaulted time. See ADR 0004.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Cancel/Done (iOS) and dialog buttons (Android)                      | Always the platform default — no `cancelText`/`confirmText` override exists. iOS: `UIBarButtonItem` system items, which render as localized text pre-iOS 26 and as icons (✕/✓) on iOS 26+ per Liquid Glass. Android: native dialog defaults, OS-localized. See ADR 0006.                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `minimumDate`/`maximumDate`/`defaultValue`/`timezone`               | Compared mode-aware (date-only / time-only / full-instant); `timezone` (IANA id) governs interpretation, omitted = device-local. `defaultValue` outside bounds is clamped into range. `minimumDate > maximumDate` or an unparseable date string rejects `E_INVALID_RANGE`; an unrecognized `timezone` rejects `E_INVALID_TIMEZONE`. Android has no native min/max-time API, so an out-of-range _picked_ time (not default) resolves as picked. See ADR 0007.                                                                                                                                                                                                                                                                     |
| `iosDisplay`                                                        | iOS only, no effect on Android. `'wheel'` (default) = `UIDatePickerStyle.wheels`; `'inline'` = `.inline` (calendar grid for the date portion, with month/year navigation). Applies to `'date'` and `'datetime'` modes and to both iOS controllers (pre-26 and 26+); addresses `'datetime'`'s `.wheels` + `.dateAndTime` combination showing the date as one hard-to-jump combined column rather than separate month/day/year wheels. **Ignored for `'time'` mode** — always `.wheels` there regardless of this value, since `.inline`'s calendar navigation doesn't apply to a time-only picker and visibly looked worse (direct feedback). See `NitroPickMode.resolvedDatePickerStyle` in `ios/DTPickerSheetPresentable.swift`. |

## Platform UI

**iOS**: Two separate controllers, picked at runtime via `if #available(iOS 26, *)` in `DatetimePickerPrompt.swift` — not a deployment-target split, both ship in the same binary. Both conform to `DTPickerSheetPresentable` so the HybridObject can hold either as `activeSheet`.

- **iOS <26** (`DTPickerBottomSheetController`): edge-to-edge bottom sheet, presented modally, slides up using the keyboard's own animation timing/curve (`0.25s`, keyboard curve). Fixed, content-hugging height (no drag-to-resize). No title/header. A real `UIToolbar` above the picker: Cancel (left) / Done (right), `UIBarButtonItem(barButtonSystemItem: .cancel/.done)`.
- **iOS 26+** (`DTPickerGlassSheetController`): a floating card (AirPods-pairing-popup style) instead of edge-to-edge — margins on every side, all four corners rounded (`cornerCurve = .continuous`). Real `UIGlassEffect(style: .regular)` material for the card's base surface, not a flat color. A compact action bar sits _above_ the picker (a button at the bottom of a tall floating card is a harder reach): a prominent capsule "Done" + a smaller de-emphasized "Cancel", both icon-only (`checkmark`/`xmark` SF Symbols) matching iOS 26's own Done/Cancel icon convention, `accessibilityLabel` still sourced from `UIBarButtonItem(...).title` so VoiceOver stays localized. Backdrop is a dim-only overlay (`RGBA(0,0,0,0.15)`), no blur. No header — tried and reverted; see ADR 0005.

Both controllers: `UIDatePicker` in `.wheels` style by default, or `.inline` via the `iosDisplay` prop for `date`/`datetime` modes — `time` mode always stays `.wheels` regardless of the prop (see behavior table above). Dismissible via Cancel button, backdrop tap, or swipe-down — all three resolve `null`. See ADR 0005 for the full redesign history and ADR 0006 for why Cancel/Done have no text override.

**Android**: Native `DatePickerDialog` / `TimePickerDialog`, OS-default theme/styling (no custom chrome). `date` mode → `DatePickerDialog` only. `time` mode → `TimePickerDialog` only. `datetime` mode → `DatePickerDialog` then, on confirm, `TimePickerDialog`; cancelling either dialog resolves the whole call `null` (see table above). Dialog buttons always use the OS's own default labels — no override exists.

## Explicit non-goals for v1

- No title/header prop (iOS-only concept, no Android equivalent, and no room in the bottom sheet layout).
- No wraparound (overnight) `minimumDate`/`maximumDate` ranges for `'time'` mode — see ADR 0007.
- No visual theming/style customization beyond `iosDisplay` — platform OS defaults otherwise (native Material dialog on Android, no equivalent style choice there).
- No queuing/stacking of concurrent `pick()` calls — the second call rejects immediately.
- No `cancelText`/`confirmText` override (removed; previously existed). iOS 26's Liquid Glass renders system Cancel/Done items as icons automatically, and a custom-titled button never gets that treatment on any iOS version — mixing an icon default with a text override reads as a bug, not a feature. Both platforms now always use the OS's own default button labels. See ADR 0006.

## Verification

- `yarn typecheck`, `yarn test`, `yarn lint` all pass against the TS layer (`PickMode.ts`, `DTPicker.native.ts`, `DTPicker.ts`, `index.tsx`).
- Both native platforms build clean as part of the example app: iOS via `xcodebuild` against the generated Nitro Swift protocol, Android via Gradle (`compileDebugKotlin` + `assembleDebug`) against the generated Kotlin spec.
- Smoke-tested on a real iOS Simulator and Android Emulator by launching the example app: both render the JS UI correctly with no native crash on launch (confirms autolinking/module registration works end-to-end).
- On Android, interactively verified via `adb shell input tap`: `'datetime'` mode correctly chains `DatePickerDialog` → `TimePickerDialog`; confirming both resolved a correct UTC ISO string (verified a local 11:20 device time converted to `...T16:20:00.000Z`, matching the device's UTC offset); Cancel on the date dialog correctly resolved `null`.
- Not verified: iOS bottom sheet interaction (no tap-automation tool was available for the iOS Simulator in the environment this was built in — only the Swift compiles and the app launches without crashing), and `dismiss()` specifically (the on-screen test button is visually covered by the modal native dialog, making it untappable in the Android test above — though it calls the same `.cancel()` path already verified via the Cancel button). Recommend a manual pass on-device for both before shipping.
- iOS keyboard-chrome parity (ADR 0005) was visually verified: a temporary auto-trigger harness (since reverted) focused a `TextInput` to capture the real system keyboard and opened the picker sheet, in both Light and Dark mode, on the same simulator. Pixel-sampled the real keyboard's background (`RGB(209,212,217)` light, `RGB(44,44,44)` dark) and confirmed the sheet now matches after switching from `UIInputView(.keyboard)` (which didn't render the keyboard material standalone) to explicit sampled colors. Did not re-verify backdrop-tap-to-cancel, swipe-to-dismiss, or Cancel/Done by tapping (same tap-automation gap as above) — these were reviewed by reading the code, which shows the tap gesture and button targets are unchanged.
- iOS localized Cancel/Done (ADR 0006): rebuild verified the `UIToolbar`/`UIBarButtonItem` migration renders correctly with no layout/color regression (English, light mode, screenshot-confirmed). Attempted to force the iOS Simulator into French (both per-process `-AppleLanguages` launch arguments and simulator-wide `defaults write -g AppleLanguages`) to visually confirm the translated text, but neither actually changed the simulator's rendered language — even `UIDatePicker`'s own native calendar labels stayed in English, confirming this is an environment/tooling limitation, not a code issue. Not re-attempted beyond that; `UIBarButtonItem(barButtonSystemItem:)`'s localization is long-standing, officially documented Apple API behavior, not a community workaround, so this is lower-risk to leave unverified than ADR 0005's curve/color values were.
- `minimumDate`/`maximumDate`/`defaultValue`/`timezone` (ADR 0007): verified end-to-end on both platforms via the example app's "Pick with bounds" and "Pick time in Asia/Tokyo" buttons. Android (tap-tested): `DatePicker.minDate`/`maxDate` correctly grayed out every day except the one in range; `defaultValue` ("now," intentionally out of range) was correctly clamped to `minimumDate` for the time step; picking in `Asia/Tokyo` from a device set to `Asia/Bangkok` produced the exact expected UTC conversion (9:46 PM Tokyo → `12:46:00.000Z`, a 9-hour offset). iOS (screenshot-verified, same clamping behavior): `defaultValue` clamped to exactly `minimumDate` (8:48 PM) when "now" fell outside the `[+1h, +2h]` window. Before implementing, also empirically confirmed — by temporarily forcing `.time` mode with a narrow `minimumDate`/`maximumDate` and observing the picker's own default value shift into range — that `UIDatePicker.minimumDate`/`.maximumDate` are honored in `.time` mode (older docs suggested otherwise; this was wrong, or no longer true).
