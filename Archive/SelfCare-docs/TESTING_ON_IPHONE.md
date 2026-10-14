# Test Self Care on your iPhone

## What you need

- A Mac with Xcode 16 or newer. This project was verified with Xcode 26.6.
- An iPhone running iOS 17 or newer.
- Your Apple Account added in Xcode. Your selected development team must support the HealthKit capability.
- A USB cable for the first connection. Wireless running can be enabled afterward.

## 1. Open the Xcode project

1. In Finder, open the `SelfCare` folder.
2. Double-click `SelfCare.xcodeproj`.
3. Wait for Xcode to finish indexing.
4. At the top of Xcode, confirm the selected scheme says **SelfCare**.

Open the blue **SelfCare** project item in the left sidebar if you need to see its settings. Do not create a new project or copy the Swift files into another template.

## 2. Set your signing team

1. Click the blue **SelfCare** project item in the left sidebar.
2. Under **TARGETS**, select **SelfCare**.
3. Open **Signing & Capabilities**.
4. Turn on **Automatically manage signing**.
5. Choose your Apple Account or **Personal Team** in the **Team** menu.

Confirm that **HealthKit** appears in the target’s capabilities list. It is already configured in the project; Xcode will create or update the development provisioning profile for the selected team.

The included bundle identifier is `com.vansedita.SelfCare`. If Xcode says it is unavailable, change it to a value unique to you, such as `com.yourname.SelfCare`.

If your Apple Account is not listed, open **Xcode > Settings > Accounts**, press **+**, sign in, and return to Signing & Capabilities.

## 3. Prepare your iPhone

1. Unlock the iPhone and connect it to the Mac by cable.
2. Tap **Trust** if the iPhone asks whether to trust the computer, then enter the iPhone passcode.
3. In Xcode, open **Window > Devices and Simulators** and select the iPhone.
4. Wait until Xcode says the device is ready. The first preparation can take several minutes.
5. If asked to enable **Developer Mode**, open **Settings > Privacy & Security > Developer Mode** on the iPhone, turn it on, and restart the phone when prompted.

Keep the iPhone unlocked during the first install.

## 4. Build and run

1. Use the device menu at the top of Xcode to select your connected iPhone instead of a simulator.
2. Press the triangular **Run** button or press **Command-R**.
3. Xcode will build, install, and open **Self Care** on the iPhone.

If the phone reports an untrusted developer, open **Settings > General > VPN & Device Management**, select your Apple Account under Developer App, and trust it. Then run the app again.

With a free Personal Team, the development install may expire after about seven days. Reconnect the phone and press Run again to refresh it.

## 5. Connect Apple Health

1. Open **Self Care Settings** with the gear button.
2. Tap **Connect Apple Health**.
3. In Apple’s permission sheet, allow **Exercise Time** and **Sleep Analysis**, then tap **Allow**.
4. Separately enable **Save check-in mood to State of Mind** and allow write access when prompted.
5. Return to Self Care. Exercise and sleep should show the most recent readable values when their entry method is **Apple Health**.
6. If you add or change data in the Health app, return to Self Care. It refreshes on foreground; you can also tap **Refresh Apple Health**.

State of Mind export requires iOS 18 or later. On iOS 17, check-ins still remain safely stored in Self Care but cannot be sent to Apple Health.

Apple deliberately does not reveal whether an individual read permission was denied. Consequently, **No readable data** can mean access was declined or that the phone has no matching Exercise Time or Sleep Analysis samples.

## 6. Test the prototype interactions

Use this checklist on the phone:

1. On a clean install, confirm the app opens directly to the full check-in panel with no custom splash, delayed navigation, or Health permission prompt.
2. Drag the mood thumb from Low to Great and confirm the label and card tint change.
3. Tap **Exercised**, **Slept well**, and **No scrolling**. Confirm each chip gains or loses its checkmark and the score badge changes.
4. Long-press each factor chip. Confirm its setup sheet appears.
5. For Exercise and Sleep, switch between **Apple Health** and **Manual**. Confirm Health values are read-only and manual values remain editable.
6. Confirm Scrolling only offers manual entry.
7. Tap the gear, switch Light/Dark appearance, and edit each factor from Settings.
8. Tap a blank area outside the card to move from full to compact, then tap outside again to move to minimal. Confirm controls inside the card do not minimize it.
9. Tap the logo or minimal capsule and confirm the Home control restores the full check-in panel.
10. Add a manual custom category, relaunch, and confirm it persists. Repeat with an optional supported Apple Health mapping and deny access to confirm manual fallback remains usable.
11. In Settings, switch between **Open manually** and **Remind me daily**. Confirm the time picker, permission status, one scheduled reminder, time updates, and removal in manual mode.
12. With mood export off, tap **Log check-in** and confirm no Health permission sheet appears. Then enable mood export in Settings and confirm a later check-in is written to State of Mind.
13. Open **Settings > History**. Confirm the new entry contains the captured mood, factor values, date, and Apple Health status.
14. Open **Health > Browse > Mental Wellbeing > State of Mind** and confirm the mood entry appears.
15. Log another check-in and confirm both momentary check-ins appear newest-first.
16. In Settings, export History as CSV and inspect the shared file. Then cancel a data reset and confirm nothing changed.
17. Force-quit and reopen the app. Mood, theme, factor modes, manual values, and check-in history should remain saved for the same local day.
18. Turn on VoiceOver and verify Mood announces a numeric/semantic value and adjusts with swipe up/down; each factor announces Goal met/not met.
19. Repeat the core flow in Light and Dark appearance, Reduce Motion, and the largest Accessibility text size.

## 7. Run the automated tests

Select an iPhone simulator in Xcode and press **Command-U**. Xcode’s Test navigator should show 17 passing model tests.

You can also run the test suite from Terminal while inside the `SelfCare` folder:

```sh
xcodebuild test \
  -project SelfCare.xcodeproj \
  -scheme SelfCare \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

If that exact simulator is not installed, choose any available iPhone simulator shown by Xcode.

## 8. Enable wireless running later

1. Keep the iPhone connected by cable.
2. Open **Window > Devices and Simulators** in Xcode.
3. Select the iPhone and enable **Connect via network**.
4. After the network icon appears next to the device, disconnect the cable.

The Mac and iPhone must be on the same network, and the phone must remain available to Xcode.

## Common fixes

- **Signing requires a development team:** choose your team in Signing & Capabilities.
- **Bundle identifier unavailable:** replace `com.vansedita.SelfCare` with a unique reverse-domain identifier.
- **Device is locked or busy:** unlock it, leave it on the Home Screen, and wait for device preparation to finish.
- **Developer Mode disabled:** enable it under Settings > Privacy & Security and restart the phone.
- **iOS version is too old:** use an iPhone on iOS 17 or later, or lower the deployment target and replace unsupported APIs.
- **CoreSimulator is out of date:** install available macOS/Xcode updates and restart the Mac. This affects simulator tests but does not prevent a direct physical-iPhone build.
- **App opens but shows old values:** delete Self Care from the phone and run again to clear its local test data.
- **HealthKit capability or provisioning error:** confirm HealthKit is listed under Signing & Capabilities and choose a development team that can provision the entitlement.
- **No readable Health data:** open the Health app, verify Exercise Time or Sleep Analysis contains recent data, then open **Settings > Privacy & Security > Health > Self Care** and check access before refreshing.
- **Check-in says it was not saved to Apple Health:** on the iPhone, open **Settings > Privacy & Security > Health > Self Care** and enable State of Mind write access. The check-in remains in Self Care, and its detail screen offers **Retry Apple Health**.
