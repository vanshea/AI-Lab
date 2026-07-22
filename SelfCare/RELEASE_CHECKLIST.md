# Self Care 1.0 Release Checklist

Do not select **Submit for Review** until every unchecked item below is complete.

## 1. Release gates

- [x] Branch is `release/1.0-qa`.
- [x] Bundle ID remains `com.vansedita.SelfCare`.
- [x] Team remains `W63L7RKS3T`; signing style remains automatic.
- [x] Version/build are `1.0 (1)`.
- [x] Deployment target is iOS 17.0; iPhone only; Mac Catalyst off.
- [x] HealthKit is the only app entitlement.
- [x] Privacy manifest is embedded in the archive.
- [x] `ITSAppUsesNonExemptEncryption = NO` is in the built Info.plist.
- [x] SwiftLint 0.65.0: 0 violations.
- [x] Tests: 17 passed, 0 failed.
- [x] Xcode Analyze: succeeded.
- [x] Unsigned physical-SDK archive: succeeded.
- [ ] Publish the privacy policy at a stable public HTTPS URL.
- [ ] Replace the Contact placeholder in `PRIVACY_POLICY.md` with a monitored support email/page.
- [ ] Add public Privacy Policy and Support links to Settings and verify them on device.
- [ ] Complete the real-device/HealthKit/accessibility matrix below.
- [ ] Create and validate a **signed** App Store archive.
- [ ] Upload to TestFlight and complete acceptance testing.

## 2. Reproduce the engineering gates

Run from the `SelfCare` folder:

```sh
xcodebuild -project SelfCare.xcodeproj -scheme SelfCare \
  -configuration Release -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/SelfCare-ReleaseBuild \
  CODE_SIGNING_ALLOWED=NO clean build

xcodebuild test -project SelfCare.xcodeproj -scheme SelfCare \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/SelfCare-Tests CODE_SIGNING_ALLOWED=NO

xcodebuild analyze -project SelfCare.xcodeproj -scheme SelfCare \
  -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/SelfCare-Analyze CODE_SIGNING_ALLOWED=NO
```

SwiftLint is not installed globally on this Mac. Either install the official release, or run its portable binary:

```sh
swiftlint lint --strict --no-cache --config .swiftlint.yml
```

Expected result: 0 violations, 17 passing tests, successful build/analyze. Xcode 26.6 currently emits one metadata-extractor notice because this app has no App Intents dependency; there must be no app compiler, concurrency, deprecation, asset, linker, or analyzer warnings.

## 3. Real-device acceptance

Use at least one iPhone running iOS 17 and one running iOS 18 or later. Follow `TESTING_ON_IPHONE.md` in full.

- [ ] Clean install shows onboarding; Health permission is not requested automatically.
- [ ] Mood drag, factor tap, factor long-press, card resize, header minimize/restore all work.
- [ ] Light and Dark appearance are polished.
- [ ] Largest Accessibility text size scrolls without clipping.
- [ ] VoiceOver announces Mood as an adjustable numeric/semantic value.
- [ ] VoiceOver announces every factor as Goal met/not met and exposes Edit.
- [ ] Reduce Motion removes nonessential card/thumb animations.
- [ ] Logging produces success haptic and a local History row.
- [ ] Second same-day log creates another momentary entry, newest-first.
- [ ] Force-quit/relaunch preserves the same-day state and history.
- [ ] Crossing local midnight resets mood/manual daily inputs but preserves history/preferences.
- [ ] Health unavailable/no samples shows a designed state, never a blank screen.
- [ ] Health read allow/deny/revoke paths never block local logging.
- [ ] iOS 17 keeps mood local and reports State of Mind export unavailable.
- [ ] iOS 18+ writes one State of Mind momentary-emotion sample with Self Care association.
- [ ] State of Mind denial retains the local record and explains how to re-enable access.
- [ ] CSV export contains correct snapshots; cancelling share changes nothing.
- [ ] Cancel Reset leaves data untouched; confirm Reset clears only app-local data.

## 4. Signed archive and validation

In Xcode, first confirm **SelfCare target → Signing & Capabilities** has automatic signing, team `W63L7RKS3T`, and HealthKit.

Recommended human path:

1. Select **Any iOS Device (arm64)**.
2. Choose **Product → Archive**.
3. In Organizer, select the archive and click **Validate App**.
4. Resolve every validation warning/error. Do not alter bundle ID, team, or entitlements to work around a profile problem.

Equivalent CLI archive:

```sh
xcodebuild -project SelfCare.xcodeproj -scheme SelfCare \
  -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath build/SelfCare.xcarchive clean archive
```

Export with the checked-in `ExportOptions.plist`. The current Xcode method name is `app-store-connect`:

```sh
xcodebuild -exportArchive \
  -archivePath build/SelfCare.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export
```

- [ ] Archive identity is `Self Care`, `com.vansedita.SelfCare`, version 1.0, build 1.
- [ ] Distribution signing certificate and provisioning profile are valid.
- [ ] Organizer validation passes with no warnings.
- [ ] Privacy manifest and HealthKit entitlement are present in the signed app.
- [ ] dSYM is present and uploadSymbols is enabled.

## 5. App Store Connect record

