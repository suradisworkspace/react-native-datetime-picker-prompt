# iOS picker is a custom bottom sheet; Android chains native dialogs

iOS has no native "prompt" chrome for `UIDatePicker` (no built-in Confirm/Cancel), so the library builds a custom bottom sheet that slides up like the keyboard, with a toolbar (Cancel left / Done right) above a `.wheels`-style `UIDatePicker`, used for all three `PickMode`s. Android has native `DatePickerDialog`/`TimePickerDialog` with built-in OK/Cancel, so it uses those directly with OS-default styling — for `datetime` mode, it opens `DatePickerDialog` then `TimePickerDialog` in sequence, since Android has no single combined native widget.

Because `datetime` mode on Android is two separate native dialogs, there's a possible partial state: the user confirms the date, then cancels the time step. We chose to collapse that to the same outcome as a full Cancel (`pick()` resolves `null`) rather than returning a result with a defaulted time, so "Cancel always means null" (ADR 0001) holds everywhere, with no mode-dependent exception a caller needs to remember.

This also means the two platforms present visually different pickers (iOS: bottom sheet; Android: native dialog(s)) rather than a pixel-matched custom widget on both — a deliberate choice to lean on each platform's native idioms instead of building and maintaining a from-scratch cross-platform picker UI.
