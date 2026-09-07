# Aubade

A finite, personal morning edition for iPhone: obligations first, then a small edit of the
world and something curious to enjoy. Private analysis stays on the device.

## Layout

- `core/` — `AubadeCore`, a Swift package holding all the logic: obligations, sources, the
  edition pipeline, news, the cultural slot, and storage. Built and tested on a hosted
  macOS runner, so it can be developed from Windows without a Mac.
- `native-trial/` — a minimal SwiftUI app used to prove the build-and-install loop. Not the
  product.
- `PRODUCT-DECISIONS.md` — the agreed design, and what has actually been verified rather
  than assumed.

## Rules the code enforces

These are decisions, not implementation details, so they are held in place by tests:

- Deadlines come only from source data. An undated item is never guessed into urgency.
- Stated facts and inferred guesses are kept apart. A guess is shown as a candidate to
  check, never asserted as an obligation.
- Reading is not handling. State changes only on an explicit action, and survives the next
  fetch, because a source has no idea you dealt with something.
- Compression may defer non-urgent work, but never anything overdue or due within 48 hours.
- **An edition may only say you are caught up when every source actually answered.** Finding
  nothing is not the same as there being nothing, so a failed sync produces a named notice
  rather than false reassurance.
- Exports default to public sections only, assembled as a whitelist rather than filtered,
  so an obligation cannot leak into a file that leaves the phone.
- Stored mornings expire after 30 days. Explicitly saved items are public by type and
  outlive that window.

## Working on it

```bash
cd core && swift test
```

Without a Mac, push instead: the **Core tests** workflow runs the same suite on a macOS
runner in about a minute. That is the development loop this project is built around.

The **Build iOS trial IPA** workflow produces an unsigned `.ipa` for the install trial.

## Status

Core logic for v1 is complete and tested. Not yet done: the SwiftUI interface, which is
waiting on Penpot designs, and the mail clients, which are waiting on the school-email
consent question in `PRODUCT-DECISIONS.md`.

Installation is currently blocked upstream: AltServer cannot authenticate with Apple
([altstoreio/AltStore#1781](https://github.com/altstoreio/AltStore/issues/1781)). Nothing
in this repository can fix that; the alternatives are recorded in the decisions file.

Keep this repository code-only. Never commit OAuth tokens, email exports, provisioning
profiles, certificates, device identifiers, or screenshots containing personal data.
