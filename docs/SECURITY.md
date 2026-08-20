# Security

How the Pinorpinor mobile app protects members, what it deliberately does not
try to do, and what remains open.

The single most important sentence in this document: **the app enforces
nothing.** Every access decision is the backend's. What follows describes how
the client avoids weakening those decisions, and how it avoids becoming a new
place for something to leak.

---

## Contents

1. [Trust boundaries](#1-trust-boundaries)
2. [Secrets](#2-secrets)
3. [Authentication and sessions](#3-authentication-and-sessions)
4. [Authorisation](#4-authorisation)
5. [Transport](#5-transport)
6. [Local storage](#6-local-storage)
7. [Media and uploads](#7-media-and-uploads)
8. [Privacy of member contact details](#8-privacy-of-member-contact-details)
9. [Deep links](#9-deep-links)
10. [Input validation](#10-input-validation)
11. [Abuse, spam and enumeration](#11-abuse-spam-and-enumeration)
12. [Logging](#12-logging)
13. [Safety controls](#13-safety-controls)
14. [Account deletion](#14-account-deletion)
15. [Threat model](#15-threat-model)
16. [Known risks](#16-known-risks)
17. [Recommendations](#17-recommendations)

---

## 1. Trust boundaries

```
┌─────────────────────────────────────────────────────────────┐
│ UNTRUSTED — the device                                       │
│                                                              │
│  Flutter app          holds: one session cookie              │
│                       holds: nothing else of value           │
│                                                              │
│  A rooted or jailbroken device can read anything the app     │
│  can. Nothing here assumes otherwise.                        │
└──────────────────────────┬───────────────────────────────────┘
                           │  HTTPS only
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ TRUSTED — pinorpinor.com (Next.js on Vercel)                 │
│                                                              │
│  requireAuth()   re-reads the account on EVERY call          │
│  Prisma          connects as `postgres`, owns the schema     │
│  Service-role    server-side only, never leaves this box     │
└──────────────────────────┬───────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Supabase Postgres — data API closed to anon/authenticated   │
│  Supabase Storage — private bucket, signed URLs only         │
└─────────────────────────────────────────────────────────────┘
```

The app never speaks to Postgres or to Supabase's data API. The only direct
contact with Supabase is a `PUT` to a signed upload URL the backend generated,
which expires and grants nothing else.

---

## 2. Secrets

**The app contains no secrets.** Not "no secrets in the repository" — none in
the compiled binary either.

| Secret | Where it lives | In the app? |
| --- | --- | --- |
| `SUPABASE_SERVICE_ROLE_KEY` | Website server env | No |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Website (browser) | **No** — see below |
| `NEXTAUTH_SECRET` | Website server env | No |
| `PAYSTACK_SECRET_KEY` | Website server env | No |
| `EMAIL_API_KEY`, `SMS_API_KEY` | Website server env | No |
| `CRON_SECRET` | Website server env + Vercel | No |
| Database credentials | Website server env | No |

The anon key deserves a note. The website ships it to browsers because
`NEXT_PUBLIC_` variables are inlined at build time — but the app does not need
it and does not carry it. The Pinorpinor backend revoked all `anon` and
`authenticated` grants on `public` (migration
`20260812030000_lock_down_postgrest`) and enabled RLS on every table, so the key
opens nothing; and every media read the app performs is a signed URL the server
issued. Shipping a key that does nothing would still be a liability the day
someone restored those grants by accident.

`android/key.properties`, `*.jks`, `*.p12`, `*.mobileprovision` and `.env` are
all gitignored. See [ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md).

---

## 3. Authentication and sessions

The backend has no bearer-token endpoint. It issues an `HttpOnly`, `Secure`
NextAuth JWT cookie, and `requireAuth()` reads exactly that on every call. The
app speaks the browser flow rather than forking the backend to add a second
credential path:

```
GET  /api/auth/csrf                  → csrfToken + csrf cookie
POST /api/auth/callback/credentials  → session cookie, or 401
GET  /api/auth/session               → claims, or {} when invalid
```

**Why not a custom mobile token endpoint.** A second auth scheme means a second
set of expiry, revocation and ban-checking rules to get right, on a live
platform. Reusing the browser flow inherits every protection the website already
has — in particular the account re-read inside `requireAuth()`, which is the only
reason a suspension bites before a 30-day JWT expires.

**Session lifecycle**

| Event | Behaviour |
| --- | --- |
| Launch | Cookie read from secure storage, validated against `/api/auth/session` |
| Empty `{}` response | Treated as signed out; cookie cleared |
| `401` on any call | Cookie cleared, `sessionInvalidatedProvider` fires, router redirects |
| `403 ACCOUNT_SUSPENDED` | Same, plus the reason is shown on the sign-in screen |
| Offline at launch | Stored cookie kept; the next successful call decides |
| Sign out | Server call, then local clear — the local clear runs even if the network fails |
| Account deletion | Local clear immediately, so the app is never left in a state where every call 403s |

Verified by `test/unit/api_client_test.dart`.

**Failed sign-in is not an expired session.** The 401 from a bad credential is
caught in `AuthRepository.signIn` before it can fire the session-invalidated
path, and is reported as one message — "Incorrect email or password" — for both
a wrong password and a suspended account, because distinguishing them would
confirm that an address exists.

---

## 4. Authorisation

**Backend only.** The router's `redirect` and the odd `if (signedIn)` in the UI
exist so a member sees a sign-in prompt instead of an empty screen. They are
convenience, and removing every one of them would not grant a single byte of
data, because:

- every protected endpoint calls `requireAuth()`, which re-reads `isActive` and
  `isBanned` from the database on each request;
- discovery resolves visible genders server-side from the stored preference,
  ignoring anything the client sends;
- country scoping is pinned server-side for signed-in members;
- `profileUpdateSchema` whitelists writable fields, so boost tier, credit
  balance and verification status cannot be self-assigned;
- conversation, contact-request and media ownership are all checked server-side.

**IDOR.** The app has no endpoint that takes an arbitrary id and returns
something the caller should not see. Conversation ids are checked against
`ConversationMember`; contact-request ids 404 for anyone but the owner (404, not
403, so ids cannot be probed); media deletion checks both the row owner and that
the storage key sits inside that owner's folder.

---

## 5. Transport

**Android** — `network_security_config.xml` sets
`cleartextTrafficPermitted="false"` and trusts only system CAs in release.
User-installed CAs are trusted in debug builds only, so a developer can proxy a
local backend without weakening shipped builds.

**iOS** — App Transport Security is left at its strict default. No exception is
declared, because none is needed: the API, the signed-upload endpoint and every
media URL are HTTPS.

**Certificate pinning is not implemented.** This is a considered decision, not an
omission. Pinning a certificate for a domain on Vercel means the app breaks
whenever the certificate rotates — which is automatic and frequent — unless the
pin set is maintained in lockstep with a release cycle the operator does not
control. The realistic failure mode is a bricked app in members' hands, which is
worse than the attack it prevents. If pinning is wanted later, pin the CA's
public key rather than the leaf, and ship a backup pin.

---

## 6. Local storage

| Data | Where | Why |
| --- | --- | --- |
| Session cookie | `flutter_secure_storage` — EncryptedSharedPreferences / Keychain | The only credential on the device |
| Cached images | `cached_network_image`'s managed cache | Public-ish profile photos; bounded lifetime |
| Nothing else | — | No draft messages, no cached profile bodies, no search history |

The Keychain entry uses `first_unlock_this_device`, so an iCloud backup restored
onto different hardware cannot carry the session with it.

**Cache keys deserve a note.** Media URLs are signed and expire in an hour, so
caching by full URL would store the same photo many times, and caching
indefinitely would keep a deleted photo alive. `ProfileImage.cacheKeyFor` strips
the signature and keys on host + path, so re-signing the same object reuses the
bytes while a different object never collides, and the cache manager's own TTL
bounds how long a removed photo can survive.

Screenshot protection (`FLAG_SECURE`) is **not** enabled. On a platform whose
whole point is that members show themselves to other members, blocking
screenshots would be theatre: anyone determined can photograph the screen. The
real control is that photos are moderated, contact is consensual, and blocking
and reporting are one tap away.

---

## 7. Media and uploads

The client never chooses a storage path and never holds a storage credential.

1. `POST /api/upload/presigned-url` — the server validates MIME type, size and
   the per-member cap, then **generates the key itself**
   (`users/<callerId>/<folder>/<timestamp>-<crypto-random>.<ext>`) and returns a
   short-lived signed URL.
2. `PUT` to that URL. A separate Dio instance is used so the session cookie is
   never sent to a third-party host.
3. `POST /api/upload/confirm` — the server re-checks the key belongs to the
   caller (`isOwnStorageKey`, which rejects `..`, absolute paths, backslashes
   and anything outside the allowed character set) and that an object exists
   there, then writes the row with `isApproved: true`.

**Client-side validation is advisory.** MIME allow-list, 15MB images, 50MB
videos, and per-type caps are all checked locally to fail fast with a clear
message, and all re-checked by the server, which is the one that decides. MIME
spoofing gains nothing: the server re-derives the extension from the type it
validated, and the bucket serves what it stored.

**Compression strips EXIF.** Images are re-encoded at quality 82 with a 1080px
floor, with `keepExif: false`. That is bandwidth work whose more important side
effect is removing GPS coordinates — shipping a member's home location inside a
JPEG would be a far worse leak than anything the API exposes.

**Moderation is reactive, and this is a real residual risk.**

Uploads used to be held until a moderator released them. That was reversed by
the owner on 2026-08-14 (migration `20260814000000_emailless_signup`, with the
matching change in `/api/upload/confirm`), and media now publishes the instant
the transfer finishes. The admin Media Queue still lists everything, and
rejecting an item deletes the object from the bucket rather than merely hiding
the row — but **an image reaches the public before any human has seen it.**

On a platform where members upload personal adult photographs, that means
illegal or non-consensual content is publicly visible for however long it takes
someone to notice and act. It is recorded here as an accepted risk rather than
a solved problem, because it is the owner's decision and the migration's own
comment says as much. It is listed again in § 16 Known risks.

Two consequences for the app, both implemented:

- **No screen may say "awaiting review".** Every such string is gone. Telling a
  member their photo is queued when it is already public is a materially false
  statement about who can see their body, and it is the kind of false statement
  that changes what someone chooses to upload.
- **`isApproved: false` now means *taken down*,** not *not yet released*. The
  badge on a member's own media reads "Removed", and the account screen says a
  moderator removed it.

**Two flags, two decision-makers.** A media object reaches another member only
when `isApproved` (the moderator's decision) **and** `isPublic` (the owner's)
are both true. Keeping them separate is what lets a member pull a photo back
without it losing its approval and having to queue again when they restore it.
The app reads both. It offers no visibility switch, because no client endpoint
sets `isPublic` — only admin paths do, and a control that silently fails is
worse than no control.

---

## 8. Privacy of member contact details

A member's phone number is the platform's most sensitive field, and it never
reaches any client.

- It is not selected into any profile response.
- The app's `Account` model carries only the **member's own** number.
- `/api/profile/<username>/whatsapp` looks the number up server-side and answers
  with a `307` to `wa.me`. The app reads the `Location` header and hands the URL
  to the system; it never parses a number out of a JSON body, because none is
  sent.

Three server-side gates stand in front of that redirect: sign-in required (an
open endpoint would let anyone enumerate usernames and harvest numbers from
`Location` headers), a not-suspended check, and an **ACCEPTED** `ContactRequest`
for that exact requester/owner pair.

The 404 for "unreachable" is deliberately shared between "no such profile",
"hidden", "opted out" and "no number on file", so probing cannot distinguish
them. The app does not attempt to interpret it further.

**One limitation, stated plainly.** Once the redirect lands, the number is
visible in the resulting `wa.me` URL — WhatsApp click-to-chat has no opaque
handle. What this design prevents is scraping and casual inspection, not a
member reading their own address bar after being granted access. Truly opaque
contact would require routing messages through a platform-owned number.

### Presence is a bucket, never a timestamp

`users.lastSeenAt` is written server-side by a throttled heartbeat inside
`requireAuth()` and **never leaves the server**. Clients receive one of four
coarse buckets — `ONLINE`, `TODAY`, `THIS_WEEK`, `AWAY` — and the app models it
as an enum (`lib/data/models/presence.dart`) with no way to express anything
finer.

The reason is a safety one rather than a compliance one. "Last seen 21:47",
published to strangers on a meetup platform and watched over a few days, is a
movement log: it shows when someone sleeps, when they work, and when they are
alone at home. The buckets are deliberately wide so that differencing two page
loads cannot recover the underlying time.

Three rules follow, and the app holds all three:

- Never render anything more precise than the bucket's own label.
- Never attempt to reconstruct a time from a bucket, or to cache buckets over
  time to narrow one.
- An unrecognised value parses to `AWAY`, the claim that asserts least. A
  parser that defaulted to `ONLINE` would advertise absent members as present.

The heartbeat is also written **after** the ban check, so a suspended account
cannot keep showing as online.

### Favourites are one-directional and silent

`/api/favorites` is readable and writable only by its owner. The saved member is
never notified, the count is never published on their profile, and **there is no
endpoint that reports who saved whom** — that absence is the control, not an
oversight.

Publishing it would turn a private shortlist into a surveillance signal on a
platform where women are browsed by strangers, and an unverifiable "saved 47
times" number invites gaming besides. The app must not reconstruct the
information client-side by diffing lists either; `FavoritesRepository` carries a
note saying so, at the place someone would add the call.

`savedAt` is kept in a map on `FavoritesPage` rather than on `ProfileSummary`,
because when *this viewer* saved someone is a fact about the viewer's shortlist,
not about the member. Keeping it off the shared model is what stops it leaking
onto a surface that renders a profile from somewhere else.

---

## 9. Deep links

Links arrive from outside the app, so `DeepLinks.resolve` is a trust boundary
with two properties, both tested (`test/unit/deep_links_test.dart`, 14 cases):

1. It maps only links the app claims — the `pinorpinor://` scheme and the
   `pinorpinor.com` / `www.pinorpinor.com` hosts over HTTPS.
2. It returns **null** for everything else, and null is ignored. It cannot
   produce an external URL, cannot carry a session, and cannot trigger an
   action — every destination is a screen that then does its own authenticated
   fetch.

Rejected: other origins, lookalike hosts (`pinorpinor.com.evil.example`),
`javascript:`, `file:`, plain `http:`, and path segments that could not be a
username. A traversal segment collapses to the app's own home.

A link to a protected screen still passes through the router's auth redirect.

**No WebViews anywhere.** Legal and safety pages open in the system browser.
A WebView inside a signed-in app is an easy way to leak a session into content
the app does not control, and the external browser also shows the member the
address bar.

---

## 10. Input validation

Client-side validation mirrors the backend's rules
(`lib/core/utils/validators.dart`, 30 unit tests) so a member gets an answer
without a round trip. It is never the authority.

| Field | Rule | Enforced by |
| --- | --- | --- |
| Email | Format, folded to lowercase | Both |
| Password | 8–100 characters | Both, at sign-up |
| Username | 3–20, `^[a-z0-9_]+$`, letter first, no trailing or doubled `_`, not reserved | Postgres CHECK + unique index, API, client |
| Date of birth | 18+ | **Server**, plus a bounded picker and a client check |
| Phone | E.164 | Both |
| Message | ≤1000 characters | Both |
| Country | Must be in the known list | Server |

**SQL injection** is not reachable: the app sends JSON to REST endpoints, and
the backend uses Prisma's parameterised queries throughout.

**XSS-style rendering** is not applicable: Flutter renders text into a canvas,
not a DOM. There is no `dangerouslySetInnerHTML` equivalent, and no HTML from
the server is ever interpreted.

---

## 11. Abuse, spam and enumeration

Rate limiting is the backend's, and the app is built not to trip it or to
subvert it:

| Endpoint | Server limit | Client behaviour |
| --- | --- | --- |
| `/api/username/available` | 40/min per IP | 450ms debounce; skips obviously invalid input |
| `/api/auth/verify/send` | 3/min per user | Visible 30-second cooldown |
| `/api/auth/verify/confirm` | 10/min per user | — |
| `/api/profile/…/whatsapp` | 30/hour per user+IP | One call per explicit tap |
| `/api/profile/…/contact-request` | 20/hour per user+IP | One call per explicit tap |
| `/api/credits/boost` | 10/min | Confirmation dialog in front |

A 429 is surfaced with the server's own message and the `Retry-After` value,
never retried automatically.

**Enumeration.** The app does not expose anything the API hides: password reset
always reports the same non-committal result; the username check returns a
boolean and nothing about who holds a taken name; the WhatsApp 404 is
undifferentiated.

**Scraping.** The app is not a meaningful scraping vector — the same public
endpoints are reachable from `curl` — but it does not add one either: no bulk
export, no "download all photos", no unpaginated fetch.

---

## 12. Logging

`AppLog` compiles `debug`, `info` and `warn` out of release builds. Only
`error` survives, and nothing that reaches it carries user content.

**Never logged, at any level:** passwords, OTP codes, session cookies, reset
tokens, private messages, phone numbers, request or response bodies. The API
client logs method, path and a mapped error kind — enough to diagnose, nothing
to leak.

R8 additionally strips `android.util.Log` verbose/debug/info calls from the
release binary, so a future mistake cannot leak through logcat either.

---

## 13. Safety controls

Both required controls are two taps from any profile or conversation, and both
are backend-enforced:

**Report** — seven structured reasons including "This person appears to be
under 18", plus optional free text. Written to the moderation queue where a
human sees it. The reported member is never told who reported them.

**Block** — hides both members from each other in discovery, swipes and contact
requests in **both** directions, and ends any existing match in the same
server-side transaction. The confirmation dialog says so before it happens.
Unblock lives in Settings.

Covered by `test/widget/report_block_test.dart` (8 cases), including that a
signed-out visitor is asked to sign in rather than being handed a control that
would fail.

---

## 14. Account deletion

The app offers **two different things**, kept deliberately apart because they
have different consequences and different confirmations.

### Deactivate — reversible

**Route:** Settings → Account → Deactivate my account.

Calls `DELETE /api/settings`, which sets `isActive: false`. From that moment
`requireAuth()` answers 403 on every call, the profile disappears from every
public surface (each read path filters on `isActive`), and the local session is
cleared. Nothing is destroyed; signing in again restores it.

### Delete permanently — irreversible, password-confirmed

**Route:** Settings → Account → Delete my account permanently, behind **two**
gates: typing the username, and entering the account password.

Calls `DELETE /api/account`, which:

1. removes every one of the member's objects from the storage bucket, **then**
2. deletes the `users` row, cascading away the dating profile, media rows,
   settings, wallet, ledger, favourites, blocks, contact requests, swipes,
   matches and sessions.

**That order is load-bearing and not interchangeable.** `storageKey` exists only
on the `media` rows, and deleting the user cascades those away — so doing it the
other way round would leave every photograph stranded in a private bucket with
nothing left pointing at it. "We deleted your account but kept your photos
forever, unreachable but present" is precisely the outcome a deletion request
exists to prevent, on a platform where members upload personal adult images.

**Why the password, when a valid session already proves identity.** Sessions are
30-day JWTs. Without a second factor, anyone who picked up an unlocked phone
could destroy the account and all its media in two taps, with no recovery path.
The server re-checks it with bcrypt and answers 403 on a mismatch; the app never
compares it locally.

A storage failure is logged and does **not** abort the deletion. That is a
deliberate trade made server-side: refusing to delete an account because one
object could not be removed would leave someone unable to leave the platform at
all, which is worse than a stranded file a sweep can collect later.

### What still survives, and why

`reports` filed **about** the member (safety records, retained for the
moderation window), `credit_ledger_entries` and `payments` (financial records),
and `audit_logs` (moderation accountability). Each is retained under legitimate
interest and stated in the privacy policy.

`audit_logs.actorUserId` is `SET NULL` on deletion rather than `Restrict`, with
the actor's username denormalised onto `actorLabel` at write time. Before
migration `20260815000000_auditlog_survives_actor` it was `Restrict`, which made
**any account that had ever performed an admin action permanently undeletable** —
the delete failed on the foreign key and surfaced as an opaque 500. An audit log
has to outlive the person who wrote it without blocking their right to leave.

---

## 15. Threat model

| Threat | Mitigation | Residual |
| --- | --- | --- |
| Stolen device, unlocked | Session cookie in Keystore/Keychain, `first_unlock_this_device` | An unlocked device has the session. Device lock is the control |
| Rooted / jailbroken device | None claimed | Full access to the app's own data. Accepted: the backend enforces authorisation regardless |
| Network attacker on public Wi-Fi | HTTPS enforced, cleartext refused, system CAs only in release | A device-level CA compromise; no pinning (§5) |
| Reverse engineering the APK | Nothing valuable inside; R8 obfuscation | The API surface becomes known — but it is a public website's API |
| Stolen session cookie | Server-side ban takes effect on the next call | Valid until expiry or ban. No per-device revocation exists |
| Credential stuffing | bcrypt cost 12; no client-side lockout | Server-side rate limiting is in-memory and per-instance (§16) |
| Malicious deep link | Resolver returns null for anything unclaimed (§9) | — |
| Malicious upload | Server-side type, size and ownership checks; moderation queue | No malware scanning of stored objects |
| Profile enumeration | Undifferentiated 404s; no bulk endpoints | Public profiles are public by design |
| Underage registration | Server-side DOB check, bounded picker, in-app reporting reason | A determined liar can enter a false date. Same limitation as the website |
| Screenshotting a profile | None | Accepted (§6) |

---

## 16. Known risks

Stated plainly, including the ones inherited from the backend.

**1. The verified badge does not prove age.** It proves control of an email
address and a phone number. The website's own notes say the same. The app's
verification screen says so to the member in as many words, rather than implying
an age check it does not perform.

**2. Backend rate limiting is in-memory and per-instance.** On a serverless
host, limits reset per cold start and are not shared between instances. This is
a website-side gap (`ioredis` is already a dependency and `REDIS_URL` is
reserved), and it means the client-side debounces and cooldowns are doing more
work than they should have to.

**3. No per-device session revocation.** A session cookie is valid until it
expires or the account is banned. There is no "sign out of all devices". Adding
one needs a server-side token version column.

**4. No certificate pinning.** Reasoned in §5.

**5. No push notification transport.** The app polls in the foreground. A
security-relevant consequence: a security alert cannot reach a member who does
not open the app.

**6. SMS delivery is unkeyed on the backend.** Phone verification codes do not
currently send from either client, because the provider key is not set. Women
therefore cannot complete phone verification today — a platform-level blocker,
not an app one.

**7. No malware scanning of uploads.** Files are type- and size-checked, but not
scanned. Media is served to app clients as images and video, never executed.

**8. The app trusts the origin it is compiled against.** A build produced with
`--dart-define=PINORPINOR_API_ORIGIN` pointing somewhere hostile would send
credentials there. That is a build-pipeline control, not a runtime one: only
release from a trusted machine, with the origin verified.

**9. Media publishes before any human review.** Reversed by the owner on
2026-08-14; reasoned in full in §7. On a platform carrying personal adult
imagery this is the most consequential risk on this list: illegal or
non-consensual content is publicly visible until somebody notices it. Reducing
it needs a backend change — a review queue with teeth, or automated scanning —
not a client one. The app's contribution is to stop claiming a review that does
not happen.

**10. Accounts created since 2026-08-14 have no password-reset path.**
Registration collects no email address, and `/api/forgot-password` looks members
up by address. A forgotten password is a lost account, permanently. The join
screen states this before the member commits, which is the only mitigation
available client-side. A real fix is either an optional recovery address or
WhatsApp OTP sign-in, both backend work.

**11. The app's contracts are read from source, not proven by round trip.** The
two breaks fixed on 2026-08-20 — the sign-in field name and the registration
payload — were both derived correctly from the website's source when originally
written, and both silently stopped matching when the website changed. Nothing in
the build catches this class of drift. `test/unit/services_catalogue_test.dart`
now closes it for the services catalogue by reading the real TypeScript, and
that pattern should be extended wherever a contract is checkable statically. The
general case still needs a signed-in session against a live origin.

---

## 17. Recommendations

For the operator, roughly in order of value:

1. **Set the SMS provider key** so women can complete phone verification. This
   is currently blocking the platform's own verification promise.
2. **Move backend rate limiting to Redis.** The dependency and the env var are
   already in place.
3. **Add a device-token table and a push send path** (see
   [DEPLOYMENT.md](DEPLOYMENT.md) § Push notifications) — this unblocks the one
   BLOCKED row in the parity matrix and lets security alerts reach members.
4. **Add a session-version column** so a member can sign out of all devices, and
   so a compromised cookie can be revoked without a ban.
5. **Publish `assetlinks.json` and `apple-app-site-association`** so shared
   `https://pinorpinor.com/<username>` links open the app rather than the
   browser.
6. **Rotate the GitHub PAT embedded in the website repository's git remote.**
   The website's own notes flag it; it is readable locally and was exposed in a
   session transcript.
7. **Consider a Content-Security-Policy on the website.** Not an app concern,
   but it is the largest remaining gap on the shared origin.

---

## Reporting a vulnerability

Email the address on <https://pinorpinor.com/contact>. Please do not open a
public GitHub issue for a security report.
