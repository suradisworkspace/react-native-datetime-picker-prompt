# DTPicker.pick() resolves null on Cancel, rejects only for real failures

`DTPicker.pick()` is Promise-based. When the end user cancels (Cancel button, backdrop tap, or swipe-down) the promise resolves with `null` rather than rejecting. Rejection is reserved for genuine failures — a second concurrent `pick()` call while one is already open, or a native error such as no active Activity/window — and carries a `code` field so callers can distinguish failure reasons without string-matching a message.

We considered rejecting on Cancel too (treating any non-confirmed outcome as an error), but that forces every caller to wrap a normal, expected user action in a try/catch alongside genuine bugs. Resolving `null` keeps "the user said no" and "something broke" distinguishable at the call site: `if (!result) return;` vs. `catch (e) { ... }`.

This is hard to reverse once consumers exist — flipping Cancel to a rejection later is a breaking change at every call site.
