# Aubade native installation trial

A small Swift + SwiftUI iPhone app used to prove the build-and-install loop before any real
product code exists. It contains no account credentials, network code, analytics, or
third-party packages. Minimum deployment target: iOS 17.

## Build: GitHub Actions (no Mac required)

The macOS build runs in CI. You do not need a Mac or a friend's laptop.

1. Push a change under `native-trial/`, or open **Actions → Build iOS trial IPA → Run workflow**.
2. Wait for the run to finish (~1 minute).
3. Download the `AubadeTrial-unsigned-ipa` artifact, or fetch it from the command line:

   ```bash
   gh run download --repo 12g3nd/aubade --name AubadeTrial-unsigned-ipa
   ```

The result is an unsigned, arm64 `.ipa`. It cannot be installed by tapping it on the iPhone.
Windows signs it in the next step.

## Install: AltServer on Windows

Sideloadly is not used. It failed to launch on this machine and was removed. AltServer can
sideload an `.ipa` directly, without installing the AltStore app first.

Prerequisites, all already satisfied on this laptop:

- iTunes and iCloud installed from **apple.com**, not the Microsoft Store.
- Apple Mobile Device Service and Bonjour Service running.
- iPhone connected by USB, unlocked, and trusted.

Steps:

1. Make sure AltServer is running (its icon lives in the Windows tray overflow, under the `^`).
2. Hold **Shift** and click the AltServer tray icon. Holding Shift is what reveals the hidden
   **Sideload .ipa…** entry; without it you only get "Install AltStore".
3. Choose **Sideload .ipa…**, then pick the `.ipa`.
4. Select your iPhone.
5. Sign in with your own Apple account when AltServer asks. AltServer needs Apple
   authentication to obtain a free development certificate. Enter these credentials only into
   AltServer's own window; never put them in this repository, a chat, or a build log.
6. On the iPhone: enable **Settings → Privacy & Security → Developer Mode** and restart if
   prompted, then trust the certificate under **Settings → General → VPN & Device Management**.
7. Open **Aubade Trial**.

## The seven-day limit

Free Apple accounts sign apps for seven days. After that the app refuses to launch until it is
re-signed. AltServer's direct sideload does not refresh automatically, so this route means
re-running the steps above weekly, with the phone connected to this laptop.

That is acceptable for a trial and a poor fit for a daily-use morning app. If this trial passes,
move to on-device refresh (SideStore) or a paid Apple Developer membership before building the
real product. See the note in `../PRODUCT-DECISIONS.md`.

Keep the same signing account and bundle identifier, and do not uninstall the app during the
persistence trial. Re-signing preserves app data; uninstalling clears it, which would also clear
any future OAuth tokens. The bundle identifier is `app.aubade.trial`.

## Trial results to report

- Did AltServer sign and install it, and does it launch? Record iOS and AltServer versions on failure.
- Tap **Save a test marker**. Close and reopen the app. Is the same marker visible?
- Enable airplane mode. Does the app still launch?
- Tap **Export marker**, save the text to Files through the share sheet, and confirm it reads back.
- Re-sign the same IPA without uninstalling. Is the same marker still visible? This is the
  question that matters most: it decides whether weekly re-signing would log you out of your
  email accounts every seven days.

## Verification status

Build verified: CI produces a valid arm64 Mach-O executable with a correct `Info.plist`
(`MinimumOSVersion` 17.0, `CFBundleSupportedPlatforms` iPhoneOS, `UIDeviceFamily` 1).

Not yet verified: signing, installation, launch on device, and data retention after re-signing.
This trial establishes nothing about Gmail, university mail, Quercus, or on-device model quality.

References: [AltStore FAQ](https://faq.altstore.io/), [direct sideloading announcement](https://x.com/altstoreio/status/1521570699361472512), [Apple Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account).
