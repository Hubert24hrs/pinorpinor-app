# Pinorpinor Mobile — Project Memory

> **Read this before starting work.** It records the verified state of the app so
> a new session continues from here rather than treating this as a fresh
> codebase. Trust the source over this file where they disagree, and update this
> file when they do.

Last verified: **2026-08-25**. Analyzer clean, **396 tests passing**, debug APK
builds. Local: `C:\Users\HP\.gemini\antigravity-ide\scratch\pinorpinor-app`.
Repository: `https://github.com/Hubert24hrs/pinorpinor-app`, branch `main`.

## Where the last session stopped

Everything is committed and pushed; the working tree is clean.

**The website changes contracts under this app, and the app keeps building.**
Four times in eleven days now. This is the single most important fact about
working on this repository, and the reason a growing share of the test suite
reads the website's own TypeScript.

| When | What the website did | What the app did about it |
| --- | --- | --- |
| 2026-08-14 | `authorize()` began reading `credentials.identifier`; `/api/member/join` rebuilt to six fields | Every sign-in answered 401 and every registration 400 |
| 2026-08-21 | Registration required `gender` **and** `primaryService` | Registration answered 400 on every attempt |
| 2026-08-22 | `hookupServices` renamed `serviceFeatures`; `birthYear` required | Registration 400 again, and every feature list saved into nothing |
| 2026-08-23 | Contact requests **deleted**, replaced by a paid unlock | Three endpoints the app called stopped existing; the inbox screen polled a 404 |

Each time: analyzer clean, every test green, APK built and installed.

**The 2026-08-22 break was the first one caught by a test rather than by a
member.** `test/unit/join_contract_test.dart` reads the real route file and
failed naming `birthYear`. That is the pattern worth extending: where a contract
can be read off the website's source, read it, and pin it with a test that reads
the same file.

### Start every session here

```
git -C ../pinorpinor log --oneline -15    # what changed under you
flutter test                               # what it broke
```

That pair is what surfaced the last two releases. The website shipped **twenty
commits in the three days** before 2026-08-25, so this is not a formality.

### What landed 2026-08-25 — the 2026-08-22/25 website releases, mirrored

| Website change | What the app does now |
| --- | --- |
| **`birthYear` required at registration** | Asked as one box on the service step, validated with the route's own bounds. Never synthesised into a `birthDate` |
| **`hookupServices` → `serviceFeatures`**, generalised to all six services | `lib/core/constants/service_features.dart`. Ids prefixed per catalogue, heading differs per service, switching service clears the column |
| **Contact requests deleted; a chat is now bought** | `ContactAccessRepository`. 100 credits each side, all or nothing. The inbox screen, its route and its menu entry are gone |
| **`relationshipIntent` dropped from the schema** | No longer sent. Second column after `dateTypes` to be silently discarded by zod |
| **Password reset over WhatsApp** | `features/auth/whatsapp_reset_screen.dart`, three steps. The join screen's "there is no way to reset" warning is gone, because it was false |
| **Sign in with a phone number** | The field accepts a username, an email **or** a number in any written form. Nothing is normalised client-side |
| **Admin password reset → `mustChangePassword`** | `PASSWORD_CHANGE_REQUIRED` is its own error kind, and the router pins the member to the change screen until it clears |
| **Credit top-ups with an admin queue** | `features/credits/top_up_screen.dart`. Records the request, then opens the WhatsApp message the server built |
| **Contact Us** | `features/support/support_screen.dart`, posting as the signed-in member |
| **A profile picture is compulsory to be listed** | The account screen warns when there is none, and registration ends at the photo step rather than at verification |

### Landed 2026-08-20

| What | Why it mattered |
| --- | --- |
| The platform menu | Five tabs, no drawer — most of the website was unreachable from a phone |
| Online Now, Videos, Locations | New screens. `online()` existed as a repository method with **no caller** |
| Deep links for every website section | `/faq`, `/videos`, `/events`, `/rooms`, `/feeds` all opened a bogus profile lookup |
| `/favorites` guarded | Deep-linkable but unprotected, so a signed-out visitor was told their *session* expired |
| Shortlist cleared on sign-out | `savedIdsProvider` survived the session; the next person on a shared phone saw the previous member's saved profiles |
| Profile edits actually save | `updateProfile` sent `dateTypes`, which `profileUpdateSchema` refuses; zod strips unknown keys silently, so every save "worked" and discarded the selection |

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

