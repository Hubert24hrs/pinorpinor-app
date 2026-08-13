# Store Readiness

What is ready, what needs the owner, and where the app's design was shaped by
store policy rather than by preference.

Legend: **DONE** — in this repository · **OWNER** — needs an account, credential
or asset only the owner can supply · **BLOCKED** — needs a change outside this
repository.

---

## Identity

| Item | Value | Status |
| --- | --- | --- |
| App name | Pinorpinor | DONE |
| Android package | `com.pinorpinor.app` | DONE |
| iOS bundle ID | `com.pinorpinor.app` | DONE |
| Version | `1.0.0+1` in `pubspec.yaml` | DONE |
| App icon | Generated from brand tokens; adaptive foreground + `#C2446E` background | DONE |
| Splash screen | Brand mark on `#FAF8F5`, incl. Android 12+ themed splash | DONE |
| Display name (iOS) | "Pinorpinor" | DONE |
| Store icon 512×512 | Derive from `assets/brand/app_icon.png` | OWNER |
| Feature graphic 1024×500 | Needs designing | OWNER |
| Screenshots | Phone, 7", 10", iPhone 6.7"/6.5", iPad 12.9" | OWNER |

## Legal and support

| Item | Where | Status |
| --- | --- | --- |
| Privacy policy | `https://pinorpinor.com/privacy` — live, linked from Settings | DONE |
| Terms of use | `https://pinorpinor.com/terms` — live, linked from Settings and sign-up | DONE |
| Community/safety guidance | `https://pinorpinor.com/safety` — live, linked from Settings and every profile | DONE |
| Support contact | `https://pinorpinor.com/contact` — live, linked from Settings | DONE |
| Account deletion URL for Play | `https://pinorpinor.com/contact` | OWNER (confirm, or add a dedicated page) |

> **One copy fix on the website.** `/safety` still says phone numbers are never
> published. Since the contact-request gate shipped, an accepted request opens a
> WhatsApp chat, which does reveal the number to that one member. The website's
> own notes flag this. It should be corrected before review, because a reviewer
> comparing the app's consent flow against that page will find them
> inconsistent.

## Account deletion — required by both stores

| Requirement | How it is met | Status |
| --- | --- | --- |
| Reachable in-app | Settings → Account and deletion → Delete my account | DONE |
| Confirmation before destruction | Type-your-username dialog | DONE |
| Honest about scope | Copy says the account is closed and the profile removed, and that some records are retained | DONE |
| Route to full erasure | "Request full data erasure" link to support | DONE |
| Web URL for the Play form | `https://pinorpinor.com/contact` | OWNER |
| Operator erasure procedure | Documented step by step in `SECURITY.md` § 14 | DONE |

## Permissions

The app requests nothing at launch. Each permission is asked for at the moment
the member taps the control that needs it.

| Permission | Platform | When asked | Rationale string |
| --- | --- | --- | --- |
| Internet | Android | — | Not user-facing |
| Camera | Both | On "Take a photo" / "Record a video" | Present in `Info.plist` and the manifest |
| Photo library | Both | On "Choose from gallery" | Present |
| Microphone | iOS | On video recording | Present |
| Notifications | Both | When alerts are first enabled | Present |
| Vibrate, wake lock | Android | — | Added by `flutter_local_notifications`, not by app code. Neither prompts the member; both are install-time permissions needed to raise a notification |
| **Location** | — | **Never requested** | The backend stores a city; coordinates never reach a client |
| **Contacts, calendar, mic-always, background location** | — | **Never requested** | Not declared anywhere |

Verified against the **merged** manifest from a real Gradle build, not just the
source manifest — the merged output is what a reviewer's tooling inspects, and
it is where a dependency can quietly add a permission:

```
android.permission.INTERNET
android.permission.ACCESS_NETWORK_STATE
android.permission.POST_NOTIFICATIONS
android.permission.CAMERA
android.permission.VIBRATE          ← flutter_local_notifications
android.permission.WAKE_LOCK        ← flutter_local_notifications
<applicationId>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION   ← AndroidX, self-scoped
```

No location, no contacts, no calendar, no external-storage permission. The same
build confirms `android:label="Pinorpinor"`,
`android:usesCleartextTraffic="false"`, the network security config, and all
three deep-link entries (`pinorpinor://`, `pinorpinor.com`,
`www.pinorpinor.com`).

