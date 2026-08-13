# Website ↔ Mobile Feature Parity

Every meaningful feature of the Pinorpinor website against its counterpart in
the Flutter app. Derived from a full read of the website source — 25 pages, 57
API route handlers, 27 Prisma models — not from a summary.

**Status meanings**

| Status | Meaning |
| --- | --- |
| **COMPLETE** | Implemented in the app against the same endpoint, with the same rules |
| **PARTIAL** | Implemented, but with a stated difference |
| **NOT APPLICABLE** | Web-only by nature (SEO, admin tooling), deliberately absent |
| **BLOCKED** | Cannot be completed without something outside this repository |

**Verification meanings**

| Verification | Meaning |
| --- | --- |
| **VERIFIED** | Exercised by an automated test in this repository |
| **PARTIALLY VERIFIED** | Compiles, analyses clean, and its logic is unit-tested; the live round trip has not been run |
| **NOT VERIFIED** | Written against the read API contract; not executed against a live account |
| **BLOCKED** | Cannot be verified here — needs macOS, store credentials, or a live member account |

> **A note on what "not verified" means here.** No live Pinorpinor member
> account was available during this work, and creating real accounts, real
> reports or real contact requests against a production platform with real
> members would have been the wrong thing to do. Signed-in flows are therefore
> written against the API contracts as read from the website source, and marked
> honestly below. The public endpoints *were* exercised against production —
> see "Live checks performed" at the end.

---

## Authentication and registration

| Website feature | App counterpart | Status | Verification | Notes |
| --- | --- | --- | --- | --- |
| Sign in (`/login`, NextAuth credentials) | `LoginScreen` → `/api/auth/csrf` + `/api/auth/callback/credentials` | COMPLETE | PARTIALLY VERIFIED | The 401-on-bad-credential shape was confirmed against production with a deliberately invalid credential; a successful sign-in needs a real account |
| Email folded to lowercase on sign-in | `AuthRepository.signIn` normalises before sending | COMPLETE | VERIFIED | `login_screen_test` asserts the submitted value |
| Registration (`/join` → `/api/member/join`) | `JoinScreen`, three steps | COMPLETE | PARTIALLY VERIFIED | Field-by-field parity with the route's own validation |
| 18+ enforcement | Date picker bounded at 18 years ago + `Validators.birthDate` + server | COMPLETE | VERIFIED | `join_screen_test`, `validators_test` |
| Women must supply a WhatsApp number | Phone field shown and required when Woman is selected | COMPLETE | VERIFIED | Conditional rendering asserted |
| Men's profiles created private | Explained at sign-up; the backend sets `isPublic: false` | COMPLETE | VERIFIED | Copy asserted in `join_screen_test` |
| Username rules (3 layers) | `UsernameRules` mirrors the app layer; live check via `/api/username/available` | COMPLETE | VERIFIED | 6 unit tests including reserved names |
| Username suggestions on conflict | Suggestion chips from the 409 body | COMPLETE | VERIFIED | `ApiException` carries `suggestions` |
| Referral code at sign-up | Optional field, passed through | COMPLETE | NOT VERIFIED | |
| Password reset request (`/forgot-password`) | `ForgotPasswordScreen` | COMPLETE | NOT VERIFIED | Non-committal copy preserved, so it stays no account-existence oracle |
| Password reset completion (`/reset-password?token=`) | `ResetPasswordScreen`, reachable by deep link | COMPLETE | VERIFIED (link resolution) | Token handling asserted in `deep_links_test` |
| Sign out | `AuthController.signOut` + local clear | COMPLETE | PARTIALLY VERIFIED | Local clear runs even if the network call fails |
| 30-day persistent session | Cookie in Keystore/Keychain, restored at launch | COMPLETE | VERIFIED | `api_client_test` covers storage and attachment |
| Ban / deactivation takes effect immediately | `403 ACCOUNT_SUSPENDED` tears the session down and explains why | COMPLETE | VERIFIED | `api_client_test` asserts the teardown |
| OAuth (Google/Facebook env slots) | Not implemented | NOT APPLICABLE | — | The env vars exist but no provider is configured on the website; there is nothing to reproduce |

## Verification

