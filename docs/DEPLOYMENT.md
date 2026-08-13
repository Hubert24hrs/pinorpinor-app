# Deployment

Getting the Pinorpinor app onto Google Play and the App Store, step by step.

Anything marked **OWNER ACTION** cannot be done from this repository — it needs
an account, a credential, or a machine that is not available here.

---

## Contents

- [Before you start](#before-you-start)
- [Google Play](#google-play)
- [Apple App Store](#apple-app-store)
- [Deep links](#deep-links)
- [Push notifications](#push-notifications)
- [Verifying against a staging origin](#verifying-against-a-staging-origin)
- [Release checklist](#release-checklist)

---

## Before you start

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze          # must be clean
flutter test             # must be green
```

The app has no environment file to prepare. The only build-time knob is the API
origin, which defaults to production:

```bash
flutter build appbundle --release \
  --dart-define=PINORPINOR_API_ORIGIN=https://pinorpinor.com
```

---

## Google Play

### 1. Create the upload key — OWNER ACTION

The upload key signs every build you send to Play. **Losing it means losing the
ability to update the listing** without a key-reset request to Google, and a
leaked one lets somebody else publish as you. Generate it once, back it up
somewhere that is not this repository, and never commit it.

```bash
keytool -genkey -v \
  -keystore ~/pinorpinor-upload-keystore.jks \
  -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

You will be asked for a store password, a key password and a distinguished
name. Record all of it in a password manager.

Then create `android/key.properties` — **gitignored, never committed**:

```properties
storePassword=<store password>
keyPassword=<key password>
keyAlias=upload
storeFile=C:/Users/<you>/pinorpinor-upload-keystore.jks
```

`android/app/build.gradle.kts` reads this file if it exists. When it does not,
the release build falls back to debug signing so the command still works
locally — such a build **cannot** be uploaded to Play, which is the intended
failure mode.

Back up: the `.jks` file, both passwords, and the alias. Consider enrolling in
Play App Signing (recommended), which lets Google hold the app signing key while
you keep the upload key.

### 2. Build the bundle

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Verify it is signed with your key, not the debug key:

```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

The owner should be your distinguished name — not `CN=Android Debug`.

### 3. Play Console setup — OWNER ACTION

Create the app at <https://play.google.com/console>.

| Field | Value |
| --- | --- |
| App name | Pinorpinor |
| Default language | English (United Kingdom) or (United States) |
| App or game | App |
| Free or paid | Free |
| Package name | `com.pinorpinor.app` |

### 4. Store listing — OWNER ACTION

| Asset | Requirement | Status |
| --- | --- | --- |
| App icon | 512×512 PNG, 32-bit, no alpha | Generate from `assets/brand/app_icon.png` |
| Feature graphic | 1024×500 PNG or JPEG | **Needs designing** |
| Phone screenshots | 2–8, min 320px, max 3840px | **Needs capturing** |
| 7-inch tablet screenshots | Optional but recommended | **Needs capturing** |
| 10-inch tablet screenshots | Optional but recommended | **Needs capturing** |
| Short description | ≤80 characters | Draft below |
| Full description | ≤4000 characters | Draft below |

Short description draft:

> Meet verified members near you. Browse freely; contact only with consent.

Full description should state, plainly: 18+ only; profiles are human-moderated;
phone numbers are never published and contact requires the member's consent;
blocking and reporting are available on every profile.

### 5. App content declarations — OWNER ACTION

These are where a dating-adjacent app most often gets rejected. Answer them
honestly and consistently with `docs/STORE_READINESS.md`.

| Section | What to say |
| --- | --- |
| Privacy policy | `https://pinorpinor.com/privacy` |
| App access | Provide a working demo account — reviewers must be able to see a signed-in profile, messaging and the contact-request flow |
| Ads | No |
| Content rating | Complete the IARC questionnaire. Expect Mature 17+ / PEGI 16+ for a dating app with user-generated photos |
| Target audience | 18 and over. Do **not** tick any child audience |
| News app | No |
| COVID-19 apps | No |
| Data safety | See the table below |
| Government apps | No |
| Financial features | No — the app contains no purchase flow |

**Data safety declarations.** What the app actually collects and sends:

| Data type | Collected | Shared | Purpose | Optional |
| --- | --- | --- | --- | --- |
| Name | Yes | No | Account, profile | Required |
| Email address | Yes | No | Account, verification | Required |
| Phone number | Yes (women) | No | Verification, consented contact | Required for women |
| Date of birth | Yes | No | Age verification (18+) | Required |
| Approximate location (city) | Yes | No | Discovery | Required |
| Precise location | **No** | — | — | — |
| Photos and videos | Yes | No | Profile content | Optional |
| Messages | Yes | No | In-app messaging | Optional |
| App interactions | Yes | No | Discovery ordering | Required |
| Crash logs | No | — | No crash SDK is integrated | — |
| Advertising ID | **No** | — | — | — |

Also declare: data is encrypted in transit; users can request deletion; the app
provides an in-app account-deletion route.

**Account deletion URL** — Play requires this for any app that lets users create
an account: `https://pinorpinor.com/contact` (or a dedicated deletion page if
one is added). The in-app route is Settings → Account and deletion.

### 6. Testing tracks

1. **Internal testing** — up to 100 testers, available in minutes. Start here.
2. **Closed testing** — Play now requires a period of closed testing with a
   minimum number of testers before a personal developer account can go to
   production. Check the current requirement in the Console; it has changed
   more than once.
3. **Production** — staged rollout, 10% → 50% → 100%.

### 7. Upload

Release → Internal testing → Create new release → upload the `.aab` → add
release notes → review → roll out.

---

## Apple App Store

> **Every step in this section requires macOS with Xcode.** None of it can be
> completed on Windows, and nothing in this repository claims otherwise. The
> Flutter code is platform-agnostic and the iOS project is configured; what
> remains is compilation, signing and submission.

### 1. Apple Developer Program — OWNER ACTION

Enrol at <https://developer.apple.com/programs/> — US$99/year. An organisation
enrolment needs a D-U-N-S number and takes longer than an individual one.

### 2. Identifiers — OWNER ACTION

In the Developer portal → Certificates, Identifiers & Profiles:

1. Create an App ID with bundle identifier **`com.pinorpinor.app`** (already set
   in `ios/Runner.xcodeproj`).
2. Enable capabilities: **Associated Domains**, and **Push Notifications** if
   and when the backend gains a send path.

### 3. Xcode configuration — OWNER ACTION, macOS

```bash
open ios/Runner.xcworkspace
```

- **Signing & Capabilities** → select your team; leave "Automatically manage
  signing" on for a first submission.
- Add the **Associated Domains** capability and point it at the checked-in
  `ios/Runner/Runner.entitlements`. That file is in the repository but is
  **not** wired into the Xcode target — deliberately, because the
  `aps-environment` entitlement it declares would fail the build on a machine
  without a matching provisioning profile. Attach it when you have one.
- Confirm the deployment target is iOS 13 or higher.

Already configured in this repository, and worth checking rather than redoing:
bundle display name, permission strings for camera, photo library and
microphone, `LSApplicationQueriesSchemes` for the WhatsApp handoff, the
`pinorpinor://` URL scheme, portrait-only on iPhone with all orientations on
iPad, and `ITSAppUsesNonExemptEncryption: false`.

### 4. Build and archive — OWNER ACTION, macOS

```bash
flutter build ipa --release
```

Then either upload the resulting `.ipa` with Transporter, or archive from Xcode
(Product → Archive → Distribute App).

### 5. App Store Connect — OWNER ACTION

| Field | Value |
| --- | --- |
| Name | Pinorpinor |
| Primary category | Social Networking |
| Age rating | **17+** — expect this for a dating app with user-generated photos |
| Privacy policy URL | `https://pinorpinor.com/privacy` |
| Support URL | `https://pinorpinor.com/contact` |

**Screenshots** — required sizes:

| Device | Size |
| --- | --- |
| iPhone 6.7" (Pro Max) | 1290×2796 |
| iPhone 6.5" | 1242×2688 |
| iPad Pro 12.9" (3rd gen) | 2048×2732 |

**Privacy nutrition labels** — mirror the Play data-safety table above. Declare
data as **linked to the user**, not used for tracking, and not shared with third
parties.

**App Review notes** — write these carefully. A dating app with user-generated
content gets read closely under guideline 1.2 (User-Generated Content). State:

- a working demo account with a completed profile;
- that the app is 18+ and date of birth is validated server-side;
- that all photos and videos are reviewed by a human moderator before they
  become visible;
- where the reporting control is (profile → overflow menu) and the blocking
  control (same menu);
- that a member's phone number is never published, and contact happens only
  after that member accepts a request;
- that credits are arranged directly with the operator and the app contains **no
  purchase flow**, so guideline 3.1.1 (In-App Purchase) does not apply.

### 6. TestFlight

Internal testers (up to 100, no review) are available as soon as the build
processes. External testing (up to 10,000) needs a Beta App Review.

---

## Deep links

Both platforms need a file published on **pinorpinor.com** before shared
`https://` links open the app instead of the browser. Until then only the
`pinorpinor://` scheme reaches the app, which is a graceful degradation rather
than a failure.

### Android App Links — OWNER ACTION

Publish at `https://pinorpinor.com/.well-known/assetlinks.json`, served as
`application/json` with no redirect:

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.pinorpinor.app",
    "sha256_cert_fingerprints": ["<SHA-256 of your signing certificate>"]
  }
}]
```

Get the fingerprint from Play Console → Setup → App integrity → App signing (use
the **app signing** certificate, not the upload one, if you enrol in Play App
Signing).

Verify:

```bash
adb shell pm get-app-links com.pinorpinor.app
```

### iOS Universal Links — OWNER ACTION

Publish at `https://pinorpinor.com/.well-known/apple-app-site-association` —
`application/json`, **no `.json` extension**, no redirect:

```json
{
  "applinks": {
    "details": [{
      "appIDs": ["<TEAM_ID>.com.pinorpinor.app"],
      "components": [
        { "/": "/profile/*" },
        { "/": "/reset-password*" },
        { "/": "/*", "comment": "bare usernames" }
      ]
    }]
  }
}
```

Both files are served from the **website** repository, so publishing them is the
one change this work touches outside the app — and it is a static file, not a
code change.

---

## Push notifications

**Current state:** the app raises local notifications and polls for badge
counts while it is in the foreground. There is no server-pushed delivery, and
that is a backend gap rather than a client one.

**Why it was not simply added.** The Pinorpinor backend has no device-token
table, no FCM or APNs credential, and no send path anywhere. Adding Firebase
Messaging to the Flutter client alone would produce an app that registers for
notifications nobody can send — and would break the Android build for anyone
without a `google-services.json`, which is not in this repository and should not
be.

**What it takes, in order:**

1. **Website — schema.** Add a device-token table:

   ```prisma
   model DeviceToken {
     id         String   @id @default(cuid())
     userId     String
     token      String   @unique
     platform   String   // "android" | "ios"
     createdAt  DateTime @default(now())
     lastSeenAt DateTime @updatedAt

     user User @relation(fields: [userId], references: [id], onDelete: Cascade)

     @@map("device_tokens")
     @@index([userId])
   }
   ```

2. **Website — endpoints.** `POST /api/devices` to register a token behind
   `requireAuth()`, and `DELETE /api/devices/:token` on sign-out.

3. **Website — send path.** A `sendPush(userId, notification)` helper beside
   `lib/notify.ts`, called from the same places that already write a
   `Notification` row: the message send route, the swipe match branch, and both
   contact-request routes. Respect the member's `Settings` toggles — the columns
   already exist.

4. **Credentials — OWNER ACTION.** A Firebase project with FCM enabled, an APNs
   auth key uploaded to it, `google-services.json` for Android and
   `GoogleService-Info.plist` for iOS. Both are already gitignored.

5. **App.** Add `firebase_core` and `firebase_messaging`, register the token
   after sign-in, delete it on sign-out, and route a notification tap through
   the existing `DeepLinks.resolve`. The routing half is already built.

Until step 4 is done, adding step 5 would break the Android build, which is why
the client stops where it does.

---

## Verifying against a staging origin

The integration tests run against a scripted backend on purpose — creating real
accounts, reports and contact requests on a live platform with real members
would be worse than having no suite. To exercise the real contracts:

1. Deploy a staging copy of the website with its own Supabase project.
2. Run the app against it:

   ```bash
   flutter run --dart-define=PINORPINOR_API_ORIGIN=https://staging.pinorpinor.com
   ```

3. Walk the whole journey: register → verify → complete profile → upload media →
   have an admin approve it → browse → open a profile → request contact →
   accept from the other account → open WhatsApp → message → report → block →
   delete the account.

That sequence is the acceptance test this repository cannot run for you.

---

## Release checklist

Before every release:

- [ ] `flutter analyze` clean
- [ ] `flutter test` green
- [ ] Version bumped in `pubspec.yaml` (`version: x.y.z+n` — **n must increase**)
- [ ] `flutter build appbundle --release` succeeds and is signed with the upload key
- [ ] Installed the release build on a physical Android device and signed in
- [ ] Deep link opens the app: `adb shell am start -a android.intent.action.VIEW -d "pinorpinor://profile/test"`
- [ ] Data safety / privacy labels still accurate
- [ ] Release notes written
- [ ] Demo account for review still works
- [ ] iOS: archived, uploaded, TestFlight build installs — **macOS only**
