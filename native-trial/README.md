# Aubade native installation trial

This is a small Swift + SwiftUI iPhone app to test remote Mac compilation, Windows sideloading, offline launch, and persistence after re-signing. It is not the morning briefing product. It contains no account credentials, network code, analytics, or third-party packages. Minimum deployment target: iOS 17.

## Your friend: build on a Mac

1. Extract this entire folder. Keep the project and source folders together.
2. Install full Xcode from Apple, open it, complete first-launch setup, and install the iOS platform when prompted. Command Line Tools alone are insufficient. No paid developer membership is needed for this unsigned build.
3. Open Terminal, type `cd `, drag the extracted `native-trial` folder into Terminal, and press Return.
4. Run:

   ```bash
   bash build-mac.sh
   ```

5. Finder should reveal `AubadeTrial-unsigned.ipa` in a new folder under `build`. Send that file back. It cannot be installed by tapping it on the iPhone; Windows signs it next.

The script creates a fresh build directory each time and doesn't delete previous builds. If it fails, send the error text and `build/run.*/build.log` back. Do not send Apple account passwords, certificates, or provisioning secrets. This trial needs none from the Mac owner.

Alternatively, open `AubadeTrial.xcodeproj` in Xcode and run it in an iPhone simulator to inspect the screen. A simulator build cannot be sideloaded onto the real phone; use the script for the device IPA.

## You: install from Windows

1. Download Sideloadly only from [sideloadly.io](https://sideloadly.io/). Follow its current Windows instructions for the required Apple components.
2. Connect your unlocked iPhone to your Windows laptop by USB and accept the phone's Trust prompt.
3. Select the phone in Sideloadly and choose the returned IPA.
4. Sign in with your own Apple account through Sideloadly. This third-party signing tool needs Apple authentication; do not send credentials to your friend or put them in this project/chat.
5. Enable automatic refresh and install. Follow the signing/developer-trust prompts. If required, enable Settings > Privacy & Security > Developer Mode and restart as directed. Trust the developer under Settings > General > VPN & Device Management if prompted.
6. Open **Aubade Trial**.

Free-account provisioning lasts seven days. Automatic refresh needs Sideloadly's helper running and a connection to your phone. Establish USB installation first; then follow Sideloadly's Wi-Fi pairing instructions if desired. If refresh is missed, the app may stop launching until re-signed. Your friend is needed for new code builds, not weekly re-signing of this same IPA.

Keep the same signing account and bundle identifier, and do not uninstall the app during the persistence trial. Re-signing should preserve app data; uninstalling clears it. The unsigned project's identifier is `app.aubade.trial`; preserve whatever stable mapping Sideloadly uses for your account.

## Trial results to report

- Did the Mac script produce an IPA? If not, what was the build error?
- Did Sideloadly install it, and does it launch on your iPhone? Record iOS and Sideloadly versions if there is a failure.
- Tap **Save a test marker**. Close and reopen the app. Is the same marker visible?
- Enable airplane mode. Does the app still launch?
- Tap **Export marker**, save the text to Files through the share sheet, and check it can be read.
- Re-sign/refresh this same IPA without uninstalling. Is the same marker still visible?
- Later, confirm automatic refresh succeeds before the seven-day deadline. One manual refresh alone doesn't prove unattended renewal.

## Verification status

Prepared on Windows. Swift compilation, iOS launch, export behavior, and signing/refresh remain unverified until this trial is run on the Mac and iPhone. The trial is intentionally dependency-free; it does not establish that Gmail, university mail, Quercus, or a local model will work yet.

References: [Sideloadly instructions](https://sideloadly.io/), [Sideloadly FAQ](https://sideloadly.io/faq), [Apple Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account).