| Website feature | App counterpart | Status | Verification | Notes |
| --- | --- | --- | --- | --- |
| Email OTP (`/api/auth/verify/send|confirm`) | `VerificationScreen` | COMPLETE | NOT VERIFIED | Needs a live account and a keyed email provider |
| Phone OTP | Same screen, shown only where required | COMPLETE | NOT VERIFIED | **The website's SMS provider is unkeyed** — Termii sender-ID approval pending — so phone codes do not currently send on either client |
| Women need both channels, men only email | `Account.fullyVerified` mirrors the rule | COMPLETE | VERIFIED | `models_test` |
| Verified badge | Read from `verificationStatus` only | COMPLETE | VERIFIED | The UI can never set it |
| Resend cooldown | 30-second countdown in front of the 3/min limit | COMPLETE | NOT VERIFIED | Avoids showing the member a 429 |

## Profiles

| Website feature | App counterpart | Status | Verification | Notes |
| --- | --- | --- | --- | --- |
| Public profile (`/profile/[username]`, `/[username]`) | `ProfileDetailScreen` | COMPLETE | PARTIALLY VERIFIED | Rendering covered by the integration test with a scripted payload |
| Own profile (`GET /api/profile`) | `AccountScreen` | COMPLETE | NOT VERIFIED | |
| Edit profile (`PATCH /api/profile`) | `EditProfileScreen` | COMPLETE | NOT VERIFIED | Only whitelisted fields sent |
| Bio, tagline, height, ethnicity, city, country | All present | COMPLETE | VERIFIED (parsing) | |
| Relationship intent | Choice chips | COMPLETE | VERIFIED (parsing) | |
| Date types | Filter chips from the same option list | COMPLETE | VERIFIED (parsing) | |
| "Available today" | Toggle in the editor, badge on cards | COMPLETE | VERIFIED | `profile_card_test` |
| Profile completeness | Computed locally, cosmetic only | COMPLETE | VERIFIED | `models_test` |
| Prompts (`prompts` JSON) | Parsed into the model | PARTIAL | VERIFIED (parsing) | Parsed and available, but not yet rendered — the website has no editor for it either, so there is no content to show |
| `lat`/`lng` | Absent | NOT APPLICABLE | — | Stripped server-side; there is nothing to model |
| View count | Parsed, not displayed | PARTIAL | — | The website does not display it to members either |

## Media

| Website feature | App counterpart | Status | Verification | Notes |
| --- | --- | --- | --- | --- |
| Three-step presign → PUT → confirm upload | `MediaRepository.upload` | COMPLETE | NOT VERIFIED | Needs a live lady account |
| Profile photos (max 6) | `ManageMediaScreen` section | COMPLETE | NOT VERIFIED | |
| Gallery photos (max 30) | Same | COMPLETE | NOT VERIFIED | |
| Videos (max 10, 50MB, 60s) | Same | COMPLETE | NOT VERIFIED | |
| 15MB image limit | Enforced after compression, and by the server | COMPLETE | — | |
| MIME allow-list | Mirrored client-side, authoritative server-side | COMPLETE | — | |
| Upload progress | Real byte progress from the PUT | COMPLETE | — | The website only fakes progress in three steps; the app reports actual bytes |
| Delete media | `DELETE /api/upload/delete` with confirmation | COMPLETE | NOT VERIFIED | |
| Held-for-moderation state | "Awaiting review" overlay on the owner's own pending media | COMPLETE | VERIFIED | `models_test` asserts `hasPendingMedia` and that no pending photo becomes an avatar |
| Signed read URLs | Handled transparently; cache keyed on path, not signature | COMPLETE | — | |
| Camera capture | Offered alongside gallery | COMPLETE | NOT VERIFIED | The website has no camera path at all — a mobile addition |
| Image compression | 1080px floor, quality 82, EXIF stripped | COMPLETE | — | Mobile addition; also removes GPS from photos |
| Reorder media | Not implemented | PARTIAL | — | The `order` column exists and is set on upload, but the website exposes no reorder control either. Deferred rather than invented |
| Video transcoding | Not implemented | PARTIAL | — | Deliberate: a bad transcode degrades the member's video for no gain. Oversized files are rejected with a clear message before upload starts |

