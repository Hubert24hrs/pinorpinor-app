# Pinorpinor — Mobile App

The official Flutter client for [Pinorpinor](https://pinorpinor.com), a premium
social discovery and meetup platform focused on Nigeria. Adult women (18+)
create public profiles with photos, short videos, the services they offer and
the rates they charge. Visitors browse those profiles without logging in;
contacting a member requires an account **and that member's explicit consent**.

This app is the native counterpart of the existing website, not a second
product. It talks to the same backend, the same database and the same accounts:
somebody who signs up in the app is the same member somebody else sees on the
website, immediately.

> **The backend is Supabase — reached through the website's REST API, not
> directly.** The app holds no key of any kind. This is not an oversight and
> must not be "fixed": migration `20260812030000_lock_down_postgrest` revokes
> every `anon` and `authenticated` grant on schema `public` and enables RLS on
> every table with **no policies**, so a `supabase_flutter` client would receive
> `401 permission denied` on every query. See
> [How the app talks to the backend](#how-the-app-talks-to-the-backend).

---

## Contents

- [Architecture](#architecture)
- [How the app talks to the backend](#how-the-app-talks-to-the-backend)
- [Prerequisites](#prerequisites)
- [Getting started](#getting-started)
- [Configuration](#configuration)
- [Project layout](#project-layout)
- [Business rules worth knowing](#business-rules-worth-knowing)
- [Testing](#testing)
- [Release builds](#release-builds)
- [Deep links](#deep-links)
- [Notifications](#notifications)
- [Security](#security)
- [Troubleshooting](#troubleshooting)
- [Further documentation](#further-documentation)

---

## Architecture

| Layer | What lives there |
| --- | --- |
| `lib/core` | Configuration, HTTP client, secure session store, theme, routing, shared utilities |
| `lib/data/models` | Typed mirrors of the backend's Prisma models and response shapes |
| `lib/data/repositories` | One class per API area; the only place a URL appears |
| `lib/features` | Screens and their controllers, grouped by product area |
| `lib/shared` | Reusable widgets and small utilities |

**State management** is [Riverpod](https://riverpod.dev). Repositories are plain
classes behind providers, which is what makes every screen testable with a fake
backend — see `test/helpers/`.

**Navigation** is [go_router](https://pub.dev/packages/go_router) with a
`StatefulShellRoute`, so each of the five tabs keeps its own history.

**Flutter 3.43 (beta channel) / Dart 3.12.** The SDK constraint in
`pubspec.yaml` is `^3.12.0-210.2.beta`. This is deliberate but worth knowing:
the project uses language features (null-aware collection elements, `RadioGroup`)
that require this SDK. Moving to a stable channel once 3.43 ships is a
constraint bump and nothing more.

---

## How the app talks to the backend

Everything goes through the website's own REST API at `https://pinorpinor.com`.
There is **no second backend, no second database, and no Supabase client in the
app at all.**

That last point is not an oversight. The Pinorpinor backend keeps its Postgres
data API closed — `anon` and `authenticated` hold no grants on `public`, and RLS
is enabled on every table — and its media bucket is private. A mobile client has
nothing it could usefully hold, so it holds nothing.

### Authentication

The website uses NextAuth's credentials provider, which issues an `HttpOnly`
JWT session cookie. The app speaks that same flow rather than forking the
backend to add a second auth scheme:

```
GET  /api/auth/csrf                  → csrfToken + csrf cookie
POST /api/auth/callback/credentials  → session cookie (401 on a bad credential)
GET  /api/auth/session               → the session, or {} when it is invalid
```

The resulting cookie is stored in **Android Keystore / iOS Keychain** via
`flutter_secure_storage` and attached to every request by `ApiClient`. Dio's own
cookie manager is not used: it writes to disk in the clear.

Reusing the browser flow inherits every protection the website already has —
including the account re-read inside `requireAuth()` that makes a suspension take
effect immediately rather than when a 30-day JWT expires.

### Media

Uploads are direct-to-storage, exactly as the website performs them:

1. `POST /api/upload/presigned-url` — the server validates type, size and the
   per-member cap, **generates the storage key itself**, and returns a
   short-lived signed URL.
2. `PUT` the bytes straight to Supabase Storage using that URL. No file passes
   through the app server; the app holds no storage credential.
3. `POST /api/upload/confirm` — the server re-checks the key belongs to the
   caller and that an object exists there, then writes the row with
   `isApproved: true`.

**Uploads publish immediately, and moderation is reactive.** This reversed on
2026-08-14: media used to be held until a moderator released it, and now it is
publicly visible the instant the transfer finishes. The admin queue can still
take an item down, which deletes the object from the bucket rather than merely
hiding the row.

So `isApproved: false` now means **taken down**, not *queued* — and no screen in
the app says "awaiting review", because nothing is. It is also an open App Store
guideline 1.2 gap; see `docs/STORE_READINESS.md`.

Reads use short-lived signed URLs (one hour) embedded in the API's JSON, or the
stable `/api/media/<id>` proxy where a URL must outlive a signature.

---

### The web build is a layout scaffold, not a supported target

`flutter build web` works and `web/` is checked in, but **the app cannot
function in a browser** and is not shipped there. Two reasons, both structural:

- **CORS.** The website sends no `Access-Control-*` headers at all — verified by
  grepping its source, not assumed — so a page served from `localhost` is
  blocked on every API call.
- **The session cookie.** Auth depends on an `HttpOnly` NextAuth cookie attached
  by hand in `ApiClient`. A browser will neither expose it to JavaScript nor
  send it cross-site, so no signed-in flow can work regardless of CORS.

What the web build *is* good for is looking at the UI quickly without a device:
layout at various widths, navigation, the 18+ gate, form validation and the
services selector are all real. Everything network-shaped renders its error or
empty state.

```bash
flutter build web --no-tree-shake-icons
python -m http.server 8765 --directory build/web
```

Do not add web to the release pipeline, and do not "fix" the CORS failure by
asking the website to open its origin — that would weaken a real boundary for a
target nobody ships.

---

## Prerequisites

- Flutter **3.43.0-0.3.pre** (beta channel) or newer
- Android SDK 36 with build-tools 36.1.0, and JDK 17+
- For iOS: macOS with Xcode 15+ (see [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md))

```bash
flutter --version
flutter doctor
```

---

## Getting started

```bash
git clone https://github.com/Hubert24hrs/pinorpinor-app.git
cd pinorpinor-app
flutter pub get
flutter run
```

That is the whole setup. There is no `.env` to fill in, because there are no
secrets to supply — see [Configuration](#configuration).

---

## Configuration

All build-time configuration lives in `lib/core/config/app_config.dart`, and
every value in it is public information. To point the app at a different origin:

```bash
flutter run --dart-define=PINORPINOR_API_ORIGIN=https://staging.pinorpinor.com
```

```bash
flutter build appbundle --release --dart-define=PINORPINOR_API_ORIGIN=https://pinorpinor.com
```

**What the app does not contain, and must never contain:** the Supabase
service-role key, the Supabase anon key, the Paystack secret or public key, the
`CRON_SECRET`, `NEXTAUTH_SECRET`, database credentials, or any email/SMS
provider key. All of those are server-side on the website and stay there. A
Flutter binary is trivially unpackable; anything shipped in one is published.

---

## Project layout

```
lib/
  core/
    config/          app_config.dart — origin, limits, TTLs
    constants/       countries.dart — the list the backend accepts
    network/         api_client.dart, api_exception.dart, session_store.dart
    routing/         app_router.dart, app_routes.dart, deep_links.dart
    theme/           app_colors.dart, app_theme.dart, responsive.dart
    utils/           validators.dart, time_ago.dart, app_log.dart
    providers.dart   composition root
  data/
    models/          typed mirrors of the API's shapes
    repositories/    auth, profile, discovery, messaging, media,
                     notifications, credits, safety, whatsapp
  features/
    auth/            splash, login, join, password reset
    home/            shell + landing screen
    discovery/       browse grid, filters
    profile/         public profile, own account, editor
    media/           picker, upload manager, full-screen viewer
    messaging/       conversation list, thread, matches
    notifications/   alerts, contact-request inbox
    verification/    email and phone OTP
    credits/         wallet, boosts, ledger
    moderation/      report and block
    settings/        preferences, blocked list, account deletion
  shared/
    widgets/         brand, profile card, states, images
    utils/           legal links
test/
  unit/              validators, models, deep links, HTTP client
  widget/            profile card, login, join, report/block
  helpers/           fakes and pump helpers
integration_test/    end-to-end flows against a scripted backend
tool/                brand image generator
docs/                the documents listed at the end of this file
```

---

## Business rules worth knowing

These are the backend's rules. The app reproduces them; it does not invent them,
and it is never the thing enforcing them.

**18+ only.** Date of birth is validated server-side at registration. The app's
date picker cannot offer a date under 18 years ago, and `Validators.birthDate`
repeats the check, but `/api/member/join` is the gate.

**Women list publicly; men do not.** A woman's profile is created with
`isPublic: true` and featured for its first 24 hours. A man's is created
`isPublic: false` and is never listed. Anonymous callers are hard-limited to
women's profiles regardless of any query parameter.

**Only lady accounts can upload media.** `/api/upload/presigned-url` returns 403
for anyone else, so the media screen explains rather than offering controls that
would fail.

**Discovery never crosses borders.** A signed-in member is pinned to their own
country; a visitor may pick one. `ProfilePage.pinned` is what tells the UI
whether to offer the control at all.

**Phone numbers are never published.** A member's number lives on the server and
is never in any JSON body. The WhatsApp button creates a `ContactRequest`; only
after the owner accepts does `/api/profile/<username>/whatsapp` resolve a
redirect. A declined requester gets the same response as someone who never asked.

**Media is held for moderation.** `isApproved` defaults to false and only the
admin queue can change it.

**Credits are sold over WhatsApp, not in the app.** Card payment is switched off
on the backend (`PAYSTACK_ENABLED=false`; the payment routes answer 503). The app
ships no purchase flow — see
[docs/STORE_READINESS.md](docs/STORE_READINESS.md) for why that also keeps it
inside both stores' payment rules.

---

## Testing

```bash
flutter analyze            # 0 issues
flutter test               # unit + widget
flutter test integration_test/app_flow_test.dart   # needs a device/emulator
```

Current state: **260 tests, all passing; analyzer clean; debug APK builds.**

| Gate | Result |
| --- | --- |
| `flutter analyze` | No issues found |
| `flutter test` | 260 passing |
| `dart format .` | Clean |
| `flutter build apk --debug` | `app-debug.apk` produced (116.1 MB, arm64) |
| `flutter build appbundle --release` | Not run — needs the owner's `key.properties` |

| Suite | Covers |
| --- | --- |
| `test/unit/validators_test.dart` | username rules, email, password floor, the 18+ age gate, E.164 phone, message length |
| `test/unit/auth_contract_test.dart` | the sign-in identifier rule (username **or** email, split on the `@`), and the registration constraints the route enforces |
| `test/unit/services_catalogue_test.dart` | **reads the website's real `services.ts`** and fails if the app's catalogue has drifted from it |
| `test/unit/money_test.dart` | minor-unit arithmetic, including the zero-decimal currencies (JPY, KRW, VND, RWF, XOF/XAF) where dividing by 100 is the bug |
| `test/unit/presence_test.dart` | the four activity buckets, and that an unknown value degrades to the least revealing one |
| `test/unit/favorites_test.dart` | shortlist parsing, and that `savedAt` stays off the shared profile model |
| `test/unit/models_test.dart` | every response shape the API returns, including the three that differ between routes, and malformed payloads |
| `test/unit/deep_links_test.dart` | which links the app claims, and that it never resolves one outside its own route table |
| `test/unit/api_client_test.dart` | cookie storage, cookie attachment, `Set-Cookie` harvesting, session teardown on 401/suspension, status→error mapping |
| `test/unit/android_manifest_test.dart` | the Android wiring that only a device disagrees with — see "The trap that actually shipped" in `CLAUDE.md` |
| `test/widget/profile_card_test.dart` | badges, verified tick, semantics, overflow at 320px |
| `test/widget/login_screen_test.dart` | validation before request, identifier folding, error surfacing, layout at 320px and iPad |
| `test/widget/join_screen_test.dart` | the six-field flow, the unrecoverable-password warning, the 18+ gate, E.164 enforcement |
| `test/widget/report_block_test.dart` | both safety controls, confirmation copy, signed-out handling |

Two of these guard a class of bug the rest cannot reach. `services_catalogue_test.dart`
and `auth_contract_test.dart` exist because on 2026-08-14 the website changed
two contracts, the app kept sending the old shapes, and **every gate stayed
green**: the analyzer, the whole suite, and the APK build. A fake repository has
whatever signature the real one has, so a widget test cannot notice. Where a
contract can be read off the website's source, read it off the website's source.

The integration test drives the real app widget with a scripted backend. It
deliberately does not hit production — a suite that created real accounts and
real reports on a live platform with real members would be worse than none.

**The app has not been run on a device or emulator.** The development machine's
only AVD cannot start (`x86_64 emulation currently requires hardware
acceleration` — the Android Emulator hypervisor driver is not installed, and
installing it is an admin-level change with a reboot). Everything above is
compile-time and widget-level verification. Camera capture, a real upload over a
mobile connection, the WhatsApp handoff, and deep-link intent resolution have
**not** been exercised end to end — see `docs/STORE_READINESS.md` §
"On-device verification".

To regenerate the brand artwork:

```bash
flutter test tool/generate_brand_images_test.dart
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

---

## Release builds

```bash
flutter build apk --debug                  # local install
flutter build appbundle --release          # the .aab Play expects
```

Release signing reads `android/key.properties`, which is gitignored. When that
file is absent the release build falls back to debug signing so the command
still succeeds locally — such a build **cannot** be uploaded to Play. Full
instructions, including generating and storing the upload key, are in
[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

---

## Deep links

Two forms are handled, both resolved by `lib/core/routing/deep_links.dart`:

```
pinorpinor://profile/zainab
https://pinorpinor.com/zainab
```

Supported destinations: profiles, conversations, notifications, verification,
credits, settings, discovery, sign-in, sign-up, and password reset (which
carries its token through to the reset screen).

A link the app does not claim resolves to `null` and is ignored — it can never
become an external URL or an action. Verified App Links and Universal Links each
need a file published on the website; see
[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

---

## Notifications

The app raises **local** notifications and keeps badge counts current by polling
`/api/notifications` and `/api/conversations` while it is in the foreground.

Server-pushed notifications are **not implemented**, and that is a backend gap
rather than a client one: there is no device-token table, no FCM or APNs
credential, and no send path anywhere in the Pinorpinor backend. Adding
Firebase Messaging to the client alone would produce an app that registers for
notifications nobody can send. The required backend change is specified in
[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) § Push notifications.

---

## Security

Summary — the detail is in [docs/SECURITY.md](docs/SECURITY.md):

- No keys, tokens or secrets of any kind in the client
- Session cookie in Keystore/Keychain, never `SharedPreferences` or a file
- Cleartext HTTP refused on Android; ATS left strict on iOS
- Backend authorisation is the only authorisation; client guards are convenience
- Uploads validated client-side for speed and server-side for truth; storage
  keys are server-generated and ownership-checked
- EXIF (including GPS) stripped from every image during compression
- Deep links cannot resolve outside the app's route table
- Logging carries no user content and is compiled out of release builds
- Report, block and account deletion all reachable in two taps

---

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `flutter pub get` fails on the SDK constraint | Stable channel Flutter | `flutter channel beta && flutter upgrade` |
| Gradle: `Failed to find target with hash string 'android-37'` | A dependency was upgraded to one compiling against SDK 37, which ships only as the minor-versioned `android-37.0` platform that AGP 8.11 cannot address | Keep `flutter_secure_storage` on the 10.x line, or move to AGP 8.13+ and set `compileSdkMinor` |
| Gradle: `plugin X requires Android SDK version N or higher` | Same root cause, reported before the build starts | As above |
| Gradle stalls in dexing — CPU near zero, no error, no output for many minutes | Memory starvation. Flutter's template asks for an 8GB heap plus a 4GB metaspace; with an IDE and a browser running, the dex workers cannot get memory and D8 hangs rather than failing | `android/gradle.properties` caps the heap at 3GB. Close other applications, or lower it further |
| APK installs but dies the instant the icon is tapped | `MainActivity.kt`'s `package` no longer matches `namespace` in `build.gradle.kts`, so the manifest's relative `.MainActivity` resolves to a class that does not exist. Nothing in the build catches it | Move the Kotlin file to match the namespace and update its `package` line. `test/unit/android_manifest_test.dart` guards this now — run `flutter test` |
| Sign-in always fails with "Incorrect email or password" | The origin has no such account, or the account is suspended | Check the origin with `--dart-define`; suspension is intentional |
| Images load then go blank after an hour | Signed URLs expired | Pull to refresh; the API re-signs on every read |
| Images 404 immediately after a delete | Correct — signed URLs revoke at once | Not a bug |
| Upload returns 403 "Only lady accounts can upload media" | Account role is not `WOMAN` | Working as intended |
| Upload returns 403 "Invalid storage key" | Stale key after re-login | Re-run the picker; the presign step regenerates it |
| A photo uploads but never appears publicly | Held for moderation | An admin releases it from the website's Media Queue |
| WhatsApp button says "not accepted your contact request" | No `ACCEPTED` row for that pair | The owner must accept first |
| Release build installs but Play rejects it | Signed with the debug key | Create `android/key.properties` — see docs/DEPLOYMENT.md |
| `https://` links open in the browser, not the app | `assetlinks.json` / `apple-app-site-association` not published | See docs/DEPLOYMENT.md |

---

## Further documentation

| Document | What it covers |
| --- | --- |
| [docs/FEATURE_PARITY.md](docs/FEATURE_PARITY.md) | Every website feature against its app counterpart, with status |
| [docs/SECURITY.md](docs/SECURITY.md) | Threat model, trust boundaries, known risks |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Play Console and App Store Connect, step by step |
| [docs/STORE_READINESS.md](docs/STORE_READINESS.md) | The checklist, and what only the owner can do |
| [docs/ENVIRONMENT_SETUP.md](docs/ENVIRONMENT_SETUP.md) | What credentials each environment needs, and where they live |

---

## Repository

- **App:** <https://github.com/Hubert24hrs/pinorpinor-app>
- **Website (source of truth):** <https://github.com/Hubert24hrs/pinorpinor>

The two are separate repositories on purpose. This one contains no server code
and no server secrets.