## The menu mirrors the website, and two files must move together

`lib/core/constants/navigation.dart` is a copy of the website's
`src/lib/navigation.ts` — same four sections, same order, same labels, with
Material equivalents of its Lucide icons. The website renders its sidebar *and*
its mobile drawer from that one file precisely so the two cannot drift; this is
the app's third reader of the same list.

Until 2026-08-20 the app had five tabs and **no menu at all**, so Online Now,
Videos, Locations, Reviews, FAQ, Safety and every Explore entry were
unreachable from a phone. `test/unit/navigation_test.dart` reads the real
TypeScript and fails when an entry exists there and not here.

Each entry declares how it opens, so nothing in the menu is decorative:

- `native` — the app has a screen.
- `placeholder` — **the website has not built it either.** Feeds, Events,
  Rooms, Adverts and Testimonials are its own `SectionPlaceholder` stubs, and
  the app repeats its wording verbatim so a member never gets two different
  explanations for the same absence.
- `website` — static content opens the real page, marked with an
  open-in-new glyph.

`/admin` is deliberately absent. An app carrying moderation tooling is an app
whose compromise carries it too.

### Adding a website section? Three files, same commit

This is the trap. Every section slug is a valid username shape
(`^[a-z0-9_]{3,20}$`), so a slug with no explicit case in `DeepLinks.resolve`
falls through to the username branch and opens **a profile lookup for a member
of that name** — `pinorpinor.com/faq` landed on "profile not found", and so did
`/videos`, `/events`, `/rooms` and `/feeds`.

1. `lib/core/constants/navigation.dart` — the menu entry.
2. `lib/core/routing/deep_links.dart` — claim it, or decline it explicitly.
   Never leave it to the default branch.
3. `lib/core/routing/app_routes.dart` — if its endpoint needs a session, add it
   to `protectedPrefixes`. `/api/favorites` does, and without the guard a
   signed-out visitor arriving by deep link is told their *session expired*,
   because `ApiClient` reads the resulting 401 as an invalidated session.

`/app` went through all three on 2026-08-22, and it is a link members actually
receive: every live-session option on the website points at it.

`deep_links_test.dart` reads the website's `src/app` directory and fails if any
top-level page resolves to a profile lookup for its own slug.

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

## The primary service, and the list under it

Added on the website 2026-08-21 and mirrored in
`lib/core/constants/primary_services.dart`. **Exactly one of six ids, required at
registration**, and it is the headline fact on a member card.

**Null is a real state and must survive.** Every account created before
2026-08-21 has none, and renders **no badge**. Never substitute a default:
guessing publishes a claim on a real person's public profile that they never
made. That is why `sanitizePrimaryService` returns null rather than falling back,
why `ProfileRepository.updateProfile` takes `Object? primaryService` against the
`unsetPrimaryService` sentinel — absent and null are different requests — and why
the picker shows nothing selected rather than preselecting an option.

### Every service has a feature list now

Until 2026-08-22 only Hookup had one. A profile saying "Relationship" told a
visitor nothing beyond the word while a Hookup profile carried thirty specifics,
which made the explicit list look like the point of the platform rather than one
option on it. `lib/core/constants/service_features.dart` mirrors all six.

The column was renamed `hookupServices` → **`serviceFeatures`** in the same
release. The app went on sending the old key, which zod strips silently, so a
member ticked a list, saved, and watched it vanish behind a 200.

**Ids are prefixed per catalogue** (`rel_`, `din_`, `fwb_`, `chat_`, `open_`),
so no id can be valid under two services. Without that, "travel" would be
legitimate under three of them and a member switching service would keep a
selection that only collided by accident.
`test/unit/service_features_test.dart` fails if any id ever belongs to two.

