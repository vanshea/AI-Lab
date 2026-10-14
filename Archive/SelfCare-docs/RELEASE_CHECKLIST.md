# Self Care 1.0 — release checklist

Do not upload until every blocker in `HUMAN_TODO.md` is resolved. Never upload or submit from this checklist automatically; the human owns the App Store Connect action.

## 1. Before archiving

- [ ] Confirm branch `release/1.0-prep` and inspect `git status`/diff.
- [x] Preserve bundle ID `com.vansedita.SelfCare`, team `W63L7RKS3T`, and automatic signing.
- [x] Confirm iPhone-only target, iOS 17.0 minimum, HealthKit capability, and portrait-only orientation.
- [x] Confirm version `1.0`, current build `4`, privacy manifest, usage strings, and export-compliance key in the built product.
- [ ] In App Store Connect, confirm build `4` is greater than every previously uploaded build for version 1.0. Increment `CURRENT_PROJECT_VERSION` for every new upload; never reuse an uploaded build number.
- [ ] Publish the privacy policy and support page/contact, replace the Settings placeholder, and verify public HTTPS links.
- [ ] Decide/resolve the one-way State of Mind reconciliation blocker and test it on device.
- [ ] Complete `TESTING_ON_IPHONE.md` and the HealthKit matrix in `HUMAN_TODO.md` on real hardware.
- [ ] Capture current-build screenshots at the current required display sizes and review them at 100% zoom.

## 2. Reproduce local engineering checks

Run from the repository root. `CODE_SIGNING_ALLOWED=NO` is appropriate for simulator QA only.

```sh
xcodebuild -project SelfCare.xcodeproj -scheme SelfCare \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/SelfCare-DerivedData CODE_SIGNING_ALLOWED=NO build

xcodebuild -project SelfCare.xcodeproj -scheme SelfCare \
  -configuration Release -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/SelfCare-DerivedData CODE_SIGNING_ALLOWED=NO build

xcodebuild test -project SelfCare.xcodeproj -scheme SelfCare \
  -destination 'platform=iOS Simulator,id=<choose-an-available-iPhone-ID>' \
  -derivedDataPath /tmp/SelfCare-DerivedData CODE_SIGNING_ALLOWED=NO test
```

Expected current results: Debug/Release builds succeed; 27 tests pass. Xcode emits its App Intents metadata-extraction warning because the app does not link AppIntents. Do not add an unused framework just to silence the warning.

## 3. Release archive and validation

The current local archive `/tmp/SelfCare-final.xcarchive` is unsigned and is for packaging QA only. It is not a distribution artifact. Recreate it after source or build-number changes.

In Xcode:

1. Open `SelfCare.xcodeproj`, select the shared `SelfCare` scheme, and select **Any iOS Device (arm64)**.
2. Confirm app target automatic signing, team `W63L7RKS3T`, and HealthKit capability. Confirm HealthKit is enabled for the App ID in the developer portal.
3. Choose **Product → Archive**. Use a new archive after every build-number change.
4. In Organizer choose **Validate App**. Resolve all signing/profile/metadata errors; do not change the bundle ID, team, or signing style to bypass them.
5. Confirm the signed app contains `PrivacyInfo.xcprivacy`, only the expected HealthKit entitlement, and the expected Info.plist values.
6. Do not distribute/upload until the real-device and App Store metadata gates below are complete.

## 4. Real-device and TestFlight sequence

- [ ] Clean install and first launch: no Health prompt until a related user action.
- [ ] Check-in: mood adjustment, factors, Yoga toggle-off after reselect, save, minimize panel, restore from logo, and verify one local History item.
- [ ] Check-in twice on the same day: two momentary entries, newest first; verify Health update/replacement behavior if mood export is enabled.
- [ ] Relaunch, cross local midnight, DST, and travel timezone; verify daily state resets once and history remains.
- [ ] Health unavailable, no samples, read denied, partial authorization, permission revoked, and Health data-source display.
- [ ] iOS 17 local-only flow; iOS 18+ State of Mind export; current public iOS 27 device. 27.2 beta is optional and never a release dependency.
- [ ] Delete a check-in in Self Care and reset data; confirm Self Care-authored Health samples are removed. Test failure handling.
- [ ] Edit/delete the sample in Apple Health and verify the approved history/reconciliation behavior. This is currently open.
- [ ] Light/dark appearance, default and AX5 Dynamic Type, VoiceOver adjustable mood control, 44pt factor controls, Reduce Motion, and increased contrast.
- [ ] Reminder permission allowed/denied, schedule update, foreground notification open, CSV export/cancel, and reset confirmation/cancel.
- [ ] Upload only the signed validated build to TestFlight; complete beta review from TestFlight before App Store review.

## 5. App Store screenshots and metadata

- [ ] Supply at least one iPhone screenshot in the currently required 6.9-inch or 6.5-inch size. The current 6.9-inch PNG set is 1320 × 2868, RGB, and has no alpha; re-capture and visually verify it from the final build before submission.
- [ ] Follow Apple’s [current screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/). App Store Connect currently lists 1320 × 2868 as an accepted portrait size for 6.9-inch devices; iPhone Duo screenshots become required beginning April 2027.
- [ ] Upload 1–10 PNG/JPEG screenshots, status bar clean, no simulated health data implying a real result, and no unapproved Apple Health logo/badge.
- [ ] Review the metadata draft in `HUMAN_TODO.md`: name, subtitle, keywords, promotional text, description, URLs, age-rating answers, review notes, and privacy answers.
- [ ] Check whether “Self Care” is available in App Store Connect. If unavailable, choose an approved alternative before creating the record.

## 6. Submit only after the human gates

- [ ] App Privacy answers reflect what the final binary actually sends off-device; redo them if backend, analytics, crash reporting, accounts, or sync are added.
- [ ] Public privacy-policy and support links work on cellular and from Settings.
- [ ] App Review notes accurately explain optional Exercise Time/Sleep Analysis reads, optional State of Mind write, and iOS 17 local-only behavior.
- [ ] Age rating, content rights, medical-device status, pricing, territories, screenshots, and reviewer contact are complete.
- [ ] Confirm signed archive/build/version, TestFlight pass, and no open 🔴 or 🟠 items.
- [ ] Human selects **Submit for Review**.
