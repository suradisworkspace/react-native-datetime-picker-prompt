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

Pass `cancelText` / `confirmText` to override the platform-default button labels:

```js
await DTPicker.pick({ mode: PickMode.Date, cancelText: 'Close', confirmText: 'Select' });
```

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

See [`docs/design/dtpicker-api.md`](docs/design/dtpicker-api.md) for the full behavior spec and [`docs/adr/`](docs/adr/) for the design decisions behind it.


## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