**Switching primary service clears the column** — in the picker and again
server-side. The ids belong to the old catalogue and mean nothing under the new
one, so keeping them would leave a Relationship profile holding Hookup ids that
any read path forgetting to check would publish. That is the lesson from August,
when the website's screens stopped showing the explicit list and four public
endpoints carried on publishing it as JSON. **Removing a catalogue from the
screen is not removing it.**

The heading differs per service on purpose (`featuresHeading`): what someone
*offers* under Hookup, what they *want* under Relationship. One generic word over
both makes the Relationship list read as a menu.

Booking rates stay **Hookup-only**. The other five do not describe a meeting that
is charged for.

## A chat costs credits, and both sides pay

Until 2026-08-23 contact was a **consent** flow: ask, wait, the member accepts.
The website deleted those routes and replaced them with a price, so
`/api/contact-requests` and `/api/profile/[u]/contact-request` are 404s. Every
screen the app had built on them was showing a queue that could never fill.

Opening a chat costs the sender **100 credits and the member being contacted
100**, in one transaction: if either wallet is short, neither is charged. Two
consequences follow that a member cannot work out from anywhere else, so the app
states both — on the profile, and beside the balance on the credits screen:

- a balance below the price makes a member **unreachable**, and
- credits leave a wallet **passively**, by being contacted.

**The two refusals are not the same thing**, and `ContactAccessFailure` keeps
them apart:

- **402 `INSUFFICIENT_CREDITS`** — the viewer is short. Names the price and their
  own balance, and offers a top-up, because that is something they can act on.
- **409 `TARGET_CANNOT_RECEIVE`** — the other side cannot cover their half.
  Carries **no balance and no blame**: the viewer did nothing wrong and has no
  business learning what is in somebody else's wallet. Pass the server's wording
  through; never rewrite it into "they have no credits".

`test/unit/contact_access_test.dart` fails if a shortfall ever becomes derivable
from the 409.

## Credits are not money, and they never share a column

`lib/core/constants/live_sessions.dart` holds the four live-session options —
custom video, custom audio, erotic video, sex chat — priced **per minute in whole
credits**. `lib/data/models/rates.dart` holds booking rates, in **integer minor
units of a real currency**.

They are one careless import apart, and the failure is silent both ways:
`formatMoney` on a credit column renders 50 credits as `₦0.50`, and
`parseRateInput` on the way in would store 50 credits as 5000. The website keeps
separate columns, a separate parser and a separate payload key (`liveRates`, not
`rates`) precisely so nothing can mix them, and
`test/unit/live_sessions_test.dart` holds the app to the same separation —
including that no live-session column name collides with a rate column name.

**Nothing delivers a live session.** There is no session backend, no call path
and no per-minute billing, here or on the website. A member may publish prices
and a viewer may read them; the website sends every one of those options to
`/app`, which says so plainly, and `features/app_info/get_the_app_screen.dart` is
this app's copy of that answer. **Do not wire a "start session" button to these
prices** — there is nowhere for it to go, and a control that silently fails is
worse than no control.

## Presence: the heartbeat, and the switch

`lastSeenAt` is written inside the backend's `requireAuth()`, and almost nothing
a member does hits an authenticated endpoint — browsing, discovery and every
public profile are unauthenticated reads in both clients. So a signed-in member
could use the app for an hour and never once report as online, and **the bug is
invisible**: presence never lies, it under-reports, and an empty "who is online"
reads as a quiet night rather than a defect.

`PresenceHeartbeat` wraps the whole app in `lib/app.dart` and beats
`POST /api/presence` every two minutes — `kPresenceInterval`, matching the
server's own `PRESENCE_WRITE_INTERVAL_MS` throttle. **Foreground only**: a phone
in a pocket must not report its owner as available. No body and no timestamp are
sent, because a client-settable "I am online" field is a field people set to lie,
and here the lie has a paying victim.

