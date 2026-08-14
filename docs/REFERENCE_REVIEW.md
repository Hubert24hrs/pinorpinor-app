# Reference Review — `ibhanu/aura`

Evaluated **2026-08-14** as an architectural reference for the Pinorpinor mobile
app, at the request of the project owner.

**Verdict: adopt two UI patterns, reject the data architecture.** Reasoning
below, so the decision can be re-argued rather than re-guessed.

---

## What aura actually is

A polished dating-app **UI prototype**. The visual design is genuinely good —
the swipe deck, the filter chips and the profile detail layout are all worth
looking at. What it is not is a working backend integration.

Measured across its `lib/` (31 Dart files):

| Signal | Count | What it means |
| --- | --- | --- |
| `fromJson` | **0** | Nothing is deserialised from any backend. The models are constructor-only |
| `validator` | **0** | No form validation anywhere |
| `try` / `catch` | **4** | Almost no error handling |
| `unsplash` | **41** | Mock profiles built from stock photographs of real people |
| Tests | **1** | The unmodified Flutter counter template — it asserts `find.text('0')` against an app with no counter, so it fails |

`main.dart` initialises Supabase with the literal strings `'YOUR_SUPABASE_URL'`
and `'YOUR_SUPABASE_ANON_KEY'`.

`AuthServiceImpl` is stubbed:

```dart
Future<void> signInWithPhone(String phoneNumber) async {
  // Simulate API call
  await Future.delayed(const Duration(seconds: 1));
}

Future<User?> verifyOTP(String phoneNumber, String otp) async {
  await Future.delayed(const Duration(seconds: 1));
  return null; // Mocking success but returning null for now as it's a dummy
}
```

Only `signOut()` and `currentUser` touch Supabase at all.

`HomeController` holds six hardcoded profiles and filters them in memory. There
is no repository layer, no pagination, and no loading/empty/error states driven
by real data.

None of this is a criticism of the project — it is doing what a design
prototype should. It is a reason not to take its data architecture.

---

## Side-by-side

| Concern | aura | Pinorpinor mobile | Decision |
| --- | --- | --- | --- |
| Flutter / Dart | 3.5.3 | 3.43 beta / 3.12 | **Keep ours** — we use null-aware collection elements and `RadioGroup` |
| State management | GetX (`GetxController`, `update()`) | Riverpod | **Keep ours** |
| DI | `get_it` + GetX | Riverpod providers | **Keep ours** — `get_it` would be a second, redundant container |
| Routing | `GetMaterialApp` + `getPages` | `go_router` + `StatefulShellRoute` | **Keep ours** |
| Auth | Stubbed; returns null | Real NextAuth cookie flow, verified against production | **Keep ours** |
| Backend | `supabase_flutter`, anon key in client | Next.js REST, **zero keys** | **Keep ours** — see below |
| Models | Constructors only, no parsing | Hand-written `fromJson`, defensive readers, 40+ parsing tests | **Keep ours** |
| Data source | 6 hardcoded profiles + Unsplash | Live API with pagination | **Keep ours** |
| Error handling | 4 try/catch | `ApiException` with 12 typed kinds, per-kind copy and retry policy | **Keep ours** |
| Form validation | None | `Validators` mirroring the backend, 30 unit tests | **Keep ours** |
| Testing | 1 broken template test | 127 passing | **Keep ours** |
| Theme | Dark, `google_fonts` at runtime | Light brand identity, bundled variable fonts | **Keep ours** |
| **Swipe deck UI** | Good gesture handling | **Missing** | **Adopt the pattern** |
| **Filter chips** | Active-filter chips with per-chip clear | Filter sheet only | **Adopt the pattern** |
| Profile detail layout | Rich stats grid | Simpler list | Partially adopt |

---

## Why the Supabase direction is rejected

The owner's brief said "my backend is Supabase, so adapt any backend-specific
implementation to Supabase." For the **website** that is true. For the **mobile
app** it is not, and following it would cause two problems.

**It would not work.** Website migration `20260812030000_lock_down_postgrest`
revokes all privileges on schema `public` from `anon` and `authenticated`,
changes default privileges so future tables are not granted either, and enables
RLS on every table — with **no policies**. It is deny-all by construction. A
`supabase_flutter` client holding the anon key receives `401 permission denied`
on every query. This was verified on the live project: the anon key returns 401
rather than an empty result set.

**It would be a security regression.** Shipping the anon key in a mobile binary
means that the day somebody restores those grants by accident — which is exactly
what that migration exists to prevent, because Prisma does not enable RLS on
tables it creates — the key in every installed copy of the app reads `users`,
including phone numbers and bcrypt hashes. The current app holds **no key at
all**, so there is nothing to leak.

The media bucket is private for the same class of reason: a public bucket serves
deleted photos from CDN cache for up to an hour, which is unacceptable on a
platform where members post personal images. Reads go through short-lived signed
URLs the server issues.

Adopting aura's schema would also be wrong on its own terms: it defines four
tables (`profiles`, `swipes`, `matches`, `messages`) against Pinorpinor's 27
Prisma models, with different column names, no credits/boosts, no contact-request
consent gate and no moderation flags.

---

## What is being adopted

### 1. The swipe deck — the real win

Pinorpinor's `DiscoveryRepository` already implements `deck()` (`/api/discover`)
and `swipe()` (`/api/swipe`, including the match-created response), with block
filtering, country scoping and already-swiped exclusion all handled server-side.
**Nothing calls them.** The backend feature is complete and has no UI.

Aura's `HomeController` shows the gesture model worth copying:

```dart
void onHorizontalDragUpdate(DragUpdateDetails details) {
  cardX += details.delta.dx;
  cardAngle = cardX / 500;   // rotation proportional to displacement
  update();
}

void onHorizontalDragEnd(DragEndDetails details) {
  if (cardX.abs() > 150) { cardX > 0 ? swipeRight() : swipeLeft(); }
  resetCard();
}
```

Simple and effective: translate with the finger, rotate proportionally, commit
past a threshold, spring back otherwise.

What we change when adopting it:
- **Riverpod, not GetX** — no `update()` calls.
- **Real profiles from `/api/discover`**, paged, with loading/empty/error states.
- **Optimistic advance with rollback** — aura's `swipeLeft()` just increments an
  index and never talks to a server. Ours posts and restores the card on failure.
- **Match celebration** on a mutual like, since `/api/swipe` returns
  `{ matched, matchId, conversationId }` and the website has no surface for it.
- **Accessible fallback buttons.** A drag-only interface is unusable with a
  screen reader or a motor impairment; aura has buttons and we keep them, wired
  to the same actions with semantic labels.
- **Reduced-motion respect**, consistent with the rest of the app.

### 2. Active-filter chips

Aura surfaces each active filter as a chip with its own clear affordance, plus
`hasActiveFilters` and per-filter display text. Our discover screen has a filter
sheet and a count badge, but no way to see or drop one filter without reopening
the sheet. Worth taking.

### Not adopted, and why

- **GetX / get_it** — swapping state management would rewrite 69 files for zero
  functional gain and would lose the router's auth redirect, deep-link
  integration and per-tab history.
- **`google_fonts`** — fetches at runtime; we bundle, which works offline.
- **Dark theme** — off-brand.
- **Mock profiles** — the platform's own rule is no fabricated members, and the
  equivalent fixtures were removed from the website for exactly that reason.
- **`glassmorphism_ui`, `lottie`** — dependencies for effects the brand does not
  use.
