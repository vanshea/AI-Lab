# Human decisions and submission gates — Self Care 1.0

Order is by what blocks a safe App Store submission. No App Store Connect record, upload, or review submission was created by this task.

## 1. 🔴 Publish the real privacy policy and support contact

- Publish `PRIVACY_POLICY.md` at a public, stable HTTPS URL. Do not submit with the `REPLACE_WITH_PUBLIC_PRIVACY_POLICY_HTTPS_URL` constant in `SelfCare/Views/SettingsView.swift`.
- Provide a monitored support email or public support page and replace the contact placeholder in `PRIVACY_POLICY.md`.
- Put the same real privacy-policy URL in App Store Connect and verify both links from Settings on cellular.
- Apple’s HealthKit guidance requires a public privacy-policy URL during submission: [HealthKit HIG](https://developer.apple.com/design/human-interface-guidelines/healthkit/).

## 2. 🔴 Resolve the HealthKit history contract and run the device matrix

The app writes a State of Mind entry and now updates/deletes its own samples by sync identifier, but it does not mirror edits/deletions performed inside Apple Health. Decide which contract is right before release:

- **Recommended for 1.0:** keep Self Care’s local history authoritative, make the one-way boundary explicit in Settings/history copy, and remove any promise that Health edits mirror back; or
- **Two-way history:** approve a State of Mind read permission and build a source-scoped anchored query that consumes additions/deletions. HealthKit hides read denial, so “no results” must never be treated as proof of deletion. Test privacy implications and deletion events on device before shipping.

After the choice, use a physical iPhone for these scenarios:

- iOS 17 local-only flow; current public iOS 27 flow; iOS 18+ State of Mind flow.
- Exercise/Sleep allowed, denied, partial, revoked, empty, and populated.
- Save a mood; verify Health shows source `Self Care`, the expected valence/associations, and no invented emotion label.
- Re-save the same check-in; verify the existing sample is replaced, not duplicated.
- Delete/reset in Self Care; verify its Health entry is removed and failure behavior is understandable.
- Edit/delete in Health and verify the selected one-way or mirrored behavior.
- On iOS 27.2 beta only if available: repeat the critical flow in the redesigned Health app. Ship no beta-only dependency.

HealthKit is limited in Simulator; the 27 passing unit tests do not replace this matrix. The app ID’s HealthKit capability, signed profile, and icon/source identity also need validation during archive review.

## 3. 🔴 Sign and validate the archive; confirm build number

- The local archive was built unsigned for QA. Create a signed Release archive in Xcode Organizer with the existing team `W63L7RKS3T`, automatic signing, bundle ID `com.vansedita.SelfCare`, and HealthKit capability.
- Validate it in Organizer. No upload was performed.
- Current project version is `1.0 (4)`. Before each upload, confirm the build number is greater than every build already uploaded for version 1.0; increment `CURRENT_PROJECT_VERSION` and rebuild if needed.
- App Store’s current minimum upload requirement is Xcode 26 or later with the iOS 26 SDK; installed Xcode 27.0/iOS 27.0 exceeds that floor. Recheck Apple’s [SDK minimum requirements](https://developer.apple.com/news/upcoming-requirements/?id=04282026a) before upload.

## 4. 🟠 Check the name and create the App Store Connect record

“Self Care” is generic. Search in App Store Connect and check trademark/market conflicts before creating the record. If unavailable, consider:

- **Morrow: Mood Check-In**
- **Moment by Moment**
- **Daily Mood & Reflection**

Alternative subtitle if retaining the name: **A private mood check-in**. Name availability and legal clearance are human checks.

Create the record only after the chosen name and final URLs are ready. Suggested SKU: `SELFCARE-IOS-1` (or another immutable internal identifier). Category: Health & Fitness. Price/territories are owner decisions.

## 5. 🟠 Capture and approve final screenshots / visual QA

Current `AppStore/Screenshots/6.9-inch` PNGs are 1320 × 2868 and have no alpha, but they predate the final build. Re-capture the current build and inspect the core five views (check-in, history/empty history, Settings, factor editor, category editor/privacy) at default and AX5 text sizes, light and dark, on the smallest and largest available iPhone simulators. Clean the status bar and use truthful sample data.

Apple currently accepts 1320 × 2868 portrait for 6.9-inch iPhones. See the [current screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/). App Store Connect says iPhone Duo screenshots become required starting April 2027; verify timing if submission moves beyond that date.

## 6. 🟡 Review label and safety copy

The current mood slider records valence only, so State of Mind labels intentionally remain empty. Approve that for 1.0 or approve an explicit feeling-selection step; do not infer “happy,” “sad,” or other labels from the numerical range.

Proposed short Settings note for approval:

> Self Care supports personal reflection. It is not medical advice and does not diagnose, treat, or prevent any condition. If you may be in immediate danger, contact local emergency services. If you need emotional support, use a crisis resource available in your region.

The in-app privacy details already say the app is not a substitute for professional care. Decide whether to add the note above and a country-appropriate crisis-resource link before release; do not ship a one-country number as universal.

## 7. App Store metadata draft

**Name:** Self Care (availability check required)  
**Subtitle:** A private mood check-in  
**Keywords:** `mood,wellbeing,wellness,journal,self care,reflection,check-in,sleep,exercise`

**Promotional text**

> A calm, private place to notice your mood, reflect on daily factors, and keep a history on your iPhone.

**Description**

> Take a quiet moment to notice how you feel.
>
> Self Care is a private daily reflection journal. Adjust your mood, reflect on exercise, sleep, and scrolling, then save a moment to build a personal history on your iPhone.
>
> Apple Health is optional. With your permission, Self Care can read Exercise Time and Sleep Analysis. On iOS 18 or later, you can separately choose to save a check-in mood to State of Mind. On iOS 17, check-ins stay on your iPhone.
>
> Your check-in history stays in the app unless you choose to export it. There are no accounts, ads, analytics, or developer-operated servers. Reset your local history and preferences at any time.
>
> Self Care supports personal reflection. It is not medical advice and does not diagnose, treat, or prevent medical conditions.

**URLs**

- Support URL: owner must supply a public, monitored support page.
- Privacy Policy URL: owner must supply the hosted HTTPS URL from item 1.
- Marketing URL: optional; owner decision.

**Age-rating answers (draft for owner confirmation)**

- The app contains no user-generated content, social features, advertising, gambling, violence, or sexual content.
- It presents wellbeing journaling, not medical diagnosis or treatment. Confirm all current App Store Connect health/medical and user-generated-content questions against the final binary; expected rating is 4+, but the owner must submit the questionnaire and accept Apple’s calculated rating.
- Confirm content rights and medical-device status in App Store Connect. The product is a personal reflection journal, not a regulated diagnostic/treatment feature.

**App Privacy answers (derive again if code changes)**

- Current source has no account, developer backend, analytics, ads, or network client. Check-ins and HealthKit values stay on device; a CSV is shared only if the user chooses an export destination.
- Draft answer to “Do you or your third-party partners collect data from this app?”: **No**, provided the final binary remains on-device and has no new SDK/service. Apple’s definition and final answers are available in [App privacy details](https://developer.apple.com/app-store/app-privacy-details/).
- Tracking: **No**. No collected data types to declare for the current on-device-only binary.
- Revisit these answers if crash reporting, cloud backup/sync, accounts, analytics, support upload, or another third-party SDK is added.

**App Review notes draft**

> Self Care is a personal wellbeing journal, not a medical device. HealthKit is optional and is not requested at launch or during a normal check-in. In Settings, connecting a category can request read access to Apple Exercise Time or Sleep Analysis. The separate mood-export switch requests State of Mind write access on iOS 18 or later. iOS 17 check-ins remain local. HealthKit hides read denial, so a no-data state may mean no matching samples or unavailable read access; manual entry and local check-ins remain usable. Check-ins and factors are stored on this iPhone. CSV export happens only after the person chooses a destination. There is no account or developer-operated backend.

Update this note to explain the final Health history/reconciliation contract after item 2 is resolved.
