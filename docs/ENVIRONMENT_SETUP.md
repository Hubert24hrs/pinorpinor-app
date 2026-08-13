# Environment Setup

What each environment needs, and where each credential lives.

**No real secret appears in this file, or anywhere else in this repository.**
Names and locations only.

---

## The short version

The Flutter app needs **no credentials at all** to build and run. There is no
`.env` file to create, no key to paste, no service account to download.

```bash
flutter pub get
flutter run
```

That is the whole setup. If you have configured a Flutter app before, this will
feel wrong — so it is worth saying why.

---

## Why the app holds nothing

Every privileged operation runs behind the Next.js API on `pinorpinor.com`. The
app is a client of a public website's API, and it authenticates the way a
browser does: with a session cookie it obtains by signing in.

The two credentials a mobile app in this shape would normally carry, and why
this one does not:

**A Supabase anon key.** The Pinorpinor backend revoked every `anon` and
`authenticated` grant on the `public` schema (migration
`20260812030000_lock_down_postgrest`) and enabled RLS on all tables. The key
opens nothing. Media reads are short-lived signed URLs the server issues, and
uploads use a signed URL the server generates per file. Shipping a key that does
nothing would still be a liability the day somebody restored those grants by
accident.

**A payment provider public key.** The app contains no purchase flow — see
`STORE_READINESS.md` § Payments.

---

## Build-time configuration

One knob, in `lib/core/config/app_config.dart`:

| Name | Default | Purpose |
| --- | --- | --- |
| `PINORPINOR_API_ORIGIN` | `https://pinorpinor.com` | The origin the app talks to |

```bash
# Against a staging deployment
flutter run --dart-define=PINORPINOR_API_ORIGIN=https://staging.pinorpinor.com

# Against a local website (Android emulator reaches the host at 10.0.2.2)
flutter run --dart-define=PINORPINOR_API_ORIGIN=http://10.0.2.2:3000
```

> Plain HTTP works in a **debug** build only. Release builds refuse cleartext —
> `network_security_config.xml` on Android, and strict ATS on iOS. That is
> intentional: a release build must never be able to send a session cookie in
> the clear.

The origin is compiled into the binary. A build made with this flag pointing
somewhere hostile would send credentials there, so release only from a trusted
machine with the value verified.

---

## Signing material — OWNER ACTION

Not credentials the app reads, but files the build needs. All gitignored.

### Android

| File | Location | Contains |
| --- | --- | --- |
| `pinorpinor-upload-keystore.jks` | Outside the repository | The upload key |
| `android/key.properties` | In the repository tree, **gitignored** | Paths and passwords for the above |

`key.properties` format:

```properties
storePassword=<store password>
keyPassword=<key password>
keyAlias=upload
storeFile=/absolute/path/to/pinorpinor-upload-keystore.jks
```

Generation instructions: `DEPLOYMENT.md` § Google Play.

**Losing the keystore means losing the ability to update the Play listing.** Back
up the `.jks`, both passwords and the alias somewhere durable that is not this
repository.

### iOS

Managed by Xcode and the Developer portal, not by files here.

| Item | Where |
| --- | --- |
| Development / distribution certificates | Keychain on the build Mac |
| Provisioning profiles | Xcode, ideally auto-managed |
| App Store Connect API key | Only if automating uploads |

`*.p12`, `*.cer`, `*.mobileprovision` and `ExportOptions.plist` are gitignored.

---

## Backend environment — for reference only

These live on the **website**, in Vercel's environment settings. They are listed
so it is clear which ones must never migrate into the app.

| Name | Server-side only | Notes |
| --- | --- | --- |
| `DATABASE_URL`, `DIRECT_URL` | Yes | Postgres connection strings |
| `NEXTAUTH_SECRET` | Yes | Signs the session JWT the app carries |
| `NEXTAUTH_URL`, `NEXT_PUBLIC_APP_URL` | Public value | Must be `https://pinorpinor.com` in production |
| `SUPABASE_SERVICE_ROLE_KEY` | **Yes** | Bypasses every access rule |
| `NEXT_PUBLIC_SUPABASE_URL` / `_ANON_KEY` | Browser-visible | **Not used by the app** |
| `EMAIL_PROVIDER`, `EMAIL_API_KEY`, `EMAIL_FROM` | Yes | Resend. Keyed |
| `SMS_PROVIDER`, `SMS_API_KEY`, `SMS_SENDER_ID` | Yes | Termii. **Not keyed** — phone verification does not send |
| `CRON_SECRET` | Yes | Guards the boost-expiry sweep |
| `PAYSTACK_ENABLED`, `PAYSTACK_SECRET_KEY` | Yes | Currently `false`; routes 503 |
| `REDIS_URL` | Yes | Reserved; rate limiting is in-memory today |

If push notifications are implemented later, an `FCM_SERVER_KEY` (or a service
account JSON) joins this list — server-side, never in the app. See
`DEPLOYMENT.md` § Push notifications.

---

## Environments

| Environment | Origin | Who uses it |
| --- | --- | --- |
| Local | `http://10.0.2.2:3000` (emulator) / `http://localhost:3000` | Developer, debug builds only |
| Staging | `https://staging.pinorpinor.com` *(does not exist yet)* | The end-to-end verification described in `DEPLOYMENT.md` |
| Production | `https://pinorpinor.com` | Default; store builds |

A staging deployment is the one piece of infrastructure worth adding. The
integration tests deliberately run against a scripted backend rather than
production, because creating real accounts, reports and contact requests on a
live platform with real members would be worse than having no suite — and
staging is where that gap gets closed.

---

## Verifying a setup

```bash
flutter doctor -v          # toolchain
flutter pub get            # dependencies
flutter analyze            # expect: No issues found
flutter test               # expect: All tests passed
flutter run                # expect: home screen, browsable signed out
```

If the home screen shows an empty discovery grid, that is most likely the
platform's real state rather than a configuration error — every upload is held
for moderation, and production currently has no approved member media. Confirm
with:

```bash
curl "https://pinorpinor.com/api/public/profiles?limit=2"
```

An empty `profiles` array from that command means the app is behaving correctly.
