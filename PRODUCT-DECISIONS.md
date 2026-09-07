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

## Source access findings

Quercus: settled. `q.utoronto.ca/api/v1/` is a live Canvas REST API answering
`WWW-Authenticate: Bearer realm="canvas-lms"`. A personal access token generated at
Account > Settings gives read access; `/api/v1/planner/items` returns assignments and
deadlines across all courses in one call. No university approval needed. This is the same
route StudyCadenza uses.

Personal Gmail: accessible. Thunderbird already authenticates against `imap.gmail.com`
with OAuth2. Prefer the Gmail REST API over IMAP so no C++ IMAP library is needed on iOS.
Note the trap: an OAuth app left in "Testing" publishing status has refresh tokens that
expire every seven days. Set the project to production and accept the unverified-app
warning, which is fine under 100 users.

School email: at risk. IMAP itself is open - Thunderbird connects to
`outlook.office365.com:993` with OAuth2 and Exchange answers - so the protocol is not
blocked. The tenant is `78aac226-2f03-4b4d-9037-b46d56c55210`, federated to UofT's own
ADFS at `sts.ad.utoronto.ca`. The risk is consent, not protocol: UofT runs a formal review
for third-party apps integrating with University Microsoft 365 accounts, including an
Application Review Committee and risk assessment, and the request route is documented for
staff and faculty rather than students. A personal hobby app is unlikely to pass. Thunderbird
works because Mozilla is a verified publisher, which tells us nothing about an unverified app.

Planned fallback if consent is refused: forward UTmail+ to Gmail with "keep a copy"
enabled, and label the forwarded mail with a Gmail filter so the edition can still say
which obligations came from school. This needs no university approval and collapses two
OAuth integrations into one. The cost is that school mail is then read through Google, and
the university warns that forwarding can delay mail - keeping a copy in UTmail+ means
nothing is lost, but the edition must still show school mail as a distinct source.

## News sourcing

Apple News+ cannot be a source. The Apple News API is a publishing interface for
publishers pushing Apple News Format articles to their own channel; there is no read API,
no way to fetch News+ content, and no way to enumerate what a subscriber can see. A shared
family subscription does not change this. Apple News stays a separate reading destination.

Licensed library databases are not a source either. UofT provides Factiva, ProQuest
Canadian Newsstand, CBCA and similar through library.utoronto.ca, but these sit behind
Shibboleth/EZproxy and their licences prohibit systematic or automated downloading.
Harvesting them from a personal app would breach the licence and put the user's library
account at risk. They are for the user to read, not for the app to collect.

The resulting shape: the edition surfaces and links; the user's own subscriptions do the
reading. Headlines and abstracts come from free, public, key-based APIs and RSS, and the
link opens wherever the user actually has access - Apple News, a library database, or the
open web. This keeps the app inside every licence while still being useful to someone with
generous subscriptions.

Verified reachable (probed, not assumed):
- CBC top stories RSS - 200, no key. Canadian slot.
- Globe and Mail category RSS - 200, no key.
- Guardian Open Platform - live results, free developer key, rich metadata. World slot.
- NYT Top Stories - free developer key required.
- The Varsity (UofT student paper) - 200, no key. A student-specific option.

Because news is public content, it may be processed off-device, unlike email and
coursework. This is the one part of the pipeline not bound by the on-device rule.

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
