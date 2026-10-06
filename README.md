# react-native-datetime-picker-prompt

A native date/time picker for React Native, built on [Nitro Modules](https://nitro.margelo.com/). Call `DTPicker.pick()` to show a platform-native picker and get back the value the user chose.

## Installation

```sh
npm install react-native-datetime-picker-prompt react-native-nitro-modules
```

> `react-native-nitro-modules` is required as this library relies on [Nitro Modules](https://nitro.margelo.com/).

## Usage

```js
import { DTPicker, PickMode, DTPickerError } from 'react-native-datetime-picker-prompt';

async function pickDateTime() {
  try {
    const result = await DTPicker.pick({ mode: PickMode.DateTime });
    if (result === null) {
      // user cancelled
      return;
    }
    console.log(result); // e.g. "2026-10-03T07:30:00.000Z"
  } catch (error) {
    if (error instanceof DTPickerError) {
      console.error(error.code, error.message);
    }
  }
}
```

`mode` is required and selects what the picker captures: `PickMode.Date`, `PickMode.Time`, or `PickMode.DateTime` (plain strings `'date'` / `'time'` / `'datetime'` also work). The result is always a full ISO 8601 string in UTC; cancelling resolves `null` rather than throwing.

Button labels always use the platform default — the device's localized Cancel/Done on iOS (rendered as icons on iOS 26+ per Apple's Liquid Glass design, text on earlier versions, automatically) and the native dialog's own defaults on Android. There's no `cancelText`/`confirmText` override; see [ADR 0006](docs/adr/0006-ios-cancel-confirm-localized-via-system-button-items.md) for why.

Call `DTPicker.dismiss()` to force-close an open picker from code (e.g. if the screen that opened it unmounts) — it resolves the pending promise with `null`, same as a user cancel, and is a no-op if nothing is open.

### Bounds, default value, and timezone

```js
await DTPicker.pick({
  mode: PickMode.DateTime,
  minimumDate: new Date().toISOString(),
  maximumDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(), // +7 days
  defaultValue: someDate.toISOString(),
  timezone: 'Asia/Bangkok', // optional — omit to use the device's current timezone
});
```

- `minimumDate` / `maximumDate` — ISO 8601 UTC strings, compared against only the part relevant to `mode` (date-only for `'date'`, time-of-day-only for `'time'`, full instant for `'datetime'`). `minimumDate` after `maximumDate` rejects with `DTPickerError` code `E_INVALID_RANGE`.
- `defaultValue` — ISO 8601 UTC string the picker opens to, instead of the device's current date/time. If it falls outside `[minimumDate, maximumDate]`, it's silently clamped into range rather than rejected.
- `timezone` — an IANA identifier (e.g. `'Asia/Bangkok'`). Governs interpretation of `minimumDate`/`maximumDate`/`defaultValue` *and* what the user picks, independent of the device's own timezone. Omit it to use the device's current local timezone. An unrecognized identifier rejects with code `E_INVALID_TIMEZONE`.
- **Android only**: there's no native API to constrain which *times* are selectable (unlike dates, which are fully enforced) — a user can pick a time outside `[minimumDate, maximumDate]` for `'time'` mode or the time-step of `'datetime'`. See [ADR 0007](docs/adr/0007-min-max-default-and-timezone.md) for why.

### iOS picker style

```js
await DTPicker.pick({ mode: PickMode.DateTime, iosDisplay: 'inline' });
```

- `iosDisplay` — `'wheel'` (default) or `'inline'`, maps to `UIDatePickerStyle.wheels`/`.inline`. **iOS only, no effect on Android** (`DatePickerDialog`/`TimePickerDialog` have no equivalent style choice). `'inline'` shows a calendar grid for the date portion instead of a scrolling wheel — useful for `'datetime'` mode in particular, since `.wheels` + `.dateAndTime` shows the date as one combined column (e.g. "Wed Nov 15") rather than separate month/day/year wheels, making it slow to jump to a date far from the default. **Ignored for `PickMode.Time`** — always renders as `.wheels` there, since `'inline'`'s calendar navigation doesn't apply to a time-only picker.

See [`docs/design/dtpicker-api.md`](docs/design/dtpicker-api.md) for the full behavior spec and [`docs/adr/`](docs/adr/) for the design decisions behind it.

## Troubleshooting

**App crashes on launch when built with Xcode 27 (iOS 27 SDK), with `EXC_BREAKPOINT` in `_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`.** This isn't caused by this library — `DTPicker`'s own iOS code already presents on the scene-based key window. It's Apple's new hard requirement (TN3187) that a host app adopt the `UIScene` lifecycle; apps that don't now fail to launch instead of just logging a warning. Fix it in *your* app:
- **Expo (SDK 57)**: add [`expo-build-properties`](https://docs.expo.dev/versions/latest/sdk/build-properties/) and set `ios.enableSceneSupport: true`, then `npx expo prebuild --clean`. See [ADR 0008](docs/adr/0008-ios27-scene-lifecycle-example-app.md) for what that changes and why a scene manifest alone isn't enough. SDK 58+ adopts the scene lifecycle by default and no longer needs the flag.
- **Bare React Native**: there's no official upstream fix yet as of this writing — see [facebook/react-native#54739](https://github.com/react/react-native/issues/54739) and [RFC #967](https://github.com/react-native-community/discussions-and-proposals/pull/967) (both open). Until one lands, you'd need to hand-roll a `SceneDelegate` or use a third-party shim.

## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