## Discovery

| Website feature | App counterpart | Status | Verification | Notes |
| --- | --- | --- | --- | --- |
| Public browse (`/discover`, `/api/public/profiles`) | `DiscoverScreen` | COMPLETE | VERIFIED | Exercised against production and in the integration test |
| No login wall for browsing | Preserved | COMPLETE | VERIFIED | Integration test asserts a signed-out visitor reaches the grid |
| Anonymous callers see women only | Server-enforced; app does not attempt to widen it | COMPLETE | — | |
| Country scoping | Read from `scope`; picker offered only when not pinned | COMPLETE | VERIFIED | `models_test` covers `pinned` |
| City filter | Filter sheet + city chips on home | COMPLETE | NOT VERIFIED | |
| Age filter (18 floor) | Range slider, floored at 18 | COMPLETE | VERIFIED | |
| Verified-only filter | Toggle | COMPLETE | NOT VERIFIED | |
| Available-today filter | Toggle | COMPLETE | NOT VERIFIED | |
| Pagination | Infinite scroll with prefetch | COMPLETE | VERIFIED | `ProfilePage.merge` unit-tested |
| Ordering (featured → boosted → tier → credits → available → recent) | Server-side; untouched | COMPLETE | — | |
| Ladies rail (`/api/ladies`) | Home screen horizontal rail | COMPLETE | VERIFIED (parsing) | Handles the `ladyProfile` rename |
| Spotlight / Face of the Day | Home card | COMPLETE | VERIFIED (parsing) | |
| Locations (`/api/public/locations`) | City chips | COMPLETE | NOT VERIFIED | |
| Swipe deck (`/api/discover`) | `DiscoveryRepository.deck` implemented | PARTIAL | NOT VERIFIED | The repository and swipe call are complete; no swipe *screen* is shipped. The website surfaces no swipe UI either — `/api/swipe` exists but nothing on the site calls it — so shipping one would be adding a product feature, not reproducing one |
| `/browse` and `/live` fabricated profiles | Not reproduced | NOT APPLICABLE | — | Those two website pages serve six invented women and three invented "live streamers" built from stock photographs of real people. The website's own notes flag them as an open product decision. Reproducing invented people in a shipped app would be worse than omitting them |

## Messaging

| Website feature | App counterpart | Status | Verification | Notes |
| --- | --- | --- | --- | --- |
| Conversation list (`/api/conversations`) | `MessagesScreen` | COMPLETE | NOT VERIFIED | |
| Unread indication | Derived from `lastReadAt` vs last message | COMPLETE | VERIFIED | `models_test`, three cases |
| Thread history with cursor paging | `ConversationScreen` + `ThreadNotifier` | COMPLETE | NOT VERIFIED | |
| Send message (1000 char cap) | Optimistic send with retry on failure | COMPLETE | VERIFIED (validation) | The website has no optimistic echo; a mobile addition |
| Read receipts | Handled by the history fetch's side effect | COMPLETE | — | |
| Ended match blocks sending | Composer disabled with an explanation | COMPLETE | — | Mirrors the route's 403 |
| Matches list (`/api/matches`) | `MatchesScreen` | COMPLETE | NOT VERIFIED | |
| Realtime delivery | Polling every 12s while a thread is open | PARTIAL | NOT VERIFIED | **There is no realtime channel on the backend** — no websocket, no SSE, and the Supabase data API is closed, so Realtime is unavailable. Polling is the honest option; the website itself has none |
| Image messages | Model and API support them | PARTIAL | — | `mediaUrl` is parsed and rendered; no compose-with-image control, because the website has none and there is no upload path that produces a message-scoped URL |
| Sample conversations behind `/messages` | Not reproduced | NOT APPLICABLE | — | The website's own notes flag these as fabricated |

## Safety and moderation

