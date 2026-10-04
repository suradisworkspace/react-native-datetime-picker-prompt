# PickMode is a public TS enum, but the Nitro boundary uses a raw string-literal union

The public API exposes `PickMode` as a real TypeScript `enum` (`PickMode.Date = 'date'`, etc.) with a derived union type (`` `${PickMode}` ``) so callers can pass either `PickMode.Date` or the raw string `'date'`. The `.nitro.ts` spec file that Nitro Modules uses to generate the Swift/Kotlin boundary, however, declares the same parameter as a plain string-literal union (`'date' | 'time' | 'datetime'`), not the `enum` keyword.

This split is required, not a style choice. Nitro's codegen only understands string-literal unions for cross-language enums in `.nitro.ts` — the `enum` keyword isn't its documented pattern there (nitro.margelo.com/docs/types/typing-system). A real TS `enum` also wouldn't let the public API accept bare strings anyway, since TS string enums are nominally typed and don't accept raw string literals without a cast. Using `enum` + a template-literal-derived union in the public layer, and a plain union at the Nitro boundary, is the only combination that satisfies both constraints at once.

A future engineer "simplifying" this by putting the same `enum` directly in `.nitro.ts`, or dropping the public `enum` for a bare union, will hit one of these two constraints — hence recording it here.
