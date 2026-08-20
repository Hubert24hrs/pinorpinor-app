# Pinorpinor Mobile — Project Memory

> **Read this before starting work.** It records the verified state of the app so
> a new session continues from here rather than treating this as a fresh
> codebase. Trust the source over this file where they disagree, and update this
> file when they do.

Last verified: **2026-08-20**. Analyzer clean, **239 tests passing**, debug APK
builds. Local: `C:\Users\HP\.gemini\antigravity-ide\scratch\pinorpinor-app`.
Repository: `https://github.com/Hubert24hrs/pinorpinor-app`, branch `main`.

## Where the last session stopped

Everything is committed and pushed; the working tree is clean.

**The website changed underneath the app on 2026-08-14, and both halves of
account access were broken.** Neither break produced a compile error, a failing
test, or a bad build. Both are now fixed; this is the thing to understand before
touching auth again.

1. **Sign-in.** `authorize()` in the website's `src/lib/auth.ts` now reads
   `credentials.identifier` and chooses the column by whether the value contains
   an `@`. The app was posting `email`, so `identifier` arrived undefined,
   `authorize()` returned null on its first guard, and **every sign-in answered
   401** — which is exactly what a wrong password looks like. No signed-in flow
   in this app could ever have worked against the current backend.

2. **Registration.** `/api/member/join` was rebuilt down to six fields:
   `username`, `password`, `phone`, `bio`, `services`, `isAdult`. The app was
   still sending `email`, `displayName`, `birthDate`, `gender` and `countryCode`
   as required — none of which is read any more — and was never sending
   `isAdult`, which the route rejects outright.

The lesson generalises, and it is the reason `test/unit/services_catalogue_test.dart`
exists: **a client and a server can agree at compile time and disagree at run
time, and only a device tells you.** Where a contract can be read off the
website's source, read it off the website's source.

### What else moved on the website, and is now mirrored

| Change | Migration / commit | What the app does now |
| --- | --- | --- |
| Email is optional; login is by username | `20260814000000_emailless_signup` | Sign-in field is "Username or email"; join collects no address and **warns that a forgotten password cannot be recovered** |
| Media publishes on upload | same migration | Every "awaiting review" string is gone. `isApproved: false` now means *taken down*, not *queued* |
| Services catalogue | `20260813010000_profile_services` | `lib/core/constants/services.dart`, **generated** from `src/lib/services.ts` |
| Rates in minor units | `20260814010000_rates_location_views` | `lib/core/utils/money.dart` + `MemberRates` |
| `state`, `build`, `languages` | same | On `ProfileSummary` and the detail screen |
| Presence buckets | `users.lastSeenAt` + `src/lib/presence.ts` | `Presence` enum; "Online now" badge only |
| Favourites | `/api/favorites` | `FavoritesRepository`, `/favorites` screen, heart on profiles |
| Online feed | `/api/public/online` | `DiscoveryRepository.online()` |
| Permanent deletion | `/api/account` | Settings offers deactivate *and* delete, the latter password-confirmed |
| Date proposals | `/api/dates` | `DatesRepository` |

**Pick up here:** the device-test checklist under "Next steps". Launch on real
hardware is *still* unconfirmed — see "Verification status", which is honest
about what that means.

If the APK does not open, get a crash log rather than guessing:

```
adb uninstall com.pinorpinor.app.debug   # a stale install looks identical to a broken build
adb install build/app/outputs/flutter-apk/app-debug.apk
adb logcat -d *:E | Select-String -Pattern "pinorpinor|AndroidRuntime" -Context 0,15
```

The expected first screen is the **18+ notice**, not the home screen. A white or
black screen instead is a different fault, and the logcat will name it.

The build is `--target-platform android-arm64` only, because a universal build
kept timing out on this machine. That covers essentially every phone from 2016
onward; `INSTALL_FAILED_NO_MATCHING_ABIS` means the fix is a universal build,
not a code change.

---

## The catalogue is generated, not hand-maintained

`lib/core/constants/services.dart` mirrors the website's `src/lib/services.ts`.
Do not edit it by hand. Drift between the two is silent and asymmetric:

- an id the app knows and the server does not is **dropped by
  `sanitizeServiceIds` on save**, so a member's selection vanishes with no
  error;
