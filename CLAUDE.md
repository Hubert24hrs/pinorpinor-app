# Pinorpinor Mobile — Project Memory

> **Read this before starting work.** It records the verified state of the app so
> a new session continues from here rather than treating this as a fresh
> codebase. Trust the source over this file where they disagree, and update this
> file when they do.

Last verified: **2026-08-14**. Analyzer clean, 127 tests passing, debug APK
builds. Local: `C:\Users\HP\.gemini\antigravity-ide\scratch\pinorpinor-app`.
Repository: `https://github.com/Hubert24hrs/pinorpinor-app`, branch `main`.

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
| 18+ only | `/api/member/join` validates `birthDate` server-side |
| Women list publicly, featured 24h; men's profiles are `isPublic: false` and never listed | `/api/member/join` |
| Anonymous callers only ever see women | `resolveVisibleGenders()` — hard-limited, ignores client input |
| Only lady accounts may upload media | `/api/upload/presigned-url` returns 403 otherwise |
| Discovery never crosses borders | `resolveViewerCountry` pins a signed-in member |
| All media held for moderation (`isApproved: false`) | Only `/api/admin/media` can release it |
| Phone numbers never published; WhatsApp needs an ACCEPTED `ContactRequest` | `/api/profile/[u]/whatsapp` |
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
*(The swipe deck was the fourth entry here until 2026-08-14. It now exists —
`features/discovery/swipe_screen.dart` — and is the app's only surface for
`/api/swipe`, which the website still does not expose.)*

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
flutter test        # expect: 127 passing
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
| `flutter test` | 127 passing |
| Debug APK | Builds (95.9 MB, arm64) |
| Release `.aab` | **Not run** — needs the owner's `android/key.properties` |
| iOS build | **Blocked** — needs macOS + Xcode |
| On device / emulator | **Never run.** The machine's only AVD cannot start: `x86_64 emulation currently requires hardware acceleration` — the hypervisor driver is not installed |
| Signed-in API flows | **Not verified against a live account.** Written against contracts read from the website source |

Untested as a result: camera capture, a real upload over mobile data, video
playback, the WhatsApp handoff, deep-link intent resolution, notification
permission prompts. Named in `docs/STORE_READINESS.md`.

**Do not claim any of these work.** The public endpoints *were* exercised
against production; the 401-on-bad-credential shape was confirmed there.

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

1. **Get it onto a real device.** Every "not verified" row above collapses the
   moment someone installs the debug APK on an Android phone and walks the
   journey in `docs/DEPLOYMENT.md`. The swipe deck in particular has never been
   touched by a finger — its gesture thresholds are reasoned, not felt.
2. **Create the upload keystore** and produce a signed `.aab`.
3. **Active-filter chips on Discover** — the second pattern worth taking from
   the aura review, and the smaller half. The filter sheet exists; what is
   missing is seeing and dropping one filter without reopening it.
4. Owner: approve some real member media so discovery is not empty, and set the
   SMS provider key so phone verification can complete.