## Content rating

| Store | Expected | Notes |
| --- | --- | --- |
| Google Play (IARC) | Mature 17+ / PEGI 16+ | Dating, user-generated photos, unmoderated-in-realtime messaging |
| App Store | 17+ | Frequent/Intense Mature or Suggestive Themes |
| Target audience | **18 and over only** | Do not tick any child audience bracket |

## User-generated content — App Store guideline 1.2

This is the guideline most likely to be applied to a dating app. All four
requirements are met:

| Requirement | Implementation |
| --- | --- |
| A method for filtering objectionable material | Every photo and video is held (`isApproved: false`) until a human moderator releases it through the website's admin queue |
| A mechanism to report offensive content, with timely responses | Report control on every profile and conversation; seven structured reasons including "This person appears to be under 18"; reports land in the moderation queue |
| The ability to block abusive users | Block on every profile and conversation; hides both members from each other in both directions and ends any existing match in the same server-side transaction |
| Published contact information | `https://pinorpinor.com/contact`, linked in Settings |

## Payments — why there is no in-app purchase

Credits unlock placement inside the app, which makes them a **digital good**. If
the app sold them, Google Play Billing and StoreKit would be mandatory
(Play Payments policy; App Store guideline 3.1.1), each taking a commission and
each requiring integration.

The app sells nothing. Credits are arranged directly between the member and the
operator over WhatsApp and applied by an administrator — which is how the
website already works, since card payment is switched off on the backend
(`PAYSTACK_ENABLED=false`; the payment routes answer `503`).

The app therefore:

- ships **no** purchase flow, **no** checkout, and **no** billing library;
- has **no** client-side "payment succeeded" flag anywhere — balance is read
  from the server and boosts are activated by the server debiting the wallet
  inside a transaction;
- shows credit packages for reference and a WhatsApp link to the operator.

`CreditsRepository.initCardPayment` exists as a named, throwing method so this
decision is visible where a future contributor would look for it, rather than
being an absence somebody "fixes" by adding a WebView checkout — which is
precisely what both policies prohibit.

**If card payments are ever re-enabled**, the mobile path must be reconsidered
from scratch. Both stores allow an app to *link out* to external purchase only
under narrow, region-specific entitlements; the safe default remains the current
one.

## Data safety / privacy labels

Both stores, same content:

| Data | Collected | Shared | Purpose | Linked to user |
| --- | --- | --- | --- | --- |
| Name | Yes | No | Account, profile | Yes |
| Email | Yes | No | Account, verification | Yes |
| Phone (women) | Yes | No | Verification, consented contact | Yes |
| Date of birth | Yes | No | 18+ verification | Yes |
| City | Yes | No | Discovery scoping | Yes |
| Precise location | **No** | — | — | — |
| Photos / videos | Yes | No | Profile content | Yes |
| Messages | Yes | No | Messaging | Yes |
| App interactions | Yes | No | Discovery ordering | Yes |
| Crash logs | **No** | — | No crash SDK integrated | — |
| Advertising ID | **No** | — | — | — |

Also declare: encrypted in transit; deletion available in-app; **no tracking**;
**no third-party data sharing**.

## Technical readiness

| Item | Status | Evidence |
| --- | --- | --- |
| `flutter analyze` | DONE | 0 issues, with lints tightened beyond `flutter_lints` |
| `flutter test` | DONE | 127 tests passing |
| `dart format` | DONE | Clean |
| Android debug APK | DONE | `app-debug.apk`, 95,953,222 bytes, arm64 |
| Android release `.aab` | OWNER — needs `key.properties` | Config in place; falls back to debug signing without it |
| Signing config | DONE | Reads gitignored `key.properties` |
| R8 / ProGuard | DONE | `android/app/proguard-rules.pro`; strips logging |
| Bundle splits | DONE | Density and ABI splits enabled |
| Network security config | DONE | Cleartext refused; system CAs only in release |
| iOS `Info.plist` | DONE | Permissions, ATS, URL scheme, orientations |
| iOS entitlements file | DONE (not attached) | Attaching needs a provisioning profile — see DEPLOYMENT.md |
| iOS build / archive | BLOCKED | Requires macOS + Xcode |
| No secrets in the repository | DONE | See SECURITY.md § 2 |
| No `TODO`/`FIXME`/mock data | DONE | Verified by search |

