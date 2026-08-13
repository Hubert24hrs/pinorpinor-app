/// Client-side mirrors of the backend's validation rules.
///
/// Every one of these is **advisory**. The server re-checks all of it and is the
/// only authority — these exist so a member gets an answer without a round trip,
/// and so the app never sends a request it already knows will be rejected.
///
/// Sources: `src/lib/username.ts`, `src/lib/validations/auth.ts`,
/// `src/app/api/member/join/route.ts`.
library;

class UsernameRules {
  const UsernameRules._();

  static const int minLength = 3;
  static const int maxLength = 20;

  static const String hint =
      '3–20 characters, lowercase letters, numbers and single underscores. '
      'Must start with a letter.';

  /// Kept in sync with `RESERVED_USERNAMES` on the website. Two hazards: a name
  /// matching a top-level route would shadow the member's own profile page, and
  /// names like `admin` or `support` read as official accounts.
  static const Set<String> reserved = <String>{
    'about',
    'admin',
    'api',
    'browse',
    'contact',
    'dashboard',
    'discover',
    'favicon',
    'forgot_password',
    'join',
    'live',
    'locations',
    'login',
    'maintenance',
    'messages',
    'notifications',
    'privacy',
    'profile',
    'register',
    'reset_password',
    'robots',
    'safety',
    'settings',
    'sitemap',
    'terms',
    'women',
    'signup',
    'signin',
    'signout',
    'logout',
    'auth',
    'account',
    'billing',
    'credits',
    'payments',
    'search',
    'explore',
    'feed',
    'home',
    'help',
    'faq',
    'blog',
    'news',
    'press',
    'careers',
    'jobs',
    'pricing',
    'upgrade',
    'boost',
    'verify',
    'verification',
    'onboarding',
    'welcome',
    'new',
    'edit',
    'delete',
    'static',
    'assets',
    'public',
    'media',
    'images',
    'img',
    'video',
    'videos',
    'uploads',
    'cdn',
    '_next',
    'well_known',
    'administrator',
    'moderator',
    'moderators',
    'mod',
    'staff',
    'team',
    'support',
    'helpdesk',
    'official',
    'pinorpinor',
    'pinor',
    'root',
    'superuser',
    'sysadmin',
    'security',
    'abuse',
    'legal',
    'billing_support',
    'noreply',
    'no_reply',
    'postmaster',
    'webmaster',
    'hostmaster',
    'info',
    'contactus',
    'system',
    'null',
    'undefined',
    'anonymous',
    'guest',
    'me',
    'you',
    'user',
    'users',
    'test',
    'testing',
    'demo',
    'example',
  };

  /// Trim and lowercase, exactly as `normalizeUsername()` does. Illegal
  /// characters are deliberately **not** stripped: silently rewriting what
  /// someone typed hands them a name they did not choose, so they are rejected.
  static String normalize(String raw) => raw.trim().toLowerCase();

  /// Returns null when valid, or a message to show under the field.
  static String? validate(String? raw) {
    final username = normalize(raw ?? '');
    if (username.isEmpty) return 'Please choose a username.';
    if (username.length < minLength) {
      return 'Username must be at least $minLength characters.';
    }
    if (username.length > maxLength) {
      return 'Username must be $maxLength characters or fewer.';
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      return 'Username can only contain lowercase letters, numbers and underscores.';
    }
    if (!RegExp(r'^[a-z]').hasMatch(username)) {
      return 'Username must start with a letter.';
    }
    if (username.endsWith('_')) {
      return 'Username cannot end with an underscore.';
    }
    if (username.contains('__')) {
      return 'Username cannot contain two underscores in a row.';
    }
    if (reserved.contains(username)) {
      return 'That username is reserved. Please choose another.';
    }
    return null;
  }
}

class Validators {
  const Validators._();

  /// The same shape `/api/member/join` enforces. Deliberately permissive —
  /// address validity is proved by the emailed verification code, not a regex.
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String? email(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value.isEmpty) return 'Enter your email address.';
    if (!_email.hasMatch(value)) return 'Please enter a valid email address.';
    return null;
  }

  /// 8–100, matching `registerSchema` and `/api/member/join`. The website's
  /// join form once accepted a one-character password; the floor is enforced on
  /// both sides now.
  static String? password(String? raw) {
    final value = raw ?? '';
    if (value.isEmpty) return 'Choose a password.';
    if (value.length < 8) return 'Password must be at least 8 characters.';
    if (value.length > 100) return 'Password must be 100 characters or fewer.';
    return null;
  }

  static String? confirmPassword(String? raw, String original) {
    if ((raw ?? '').isEmpty) return 'Re-enter your password.';
    if (raw != original) return 'Passwords do not match.';
    return null;
  }

  static String? displayName(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return 'Enter the name other members will see.';
    if (value.length < 2) return 'That name is too short.';
    if (value.length > 50) return 'That name is too long.';
    return null;
  }

  static String? required(String? raw, String message) {
    if ((raw ?? '').trim().isEmpty) return message;
    return null;
  }

  /// E.164, as `normalizePhone` on the backend expects: a leading `+`, a
  /// non-zero first digit, 8–15 digits total.
  static String? phone(String? raw, {bool required = true}) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) {
      return required
          ? 'Enter your WhatsApp number in international format, e.g. +2348012345678.'
          : null;
    }
    final digits = value.replaceAll(RegExp(r'[^\d+]'), '');
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(digits)) {
      return 'Use international format, e.g. +2348012345678.';
    }
    return null;
  }

  /// Server-side 18+ enforcement is what actually gates registration — this is
  /// the same arithmetic, run early so an underage date never leaves the device.
  static int ageOn(DateTime birthDate, [DateTime? now]) {
    final today = now ?? DateTime.now();
    var age = today.year - birthDate.year;
    final monthDelta = today.month - birthDate.month;
    if (monthDelta < 0 || (monthDelta == 0 && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  static bool isAdult(DateTime birthDate, [DateTime? now]) =>
      ageOn(birthDate, now) >= 18;

  static String? birthDate(DateTime? value) {
    if (value == null) return 'Enter your date of birth.';
    if (value.isAfter(DateTime.now())) return 'That date is in the future.';
    if (!isAdult(value)) {
      return 'You must be at least 18 years old to create a profile on Pinorpinor.';
    }
    if (ageOn(value) > 100) return 'Please check your date of birth.';
    return null;
  }

  /// Messages are capped at 1000 characters by the send route.
  static String? messageBody(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return 'Write a message first.';
    if (value.length > 1000) return 'Message too long (1000 characters max).';
    return null;
  }

  static String? bio(String? raw) {
    final value = (raw ?? '').trim();
    if (value.length > 2000) return 'Keep your bio under 2000 characters.';
    return null;
  }

  /// The contact-request note the owner sees when deciding. Capped at 300.
  static String? contactNote(String? raw) {
    final value = (raw ?? '').trim();
    if (value.length > 300) return 'Keep your note under 300 characters.';
    return null;
  }
}