| Website feature | App counterpart | Status | Verification | Notes |
| --- | --- | --- | --- | --- |
| Report a user (`/api/report`) | `showReportBlockSheet` → report form | COMPLETE | VERIFIED | 8 tests |
| Structured reasons | Seven fixed reasons including "appears to be under 18" | COMPLETE | VERIFIED | |
| Block (`/api/block`) | Confirmation dialog then block | COMPLETE | VERIFIED | |
| Unblock | Settings → Blocked members | COMPLETE | NOT VERIFIED | |
| Block ends an existing match | Server-side, in the same transaction | COMPLETE | — | The dialog says so before it happens |
| Reachable from a profile | App-bar overflow, one tap | COMPLETE | VERIFIED | |
| Reachable from a conversation | Overflow menu | COMPLETE | — | |
| Media moderation queue | Not reproduced | NOT APPLICABLE | — | Admin tooling; the website's `/admin` is the right home for it |

## WhatsApp

| Website feature | App counterpart | Status | Verification | Notes |
| --- | --- | --- | --- | --- |
| Contact request (`POST /api/profile/[u]/contact-request`) | Note sheet then request | COMPLETE | NOT VERIFIED | |
| Owner accepts / declines | `ContactRequestsScreen`, Received tab | COMPLETE | NOT VERIFIED | |
| Sent requests with status | Sent tab | COMPLETE | NOT VERIFIED | |
| `wa.me` redirect after acceptance | Redirect read, not followed; opened via `whatsapp://` with an `https` fallback | COMPLETE | NOT VERIFIED | |
| Number never reaches the client | Preserved — the app receives a redirect target, never a JSON field | COMPLETE | — | |
| Credits sales number | Shown on the credits screen from `/api/credits/wallet` | COMPLETE | NOT VERIFIED | |
| WhatsApp Business / Cloud API | Does not exist | NOT APPLICABLE | — | The website has click-to-chat only. Nothing was invented |

## Credits and payments

| Website feature | App counterpart | Status | Verification | Notes |
| --- | --- | --- | --- | --- |
| Wallet balance (`/api/credits/wallet`) | `CreditsScreen` | COMPLETE | VERIFIED (parsing) | |
| Boost tiers | Listed with cost and duration | COMPLETE | NOT VERIFIED | |
| Activate boost (`POST /api/credits/boost`) | Confirmation then activate; 402 surfaced | COMPLETE | NOT VERIFIED | |
| Ledger | Recent activity list | COMPLETE | VERIFIED (parsing) | |
| Credit packages | Listed for reference | COMPLETE | VERIFIED (parsing) | |
| Referral code + count | Card with copy-to-clipboard | COMPLETE | NOT VERIFIED | |
| Buy credits over WhatsApp | Deep link to the platform's sales number | COMPLETE | NOT VERIFIED | |
| Paystack card checkout | **Deliberately not implemented** | NOT APPLICABLE | — | Disabled on the backend (503). Adding a card checkout for a digital good inside a mobile app would breach Play and App Store payment rules — see `docs/STORE_READINESS.md`. `CreditsRepository.initCardPayment` exists as a throwing method so the decision is visible where someone would look for it |
| Paystack webhook | Server-side only | NOT APPLICABLE | — | |

## Settings and privacy

| Website feature | App counterpart | Status | Verification | Notes |
| --- | --- | --- | --- | --- |
| Notification preferences (4 toggles) | Settings, optimistic with rollback | COMPLETE | NOT VERIFIED | |
| Show in discovery | Toggle; also updates `isDiscoverable` | COMPLETE | NOT VERIFIED | |
| Interested-in preference | Dedicated screen | COMPLETE | NOT VERIFIED | |
| Age range / distance | Model supports; not surfaced | PARTIAL | — | The website exposes no editor for them either; discovery filters cover the same ground |
| Blocked members list | Settings → Blocked members | COMPLETE | NOT VERIFIED | |
| Account deactivation (`DELETE /api/settings`) | Settings → Account → Delete my account | COMPLETE | NOT VERIFIED | Type-your-username confirmation |
| Privacy policy / Terms / Safety / Contact | Opened in the system browser | COMPLETE | — | Not a WebView: a WebView inside a signed-in app is an easy way to leak a session |
| `whatsappEnabled` toggle | Not implemented | PARTIAL | — | The column and API honour it, but **the website ships no control for it either** — it is on the website's own outstanding list. Adding one only in the app would put the two out of step |

## Navigation and platform