## Store review credentials

Both stores need a working demo account. **OWNER ACTION.**

Create one on production or a staging origin with:

- a completed profile including at least one **approved** photo (an unapproved
  one is invisible, and a reviewer seeing an empty profile will assume the app
  is broken);
- at least one conversation with message history;
- at least one pending contact request, so the consent flow can be demonstrated;
- a credit balance, so the wallet screen is not empty.

Supply it in Play Console → App access, and in App Store Connect → App Review
Information.

## Backend readiness

Nothing here is an app defect, but each affects what a reviewer sees.

| Item | State | Impact |
| --- | --- | --- |
| Website live at pinorpinor.com | Yes | — |
| Email provider keyed | Yes | Verification and password reset send |
| **SMS provider keyed** | **No** — Termii sender-ID approval pending | **Women cannot complete phone verification.** A reviewer following the verification flow will hit this |
| Media moderation queue | Working | Uploads need an admin to approve them before they appear |
| Public profiles visible | **Currently zero** | No member media has been approved yet, so discovery is empty on production. A reviewer will see an empty grid |
| Push send path | Absent | See DEPLOYMENT.md § Push notifications |
| `assetlinks.json` | Not published | `https://` links open the browser |
| `apple-app-site-association` | Not published | Same on iOS |

> **The most important line in this table** is "public profiles visible:
> currently zero". An empty discovery grid is the single most likely cause of a
> store rejection for "incomplete app", regardless of how well everything else
> is built. Approve some real member media before submitting, or point the
> review build at an origin that has content.

## Build verification

Run and record before submitting:

```bash
flutter analyze                    # expect: No issues found
flutter test                       # expect: All tests passed
flutter build apk --debug          # expect: app-debug.apk
flutter build appbundle --release  # expect: app-release.aab, signed with the upload key
```

Results from this repository:

| Command | Result |
| --- | --- |
| `flutter analyze` | **No issues found** |
| `flutter test` | **127 tests, all passing** |
| `dart format .` | Clean |
| `flutter build apk --debug --target-platform android-arm64` | **Succeeded** — `build/app/outputs/flutter-apk/app-debug.apk`, 95,953,222 bytes, in 1367s |
| `flutter build appbundle --release` | **Not run** — needs `android/key.properties`, which only the owner can create |

A debug APK is large because it carries the full Dart kernel and the debug
engine. A release bundle with R8, resource shrinking and ABI/density splits is a
fraction of it.

### On-device verification — NOT DONE, and why

The app has **not been run on a physical device or an emulator.** The only AVD
on the development machine (`Medium_Phone_API_36.1`, x86_64) refuses to start:

```
ERROR | x86_64 emulation currently requires hardware acceleration!
CPU acceleration status: Android Emulator hypervisor driver is not installed
```

Installing the hypervisor driver is an administrator-level system change with a
reboot, which is the machine owner's call rather than something to do to a
development machine unasked.

**This is the largest untested surface, and it is worth being blunt about it.**
Compilation and the widget suite prove a great deal — layout at six widths,
validation, error mapping, session handling, the safety flows — but they do not
prove that the camera opens, that a real upload completes over a mobile
connection, that WhatsApp launches from the handoff, that the deep link
intent-filter resolves, or that the splash hands over cleanly.

Before the first store submission, someone should install the debug APK on a
real Android phone and walk the whole journey. `DEPLOYMENT.md` §
"Verifying against a staging origin" describes exactly what to walk through.

## Remaining owner actions

In the order they block a submission:

1. **Approve real member media** so discovery is not empty. (Backend)
2. **Set the SMS provider key** so phone verification completes. (Backend)
3. **Create the upload keystore** and `android/key.properties`.
4. **Build and verify the signed `.aab`.**
5. **Create a Play Console app**, complete the store listing and all content
   declarations.
6. **Design the feature graphic and capture screenshots.**
7. **Create a demo account** for both reviews.
8. **Correct the `/safety` copy** on the website about phone numbers.
9. **Publish `assetlinks.json`** with the release certificate fingerprint.
10. **Enrol in the Apple Developer Program**, then on macOS: configure signing,
    attach the entitlements file, archive, upload, TestFlight.
11. **Publish `apple-app-site-association`.**
12. *(Optional, later)* Implement the push backend, then wire FCM into the app.
