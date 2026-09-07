# Aubade

Aubade is a finite, personal morning edition for iPhone: obligations first, then a small edit of the world and something curious to enjoy. Private analysis is intended to stay on the device.

This repository currently contains the native installation trial. It deliberately has no email, Quercus, news, analytics, credentials, or third-party dependencies. The trial proves the cheapest development loop before we build the actual edition.

## Build the iPhone trial from Windows

The repository includes a GitHub Actions workflow that builds on a hosted macOS runner. Run it manually from the **Actions** tab, or push a change under `native-trial/`. Download the `AubadeTrial-unsigned-ipa` artifact from the completed run, then sign and install it with AltServer on Windows (hold Shift and click the AltServer tray icon to reveal "Sideload .ipa…").

GitHub Actions does not receive your accounts or phone data. The workflow only compiles the checked-in source. Keep this repository code-only; never commit OAuth tokens, email exports, provisioning profiles, certificates, or screenshots containing personal data.

## Install and test

Follow [native-trial/README.md](native-trial/README.md). The current trial checks offline launch, local storage, export, and persistence after re-signing. Free Apple-account signing expires after seven days, so the app must be re-signed from your Windows laptop. See the trial README for why this route is a poor long-term fit.

## Product direction

The agreed product decisions are recorded in [PRODUCT-DECISIONS.md](PRODUCT-DECISIONS.md). They are a design record, not a promise that every integration has been proven.