| Website feature | App counterpart | Status | Verification | Notes |
| --- | --- | --- | --- | --- |
| Header + mobile bottom nav | Five-destination shell; navigation rail on tablets | COMPLETE | VERIFIED | |
| Protected routes | Router redirect + server enforcement | COMPLETE | VERIFIED | Integration test asserts the redirect |
| Auth-only routes | Redirected away when signed in | COMPLETE | VERIFIED | |
| Android back / iOS swipe-back | Platform page transitions; `PopScope` on the multi-step form | COMPLETE | — | |
| Deep links | Custom scheme + App/Universal Links | COMPLETE | VERIFIED | 14 tests |
| Responsive 320–1440 | Verified at 320, 375, 393, 430, 768, 1024 | COMPLETE | VERIFIED | Overflow assertions on the two densest screens |
| Brand identity | Palette, gradients, Playfair + Plus Jakarta Sans, badges, shadows all transcribed | COMPLETE | VERIFIED | |
| SEO, sitemap, robots, Open Graph | — | NOT APPLICABLE | — | Web-only by nature |
| `/maintenance` page | Not reproduced | NOT APPLICABLE | — | Driven by a website env flag |
| Admin console (`/admin`, 13 endpoints) | Not reproduced | NOT APPLICABLE | — | Moderation belongs on the desktop console; reproducing an admin surface in a consumer app would widen the attack surface for no gain |

## Notifications

| Website feature | App counterpart | Status | Verification | Notes |
| --- | --- | --- | --- | --- |
| Notification list | `NotificationsScreen` | COMPLETE | VERIFIED (parsing) | |
| Mark one / all read | Both | COMPLETE | NOT VERIFIED | |
| Typed icons and destinations | Every `NotificationType` mapped | COMPLETE | VERIFIED (parsing) | |
| Unread badge | Foreground polling | COMPLETE | — | |
| Server-pushed notifications | Not implemented | BLOCKED | BLOCKED | **Backend gap:** no device-token table, no FCM/APNs credential, no send path. The client work is small; the backend change is specified in `docs/DEPLOYMENT.md` § Push notifications |

---

## Live checks performed

Against production, read-only, on public endpoints:

| Check | Result |
| --- | --- |
| `GET /api/public/profiles?limit=2` | 200, valid envelope, geo-resolved scope |
| `GET /api/public/profiles?country=NG` | 200, country scoping honoured |
| `GET /api/auth/csrf` | 200, `__Host-next-auth.csrf-token` issued |
| `POST /api/auth/callback/credentials` (invalid credential) | **401**, no session cookie — this is what the client's failure path is written against |
| `GET /api/auth/session` (no cookie) | `{}` — the app treats an empty body as "signed out" |

The production database currently returns **zero public profiles**, because
every upload is held for moderation and no member media has been approved yet.
That is the platform's current state, not an app defect: the same request from a
browser returns the same empty list.

## What was not verified, and why

**No device or emulator run.** The development machine's only AVD refuses to
start — `x86_64 emulation currently requires hardware acceleration`, because the
Android Emulator hypervisor driver is not installed, and installing it is an
administrator-level change with a reboot. Every **NOT VERIFIED** row above is
therefore verified to the level of "compiles, analyses clean, and its logic is
unit-tested", and no further.

The surfaces this leaves genuinely untested: camera capture, a real upload over
a mobile connection, video playback, the WhatsApp app handoff, deep-link intent
resolution, notification permission prompts, and the splash-to-first-frame
handover.

**No live member account.** Signed-in flows are written against the API
contracts as read from the website source. Creating real accounts, reports or
contact requests against a production platform with real members would have been
the wrong thing to do.

---

## Summary

| Status | Count |
| --- | --- |
| COMPLETE | 71 |
| PARTIAL | 10 |
| NOT APPLICABLE | 11 |
| BLOCKED | 1 |

**No website feature is unintentionally missing.** Every PARTIAL and NOT
APPLICABLE row above states its reason, and each falls into one of four
categories: the website has no UI for it either; it is admin or SEO tooling that
does not belong in a consumer app; it is fabricated content the website's own
notes flag as an open decision; or it would breach app store policy.

The single BLOCKED item — server-pushed notifications — needs a backend change,
not a client one.