`showOnline` is the member's own switch, and `Presence?` is nullable everywhere
because of it. **Null is not `AWAY`.** `AWAY` is a claim about her ("not here in
a week"); null is the absence of a claim, which is what she asked for. Both
render nothing, but only one of them is ours to say — so never collapse them.

## Nothing is drawn over a member's face

`lib/shared/widgets/profile_card.dart` renders nothing above the bottom strip,
and `test/widget/profile_card_test.dart` fails if anything appears in the top
half of the card. Four badges used to sit there; on a 3:4 portrait they landed
across the member's face, which is the one thing a member card exists to show.

Presence became an 8px dot beside her name. "Available today" moved into the meta
line. The boost and new-profile badges are **gone rather than moved** — a boost
buys placement in the discovery order, which the member still gets, and neither
badge told a visitor anything they could act on. The verified tick stayed,
because unlike the website's old "Verified Woman" pill it is conditional on
`verificationStatus` and therefore true.

The WhatsApp glyph on the card opens the member's profile, where the consent gate
is. **It must never open `wa.me`.** Her number is not in the card payload and
must never be: a direct link there would publish every member's WhatsApp number
to anonymous visitors and let a whole grid be harvested in one pass.

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
| 18+ is an assertion **plus a year** | `/api/member/join` requires `isAdult === true` **and** a `birthYear` that makes the member 18. `birthDate` stays null and must never be synthesised from the year. Still a declaration, never verification |
| Registration accepts women **and men** | `/api/member/join` requires `gender`, mapped through a closed server-side table since 2026-08-21. It used to force `WOMAN` |
| One primary service, required, from a fixed list | `sanitizePrimaryService`. Null is a real state for older accounts and renders no badge |
| Feature ids are validated against **the chosen service's** catalogue | `sanitizeServiceFeatures`. Ids are prefixed per catalogue, and switching service clears the column |
| Booking rates still need `primaryService: 'hookup'` | The other five services do not describe a meeting that is charged for |
| The country comes from the phone number | `countryFromPhone`. A number that does not resolve leaves `countryCode` null — and discovery scopes on it, so the member is listed nowhere |
| Login accepts a username, an email **or a WhatsApp number** | `authorize()` splits on an `@`, then on `phoneMatchSuffix()`. Every written form of a number works, because the server matches significant digits from the **end** rather than rebuilding E.164 |
| An ambiguous number is **refused**, never resolved | `users.phone` is not unique, so the lookup caps at two and anything but exactly one match returns null. Signing someone into whichever account came back first would be account takeover |
| Anonymous callers only ever see women | `resolveVisibleGenders()` — hard-limited, ignores client input. Signed-in members see whatever their stored `interestedIn` allows, which is how men became visible at all |
| Only lady accounts may upload media | `/api/upload/presigned-url` returns 403 otherwise — **still true after men could register**, so a man who joins has no way to add a photo |
| Discovery never crosses borders | `resolveViewerCountry` pins a signed-in member |
| **Media publishes on upload** | `isApproved: true` on insert since 2026-08-14. Moderation is reactive: rejecting deletes the object from the bucket |
| Media needs `isApproved` **and** `isPublic` | The first is the moderator's decision, the second the owner's. Both must hold |
| Services are ids from a fixed catalogue | `sanitizeServiceIds` drops anything else. Never free text |
| Rates are integers in minor units | And minor units are not always hundredths — see `lib/core/utils/money.dart` |
| Last-active is a coarse bucket, never a timestamp | `src/lib/presence.ts`. A precise time is a movement log |
| A member may withhold presence without hiding | `showOnline`. `publicPresence()` then returns **null**, which is not `AWAY` |
| Live-session prices are whole credits, not money | `parseLiveSessionInput`, separate columns, separate payload key |
| Referrals report a count and a total, never who | `/api/referrals`. A referral list is a record of who knows whom |
| Favourites are private and one-directional | `/api/favorites`. The saved member is never told, and no endpoint would tell them |
| Phone numbers never published; a WhatsApp chat is **bought** | `/api/profile/[u]/whatsapp` charges both sides 100 credits in one transaction. The consent flow was deleted on 2026-08-23 |
| Only members with an approved profile photo are listed | `HAS_PROFILE_PHOTO`, applied to all twelve public reads. A member without one is absent everywhere and their public profile 404s — the owner and staff still see it |
| A forgotten password **is** recoverable | `/api/auth/whatsapp/*`, since 2026-08-22. The app said otherwise for eleven days |
| An admin can reset a password without learning it | `mustChangePassword` then refuses every other authenticated call until it is changed |
| Deleting an account erases bucket objects **before** rows | `/api/account`. The other order strands every photo |
| Credits sold over WhatsApp; card payment off (`503`) | `PAYSTACK_ENABLED=false`. A top-up is **recorded first** (`/api/credits/purchase`) so the reference in the member's message matches the admin queue |

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

**Gone rather than absent: the contact-request inbox.** The screen, its route,
its account-menu entry and its providers were deleted on 2026-08-25 with the
endpoints behind them. Nobody asks to reach anybody now — a chat is opened by
paying for it — so there is no queue to review and nothing to accept or decline.
Old notifications that carry a `contactRequestId` fall through to the member's
profile, which is where a chat is opened.

**Also deliberately absent: a media visibility toggle.** `media.isPublic` is a
real column and the owner is meant to control it, but no client endpoint sets
it — only admin paths do. The app reads it and does not offer a switch, because
a control that silently fails is worse than no control. If the website adds
`PATCH /api/media/[id]`, this becomes a ten-line change.

**And no `relationshipIntent` editor.** The website removed its four-option
dropdown on 2026-08-25 and dropped the key from `profileUpdateSchema`. Nothing
rendered the column anywhere — not the card, not the profile, not discovery — so
it was a question that wasted a member's time and produced a value nothing could
show them. `primaryService` asks the same thing with answers that are visible.
The column is kept, exactly as `dateTypes` is, because it holds real answers real
members gave.

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
flutter test        # expect: 396 passing
flutter build apk --debug
```

`analysis_options.yaml` is tightened past `flutter_lints`: `avoid_print`,
`use_build_context_synchronously` and `unawaited_futures` are **errors**. That
last one has already caught a real bug (an unawaited `context.push` swallowing a
navigation failure). `avoid_redundant_argument_values` is deliberately off.

Tests found three genuine defects so far: two RenderFlex overflows (brand mark,
sign-in footer) and the unawaited push. Keep the overflow assertions — they are
cheap and they work.

**Seven tests read the website's own source**, and they are the only defence
against the failure mode that has now broken this app three times:

| Test | Reads | Fails when |
| --- | --- | --- |
| `join_contract_test.dart` | `api/member/join/route.ts` | the route can reject a field this app does not send |
| `navigation_test.dart` | `lib/navigation.ts` | the menu gains an entry |
| `deep_links_test.dart` | `src/app/` | a section resolves to a profile lookup for its own slug |
| `services_catalogue_test.dart`, `primary_services_test.dart`, `hookup_services_test.dart`, `live_sessions_test.dart`, `service_features_test.dart` | the matching `src/lib/*.ts` | any catalogue drifts, or an id becomes valid under two services |
| `credits_test.dart` | `credits.ts`, `credit-purchase.ts` | a price the app quotes stops matching the one the server charges |

They **skip** when the sibling website checkout is absent, so the app stays
buildable alone. That is a deliberate hole: CI running only this repository
proves nothing here. They earn their place on a developer machine, which is where
the edit that causes drift is actually made.

The integration test drives the real app widget against a **scripted** backend.
It deliberately does not hit production: a suite that created real accounts and
reports on a live platform with real members would be worse than none.

---

## Verification status — be honest about this

| Area | Status |
| --- | --- |
| `flutter analyze` | Clean |
| `flutter test` | 396 passing |
| Debug APK | Builds (122 MB, arm64) |
| Release `.aab` | **Not run** — needs the owner's `android/key.properties` |
| iOS build | **Blocked** — needs macOS + Xcode |
| On device — install | **Confirmed.** The APK installs on the owner's phone |
| On device — launch | **One crash found and fixed** (wrong `MainActivity` package). The corrected build has **not yet been confirmed to launch** |
| Emulator | **Unavailable.** The machine's only AVD cannot start: `x86_64 emulation currently requires hardware acceleration` — the hypervisor driver is not installed |
| Signed-in API flows | **Not verified against a live account.** Written against contracts read from the website source |
| Registration (gender, primary service, birth year) | **Fixed 2026-08-25, not run.** The payload is pinned by `join_contract_test.dart` against the real route, which is the strongest evidence available without an account |
| Paid contact (402/409) | **Verified by test** against fabricated responses. No real credit has ever been spent from this app |
| WhatsApp password reset | **Not run.** No code has been received on a device; the three-step shape is read from the routes |
| Forced password change | **Not run.** Needs an admin to reset a real account |
| Sign-in field name | **Fixed 2026-08-14, still not verified** against a live account |
| The hookup gate | **Verified by test** on the client side only. The server's own four gates were verified by the website's session, not by this one |
| Presence heartbeat | **Verified by test** (interval, foreground-only, signed-out silence). The 204 has never been received from production |
| Catalogue parity — services, primary services, hookup, live sessions | **Verified by test**, against the local website checkout |
| Menu and deep-link parity | **Verified by test**, same |
| Minor-unit money maths | **Verified by test**, including the zero-decimal currencies |

Untested as a result: camera capture, a real upload over mobile data, video
playback, the WhatsApp handoff, deep-link intent resolution, notification
permission prompts. Named in `docs/STORE_READINESS.md`.

**Do not claim any of these work.** The public endpoints *were* exercised
against production; the 401-on-bad-credential shape was confirmed there.

A specific caution about every contract fix in this file. They were derived by
reading the website's source, which is the best available evidence and is *not*
the same as a successful round trip. The previous versions were also derived that
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
   | 7 | **Register an account, end to end** | The one thing that turns the 2026-08-21 contract fix from "should work" into "works". It has now been derived from source twice and run zero times |
   | 8 | Sign in, then leave the app open for five minutes and check "Online Now" from a browser | The heartbeat is the only surface where the app writes something another client reads |

   Expect **discovery to be empty** — production has no approved member media,
   and a browser gets the same empty list. That is the platform's state, not a
   defect.

2. **Create the upload keystore** and produce a signed `.aab`. Nothing exists
   for this yet, deliberately: generating it means choosing passwords, and
   those belong to the owner. `android/key.properties` is absent, so a release
   build silently falls back to debug signing and Play will reject it — the
   intended failure mode.
3. **Close the App Store 1.2 gap** — see `docs/STORE_READINESS.md`. Media
   publishes before any human sees it, so the guideline's "filter objectionable
   material *from being posted*" is not satisfied. This is **backend work** and
   it is the likeliest cause of a store rejection, ahead of anything in the app.
   Two workable shapes: hold first-time uploaders only, or put a classifier in
   front of `/api/upload/confirm`.
4. Owner: approve some real member media so discovery is not empty, and set the
   SMS provider key so phone verification can complete.
5. **Watch the website, every session.** It has changed contracts under this app
   four times in eleven days, and shipped twenty commits in the three days
   before 2026-08-25 alone. The check costs a minute:

   ```
   git -C ../pinorpinor log --oneline -15
   flutter test
   ```

   That is what caught `birthYear`, and the failure named the field.

   Two things the website is carrying that the app cannot fix:
   **referral farming** (signup collects no email, the phone is not verified
   unless `WHATSAPP_OTP_ENABLED` is on, and `users.phone` is not unique, so a
   fake referral costs one invented username) and **men who cannot upload a
   photo**, because `/api/upload/presigned-url` is still `WOMAN`-only — which
   now also means a man can never be listed, since every listing filters on an
   approved profile photo. Both are the owner's calls.

6. **Two flows are written and completely unexercised**: the WhatsApp password
   reset and the forced password change. Both are reachable, both are pinned to
   the routes by reading them, and neither has ever received a code or a 403 from
   production. They are the first things to try on a real device after
   registration.

*(Active-filter chips on Discover — the second aura pattern — are **done**;
`_ActiveFilterChips` in `discover_screen.dart`, one chip per filter with its own
clear, including one per selected service.)*
