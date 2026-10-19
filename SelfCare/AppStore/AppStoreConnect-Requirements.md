# Self Care - App Store Connect answers

Prepared from `AppStore/Requirements.pdf`. Values marked **Confirm** are account, legal, or distribution choices that cannot be established from the screenshot alone.

## Localizable information

- **Language:** English (U.S.)
- **Name:** Self Care
- **Subtitle:** Log healthy actions

Suggested subtitle alternative if Apple rejects the wording or the product positioning changes: `A private daily check-in`.

## General information

- **Bundle ID:** `com.vansedita.SelfCare`
- **SKU:** `VSC-001`
- **Apple ID:** `6823627820`
- **Primary language:** English (U.S.)
- **License agreement:** Apple's Standard License Agreement
- **Content rights:** The app contains original Self Care content and user-entered journal/check-in data. **Confirm** ownership and licensing for every supplied icon, illustration, font, and other asset before submitting.

## Age rating

Use the App Store Connect questionnaire and verify the regional results shown in the requirements PDF:

- **Default/global result shown:** 9+
- **Vietnam:** 12+
- **Brazil:** A10
- **Korea, Republic of:** ALL
- **Age suitability URL:** None, unless a separate age-suitability page is required by the account or region.

The app is a wellbeing reflection tool. It does not provide medical diagnosis, treatment, emergency advice, sexual content, gambling, violence, or unrestricted web access.

## App encryption documentation

Recommended answer for the current app:

- **App Uses Non-Exempt Encryption:** No
- **Reason:** Self Care does not implement proprietary or custom cryptographic algorithms. Any system-level protection used by iOS, Apple Health, or the device is provided by Apple's operating system.

**Confirm with the final build:** If networking, third-party SDKs, custom encryption, or encrypted cloud services are added, revisit the export-compliance answer before submission.

## App Store regulations and permits

- **Digital Services Act trader status:** **Confirm in App Store Connect.** This is an account/business declaration, not an app-content value.
- **Vietnam Game License:** Not applicable; Self Care is not a game.
- **Regulated medical device:** No. Self Care is a general wellbeing and reflection tool, not a regulated medical device. Keep the product copy and review notes consistent with this position.

## Server notifications and shared secret

- **Production server notification URL:** None
- **Sandbox server notification URL:** None
- **App-specific shared secret:** Not required; the app has no auto-renewable subscriptions or receipt server.

## App privacy and URLs

- **Privacy policy URL:** `https://vanshea.com/selfcare_app/PrivacyPolicy/index.html`
- **Custom product page:** `https://vanshea.com/selfcare_app/ProductPage/`
- **Support URL:** **Confirm** the preferred public support/contact page before submission.
- **Marketing URL:** Optional; use the public Self Care product page if App Store Connect requests one.

## Submission notes

1. Confirm the bundle ID matches the signed release build.
2. Confirm that `VSC-001` is unique within the App Store Connect account.
3. Complete the privacy nutrition labels for mood/state-of-mind data, HealthKit data, and any user-entered wellness information according to the actual release build.
4. Recheck the age-rating questionnaire after the final feature set is locked.
5. Keep the medical-device disclaimer in the product page and review notes.