- [ ] App name: **Self Care** (9/30 characters).
- [ ] Bundle ID: `com.vansedita.SelfCare`.
- [ ] SKU: choose an internal immutable value, for example `SELFCARE-IOS-1`.
- [ ] Primary category: **Health & Fitness**.
- [ ] Price: **Free**, unless the owner explicitly chooses otherwise.
- [ ] Availability/territories reviewed.
- [ ] Content rights answered.
- [ ] Age-rating questionnaire completed; expected result is 4+ because the app has no objectionable content or medical-treatment claims.
- [ ] Regulated medical device status: **No**. The app is a private wellbeing journal and explicitly does not diagnose, treat, or prevent conditions.

### Suggested metadata

**Subtitle** (28/30):

> Private daily mood check-ins

**Keywords** (89/100):

```text
mood,wellbeing,self care,journal,check-in,reflection,sleep,exercise,Apple Health,wellness
```

**Description:**

> Take a quiet moment to notice how you feel.
>
> Self Care is a private daily wellbeing journal for mood and a few simple factors that can shape your day. Adjust your mood, reflect on exercise, sleep, and scrolling, then log a moment to build a personal history on your iPhone.
>
> Apple Health is optional. With your permission, Self Care can read Exercise Time and Sleep Analysis. On iOS 18 or later, it can save your logged mood to State of Mind.
>
> Your full check-in history stays in the app. There are no accounts, ads, analytics, or developer-operated servers. Export a CSV when you choose, or reset local data at any time.
>
> Self Care supports personal reflection. It is not medical advice and does not diagnose, treat, or prevent medical conditions.

**Promotional text:**

> A calm, private place to notice your mood, reflect on daily factors, and keep a history on your iPhone.

**URLs:**

- [ ] Support URL: public monitored page supplied by owner.
- [ ] Privacy Policy URL: public HTTPS copy of `PRIVACY_POLICY.md`.
- [ ] Marketing URL: optional.

### App Review notes

```text
Self Care is a wellbeing journal, not a medical device.

Apple Health is optional and is never requested at launch. In Settings, “Connect Apple Health” requests read access to Apple Exercise Time and Sleep Analysis and write access to State of Mind. Read denial is intentionally opaque under HealthKit, so a no-data state can represent no matching samples or declined read access. Local check-ins always work without Health access.

On iOS 18 or later, Log check-in can write one HKStateOfMind momentary-emotion sample associated with self care. On iOS 17, the check-in remains local and the UI explains that mood export is unavailable.

The app has no account, ads, analytics, or developer-operated backend. Check-in history is stored in this app’s UserDefaults and can be exported or reset from Settings.
```

## 6. App Privacy answers

Apple defines “collect” as transmitting data off device in a way the developer or a third party can access beyond servicing a real-time request. This build has no network/backend/analytics/advertising SDK and processes check-ins and Health data on device.

- [ ] Privacy Policy URL entered and published.
- [ ] **Do you or your third-party partners collect data from this app?** → **No, we do not collect data from this app.**
- [ ] Tracking → **No**.
- [ ] Privacy Choices URL → optional; the in-app Export/Reset controls already provide choices, but a public page may be added.
- [ ] Confirm no new SDK, crash reporter, analytics, sync, account, or server feature was added after this audit. If any was added, redo the privacy answers.

Do not mark Health & Fitness data as developer-collected for this binary merely because HealthKit is used: Apple's current guidance says data processed only on device is not “collected.” Still disclose the exact HealthKit access in the privacy policy, usage strings, UI, and review notes.

## 7. Screenshots

Current Apple specifications accept 1320×2868 portrait for the highest-resolution 6.9-inch iPhone set. The prepared files are all exactly 1320×2868 and have no alpha:

- [x] `AppStore/Screenshots/6.9-inch/01-welcome-dark.png`
- [x] `AppStore/Screenshots/6.9-inch/02-check-in-dark.png`
- [x] `AppStore/Screenshots/6.9-inch/03-settings-dark.png`
- [x] `AppStore/Screenshots/6.9-inch/04-settings-light.png`
- [x] `AppStore/Screenshots/6.9-inch/05-check-in-light.png`
- [x] `AppStore/Screenshots/6.9-inch/06-privacy-light.png`

- [ ] Review times/dates and any visible sample data one last time.
- [ ] Upload in the intended storytelling order; App Store Connect can scale the highest-resolution set down where supported.
- [ ] Preview the product page and confirm no screenshot is cropped, softened, or rejected for alpha.

References: [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) and [upload screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/).

## 8. Upload and TestFlight

Apple supports Xcode Organizer, Transporter, `altool`, and the App Store Connect API. For this release, use **Xcode Organizer → Distribute App → App Store Connect → Upload** because it keeps validation, signing, and upload in one reviewed flow.

- [ ] Upload the validated signed archive with Organizer.
- [ ] Wait for processing; resolve export-compliance or asset warnings.
- [ ] Attach the processed build to an internal TestFlight group.
- [ ] Add concise beta notes covering onboarding, check-in, History, HealthKit allow/deny, CSV export/reset, light/dark, VoiceOver, and iOS 17 behavior.
- [ ] Complete the real-device matrix above from the TestFlight build—not the development build.
- [ ] Confirm privacy/support URLs work from a device on cellular data.
- [ ] Confirm App Store Connect metadata, screenshots, App Privacy, age rating, territories, pricing, and review contact.
- [ ] Only then select **Submit for Review**.

Reference: [Apple's current build upload methods](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds).