- an id the server knows and the app does not **renders as a raw slug**
  ("gfe") on a public profile.

`test/unit/services_catalogue_test.dart` reads the real TypeScript and fails on
either. It has already caught one live divergence: the catalogue was reworked
from an explicit list to a companionship one on 2026-08-20, and the test failed
within the same session that generated the file.

Regenerate rather than retype. The 35 pre-2026-08-20 ids are still present as
`retired: true` in the `archived` group — that is the website's own
retire-don't-delete rule, and it is why a profile written before the change
still renders a label instead of a slug.

---

## What this is

The native mobile client for [Pinorpinor](https://pinorpinor.com), a premium
social discovery and meetup platform, Nigeria-focused, adults only. It is the
mobile counterpart of the existing website — **same backend, same database, same
accounts** — not a separate product.

The website repository (`Hubert24hrs/pinorpinor`) is the source of truth for
every business rule. It has its own `CLAUDE.md`; read that one for backend
detail.

> **Another agent works on the website.** Do not edit
> `scratch/pinorpinor` from this project. Coordinate through the API contract.

---

## The single most important architectural fact

**The app talks to the Next.js REST API at `https://pinorpinor.com`. It does not
talk to Supabase, and it holds no keys of any kind.**

This is not an oversight, and it must not be "fixed":

- Migration `20260812030000_lock_down_postgrest` on the website revokes **all**
  privileges on schema `public` from `anon` and `authenticated`, changes
  `ALTER DEFAULT PRIVILEGES` so future tables are not granted either, and
  enables RLS on every table. There are **no RLS policies** — it is deny-all.
- So `supabase_flutter` with the anon key would receive `401 permission denied`
  on every query. Adding it would not work, and would ship a key that reads
  `users` (phone numbers, bcrypt hashes) the day somebody restores those grants
  by accident.
- The media bucket is **private**. Reads are short-lived signed URLs the server
  issues; uploads use a signed upload URL the server generates per file.

If a future task says "the backend is Supabase, wire the app to it directly",
that premise is wrong for this app. Say so and keep the REST architecture.

### Authentication

The backend has no bearer-token endpoint. It issues an `HttpOnly` NextAuth JWT
cookie, and `requireAuth()` reads exactly that on every call. The app reproduces
the browser flow:

```
GET  /api/auth/csrf                   → csrfToken + csrf cookie
POST /api/auth/callback/credentials   → session cookie (verified: 401 on a bad
                                        credential, form-encoded body)
GET  /api/auth/session                → claims, or {} when invalid
```

Chosen over adding a mobile token endpoint because it inherits `requireAuth()`'s
per-request account re-read — the only thing that makes a ban bite before the
30-day JWT expires. The cookie lives in Keystore/Keychain via
`flutter_secure_storage` and is attached by hand in `ApiClient`; Dio's own cookie
manager is not used because it writes to disk in the clear.

---

## Technology

- **Flutter 3.43.0-0.3.pre (beta) / Dart 3.12.** The SDK constraint in
  `pubspec.yaml` is `^3.12.0-210.2.beta`. Deliberate — the code uses null-aware
  collection elements (`'k': ?v`) and `RadioGroup`, both of which need it.
- **Riverpod** (`flutter_riverpod`) for state. Repositories are plain classes
  behind providers, which is what makes every screen testable with a fake.
- **go_router** with `StatefulShellRoute.indexedStack` — each of the five tabs
  keeps its own history.
- **Dio** for HTTP, with a hand-rolled cookie interceptor.
- No code generation. No `build_runner`. Models are hand-written `fromJson`.

---

## Architecture

```
lib/
  core/
    config/app_config.dart        origin, limits, TTLs — all public values
    constants/countries.dart      the list the backend accepts
    network/                      api_client, api_exception, session_store
    routing/                      app_router, app_routes, deep_links
    storage/                      acknowledgement_store (age gate)
    theme/                        app_colors, app_theme, responsive
    utils/                        validators, time_ago, app_log
    providers.dart                composition root
  data/
    models/                       typed mirrors of the API's shapes
    repositories/                 one class per API area; only place a URL appears
  features/                       screens + controllers, by product area
  shared/widgets/                 brand, profile card, states, images
```

**Layering rule:** a screen never builds a URL. Repositories own the API surface;
screens consume providers. Breaking this is what makes an app untestable.

---

## Business rules the app reproduces

These are the **backend's** rules. The app mirrors them so a member gets an
answer without a round trip; it is never the thing enforcing them.

| Rule | Where it really lives |
| --- | --- |
| 18+ is an assertion, not a date | `/api/member/join` requires `isAdult === true`. `birthDate` stays **null** for every account created since 2026-08-14, so nothing downstream may assume an age exists |
| Registration creates women only | `/api/member/join` forces `gender: WOMAN`. It is not a general signup route |
| The country comes from the phone number | `countryFromPhone`. A number that does not resolve leaves `countryCode` null — and discovery scopes on it, so the member is listed nowhere |
| Login accepts a username **or** an email | `authorize()` splits on the presence of an `@` |
| Anonymous callers only ever see women | `resolveVisibleGenders()` — hard-limited, ignores client input |
| Only lady accounts may upload media | `/api/upload/presigned-url` returns 403 otherwise |
| Discovery never crosses borders | `resolveViewerCountry` pins a signed-in member |
| **Media publishes on upload** | `isApproved: true` on insert since 2026-08-14. Moderation is reactive: rejecting deletes the object from the bucket |
| Media needs `isApproved` **and** `isPublic` | The first is the moderator's decision, the second the owner's. Both must hold |
| Services are ids from a fixed catalogue | `sanitizeServiceIds` drops anything else. Never free text |
| Rates are integers in minor units | And minor units are not always hundredths — see `lib/core/utils/money.dart` |
| Last-active is a coarse bucket, never a timestamp | `src/lib/presence.ts`. A precise time is a movement log |
| Favourites are private and one-directional | `/api/favorites`. The saved member is never told, and no endpoint would tell them |
| Phone numbers never published; WhatsApp needs an ACCEPTED `ContactRequest` | `/api/profile/[u]/whatsapp` |
| Deleting an account erases bucket objects **before** rows | `/api/account`. The other order strands every photo |
| Credits sold over WhatsApp; card payment off (`503`) | `PAYSTACK_ENABLED=false` |

**`ProfilePage.pinned`** is what tells the UI whether to offer a country picker.
For a signed-in member the backend ignores the `country` parameter, so showing
the control would be a lie.

---

## Things that are deliberately absent

Each of these looks like a gap and is not. Do not "complete" them without
reading the reason.

- **No in-app purchase.** Credits are a digital good; if the app sold them,
  Play Billing and StoreKit would be mandatory. The sale happens off-app between
  member and operator, exactly as the website already works.
  `CreditsRepository.initCardPayment` is a named throwing method so the decision
  is visible where someone would look for it.
- **No push notifications.** The backend has no device-token table, no FCM/APNs
  credential and no send path. Adding `firebase_messaging` client-side would
  register for notifications nobody can send, and would break the Android build
  without a `google-services.json`. The app polls in the foreground. Backend
  change specified in `docs/DEPLOYMENT.md` § Push notifications.
- **No realtime messaging.** No websocket, no SSE, and the Supabase data API is
  closed so Realtime is unavailable. Threads poll every 12s while open.
- **No certificate pinning.** Pinning a Vercel domain breaks on every automatic
  cert rotation; the realistic failure is a bricked app in members' hands.
- **No dark mode.** The website ships one light identity with no switcher. The
  theming is structured to accept one later.
*(The swipe deck was an entry here until 2026-08-14. It now exists —
`features/discovery/swipe_screen.dart` — and is the app's only surface for
`/api/swipe`, which the website still does not expose. Favourites, the online
feed and date proposals joined it on 2026-08-20.)*

**Also deliberately absent: a media visibility toggle.** `media.isPublic` is a
real column and the owner is meant to control it, but no client endpoint sets
it — only admin paths do. The app reads it and does not offer a switch, because
a control that silently fails is worse than no control. If the website adds
`PATCH /api/media/[id]`, this becomes a ten-line change.

**And no "who saved me".** The backend has no endpoint for it, by design.
Favourites are one-directional and the saved member is never told; being able
to see who has bookmarked you would make the feature a surveillance signal on a
platform where women are browsed by strangers. Do not add it client-side by
diffing lists.

---

## Design system

Transcribed from the website's `src/app/globals.css` into
`core/theme/app_colors.dart`. If the site changes `--accent-rose`, exactly one
constant changes here.

Rose `#C2446E` → burgundy `#7C1D38` gradient, gold `#D4AF37`, warm ivory
`#FAF8F5`. Playfair Display for editorial headings, Plus Jakarta Sans for
everything else — both **bundled** as variable fonts (`assets/fonts/`, OFL
licences included), not fetched at runtime.

**Load-bearing:**
- 16px minimum on form controls — matches the website's iOS zoom guard.
- 44px minimum touch targets (`AppSpacing.minTouchTarget`).
- `ContentContainer` width-caps content on tablets. Without it an iPad renders a
  single column of text a metre wide.
- Text scale is clamped to 0.85–1.4 so an extreme accessibility setting cannot
  break a 320px layout.

---

## Testing

```bash
flutter analyze     # expect: No issues found
flutter test        # expect: 239 passing
flutter build apk --debug
```

`analysis_options.yaml` is tightened past `flutter_lints`: `avoid_print`,
`use_build_context_synchronously` and `unawaited_futures` are **errors**. That
last one has already caught a real bug (an unawaited `context.push` swallowing a
navigation failure). `avoid_redundant_argument_values` is deliberately off.

Tests found three genuine defects so far: two RenderFlex overflows (brand mark,
sign-in footer) and the unawaited push. Keep the overflow assertions — they are
cheap and they work.

The integration test drives the real app widget against a **scripted** backend.
It deliberately does not hit production: a suite that created real accounts and
reports on a live platform with real members would be worse than none.

---

## Verification status — be honest about this

| Area | Status |
| --- | --- |
| `flutter analyze` | Clean |
| `flutter test` | 239 passing |
| Debug APK | Builds (116.1 MB, arm64, 49.7s incremental) |
| Release `.aab` | **Not run** — needs the owner's `android/key.properties` |
| iOS build | **Blocked** — needs macOS + Xcode |
| On device — install | **Confirmed.** The APK installs on the owner's phone |
| On device — launch | **One crash found and fixed** (wrong `MainActivity` package). The corrected build has **not yet been confirmed to launch** |
| Emulator | **Unavailable.** The machine's only AVD cannot start: `x86_64 emulation currently requires hardware acceleration` — the hypervisor driver is not installed |
| Signed-in API flows | **Not verified against a live account.** Written against contracts read from the website source |
| Sign-in field name | **Fixed, not verified.** The `identifier` contract was read from `src/lib/auth.ts`. It has not been exercised against a live account |
| Six-field registration | **Fixed, not verified.** Same: read from the route, never run |
| Services catalogue parity | **Verified by test**, against the local website checkout |
| Minor-unit money maths | **Verified by test**, including the zero-decimal currencies |

Untested as a result: camera capture, a real upload over mobile data, video
playback, the WhatsApp handoff, deep-link intent resolution, notification
permission prompts. Named in `docs/STORE_READINESS.md`.

**Do not claim any of these work.** The public endpoints *were* exercised
against production; the 401-on-bad-credential shape was confirmed there.

A specific caution about the two contract fixes. They were derived by reading
the website's source, which is the best available evidence and is *not* the
same as a successful round trip. The previous versions were also derived that
way, and were correct when written. **The first signed-in flow on a real device
is what turns these from "should work" into "works".**

---

## The trap that actually shipped

**`MainActivity.kt`'s package must equal `namespace` in `build.gradle.kts`.**

The manifest registers the activity as `android:name=".MainActivity"` — a
*relative* name that Android resolves against the namespace. The namespace and
`applicationId` were renamed from `com.pinorpinor.pinorpinor_app` to
`com.pinorpinor.app` and the Kotlin file was left where it was.

Everything reported success: Kotlin compiled, the manifest merged, Gradle built,
`flutter analyze` and 158 tests were green, and the APK installed on a real
phone. It then died the instant the icon was tapped —
`ClassNotFoundException: com.pinorpinor.app.MainActivity`.

Nothing in the Flutter toolchain catches this, because from its point of view
nothing is wrong. `test/unit/android_manifest_test.dart` now does: it reads the
real Gradle and manifest files and asserts the Kotlin file exists at the path
the namespace implies and declares that package. It also guards the permission
set, the cleartext refusal, the deep-link filters and the WhatsApp `<queries>`
entry — all things that fail only at runtime, on a device.

If you rename the namespace again, move the Kotlin file and change its `package`
line in the same commit.

---

## Android build — three traps already hit

1. **`flutter_secure_storage` is pinned to `^10.0.0`.** Version 11 compiles
   against SDK 37, which ships only as the minor-versioned `android-37.0`
   platform, and AGP 8.11 looks for `android-37` and fails. Needs
   `compileSdkMinor` (AGP 8.13+). 10.x uses the same Keystore-backed storage.
2. **Core library desugaring is required** by `flutter_local_notifications`
   (it uses `java.time`). Without it the build stops at
   `checkDebugAarMetadata`.
3. **The Gradle heap is capped at 3G** in `android/gradle.properties`. Flutter's
   template asks for 8G; on a 16GB machine with an IDE open, D8 does not fail —
   it *hangs*. Two builds sat at zero CPU for fifteen minutes with no output.

---

## Reference projects

**`ibhanu/aura`** was evaluated 2026-08-14 as an architectural reference.
Verdict in `docs/REFERENCE_REVIEW.md`. Summary: it is a polished **UI
prototype** — auth stubbed, `fromJson: 0`, `validator: 0`, 41 Unsplash mock
profiles, the only test being the unmodified Flutter counter template. Its GetX
+ get_it + direct-Supabase architecture is **not** adopted; its swipe-deck
gesture handling and filter-chip patterns are worth borrowing.

---

## Git

- Repository: `https://github.com/Hubert24hrs/pinorpinor-app`, branch `main`.
- Push uses the `gh` credential helper — already authenticated as `Hubert24hrs`.
- Never stage `key.properties`, `*.jks`, `*.p12`, `.env`, `google-services.json`.
  All are gitignored; verify before every push.
- The website is a **separate repository**. Never push app code to it.

---

## Next steps

In priority order:

1. **Get it onto a real device.** In progress — an APK is with the owner. Build
   a fresh one with:

   ```
   flutter build apk --debug --target-platform android-arm64
   → build/app/outputs/flutter-apk/app-debug.apk
   ```

   Drop `--target-platform` for a universal build if arm64 will not install
   (expect it to take considerably longer here).

   What to check, hardest-to-fake first:

   | # | Check | Why it cannot be verified any other way |
   | --- | --- | --- |
   | 1 | Swipe deck feel (Discover → cards icon) | 110px commit threshold and 0.18rad rotation cap are reasoned, never felt |
   | 2 | 18+ gate on first launch, absent on the second | Exercises `SharedPreferences` round-tripping on a real device |
   | 3 | Camera + photo upload (Profile → Photos and videos) | Crosses picker, compressor, presign, direct PUT and confirm — completely untested |
   | 4 | WhatsApp handoff after an accepted contact request | Depends on `LSApplicationQueriesSchemes` / package visibility resolving |
   | 5 | `adb shell am start -a android.intent.action.VIEW -d "pinorpinor://profile/test"` | Intent filter resolution is a manifest behaviour |
   | 6 | Splash → first frame handover | Android 12+ draws its own splash; a mismatch shows as a flash |

   Expect **discovery to be empty** — production has no approved member media,
   and a browser gets the same empty list. That is the platform's state, not a
   defect.

2. **Create the upload keystore** and produce a signed `.aab`. Nothing exists
   for this yet, deliberately: generating it means choosing passwords, and
   those belong to the owner. `android/key.properties` is absent, so a release
   build silently falls back to debug signing and Play will reject it — the
   intended failure mode.
3. **Active-filter chips on Discover** — the second pattern worth taking from
   the aura review, and the smaller half. The filter sheet exists; what is
   missing is seeing and dropping one filter without reopening it.
4. Owner: approve some real member media so discovery is not empty, and set the
   SMS provider key so phone verification can complete.
