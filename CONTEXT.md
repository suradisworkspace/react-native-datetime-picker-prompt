# react-native-datetime-picker-prompt

A React Native library (built on Nitro Modules) that shows a platform-native date/time picker and resolves the value the user picked.

## Language

**Pick**:
The library's one verb for showing the picker and awaiting a result, via `DTPicker.pick()`.
_Avoid_: Prompt, show, open

**PickMode**:
Which part of a date/time the picker captures on a given call: `date`, `time`, or `datetime`. Passed as `options.mode` — there is no default, every call states it explicitly.
_Avoid_: type, variant, kind

**Cancel**:
The outcome when the *end user* closes the picker without confirming a value — via the Cancel button, tapping the backdrop, or swiping the sheet down. Resolves the pending `pick()` promise with `null`.
_Avoid_: Dismiss (reserved for the programmatic case below), abort, close

**Dismiss**:
A *programmatic* action (`DTPicker.dismiss()`) that force-closes an open picker from application code — e.g. because the screen that opened it unmounted. Resolves the pending promise with `null`, the same outcome as a Cancel, but is caller-initiated rather than user-initiated. Safe to call even when no picker is open.
_Avoid_: Cancel (reserve for the user-initiated case above)

**Result**:
The UTC ISO 8601 string `pick()` resolves with when the user confirms a value. Always a full combined date-and-time format regardless of `PickMode` — whichever part the user didn't pick is defaulted, and the caller is expected to ignore it.
_Avoid_: value, response, output
