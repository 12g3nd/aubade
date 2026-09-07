# Aubade: agreed direction

## Reader and experience

- Personal app for one reader; iPhone 16 Pro first.
- Native iPhone experience. Swift + SwiftUI is the current direction; no web wrapper.
- Finite morning edition, approximately ten minutes, focused first on catching obligations.
- Prepare on opening. Previously prepared material must be clearly dated.
- Main morning check after a week comparing it against original sources.
- Compress busy days: explain top priorities and retain a compact list of near-term deadlines. Reduce news before removing the enjoyable cultural element.

## Sources and behavior

- Personal Gmail, university email, and Quercus. No calendar integration initially because no calendar is actively maintained.
- Read-only source integrations. Save, Handled, Snooze, and incorrect-reminder feedback affect only Aubade.
- Prefer extra reminders over silently missing obligations. Show uncertainty and source evidence.
- Show overdue work and deadlines within 48 hours. Scan 14 days ahead for tentative start suggestions. Unknown submission state must not be mistaken for confirmed overdue work.
- Tentative assignment effort estimates can be corrected. No invented precise durations or claims about free time.
- Three news stories: Canadian, world, flexible, with exceptions for major events.
- One poem or cultural selection, one weird website, fixed game links. Rotate quotes and facts through the cultural selection.
- Publish partial editions with prominent, source-specific failure and last-success information. Never declare the reader caught up when required sources failed.

## Privacy, cost, and history

- Private analysis stays on the iPhone. No cloud fallback for private content.
- If local inference is inadequate, use exact deadlines, excerpts, and clearly labeled conservative rules.
- Target zero recurring cost.
- Retain 30 days of editions in the app; explicit exports provide a permanent archive.
- Exports offer full edition or public sections only, with public sections initially selected. No credentials or raw email exports.
- Keep fetched private content only as needed for processing and active reminders; preserve explicitly saved items.

## Interface

The UI is to be designed in Penpot before it is built in SwiftUI. Screens are drawn and
agreed there rather than being discovered in code, so the SwiftUI layer stays a
transcription of an approved design instead of an accumulation of ad-hoc views.

This matters more than usual here: the app cannot currently be installed on the phone, so
there is no way to judge feel by holding it. Penpot is the only place the visual design can
be settled until installation is unblocked. Keep SwiftUI views thin until then.

## Current feasibility gate

The friend's Mac is no longer available, and Sideloadly failed to launch on Windows and was removed. The build now runs on a GitHub Actions macOS runner at no cost, and signing/installing is done by AltServer on Windows with a free Apple account. The next authorized step is a minimal native installation trial, not the full product.

Verified so far: CI compiles a valid arm64 iOS binary; the Windows environment (web iTunes/iCloud, Apple Mobile Device Service, Bonjour, USB pairing) is correctly configured. Unverified: signing, installation, and launch on the device.

Open decision, deferred until the trial passes: free-account signing expires every seven days, which fits a trial but not a morning app relied on daily. The candidates are on-device refresh (SideStore) or a paid Apple Developer membership. Do not build the full product on top of an install path that dies weekly.

Trial must establish device compilation, installation, offline launch, local persistence through re-signing, export, and refresh practicality. Account authorization, university restrictions, Quercus access, local inference performance, and public-content sourcing remain unproven. Final product design is not complete; resume the interview around those branches after feasibility evidence.
