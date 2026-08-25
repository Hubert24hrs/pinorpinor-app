/// Age, from whichever of the two things the backend knows.
///
/// **Mirrors the website's `src/lib/age.ts`.**
///
/// ## Why there are two columns
///
/// `birthDate` is a full date of birth and only pre-2026-08-14 accounts have
/// one — registration stopped asking that day, which left the platform with no
/// age at all on every account created since. `birthYear` is what registration
/// collects now: the year only, typed by the member and editable afterwards.
/// One box gets filled in where three do not.
///
/// The app never receives either. Both are stripped from every public payload —
/// `birthDate` would let a caller recover an exact date of birth and `birthYear`
/// a precise year, which is worse than the derived age it replaces. What arrives
/// is `age`, already resolved server-side. This module exists for the **owner's
/// own** screens, where the year is editable, and to keep the 18+ rule the app
/// enforces identical to the one the route enforces.
///
/// ## The imprecision is real and is not hidden
///
/// From a year alone the best available answer is the age someone *turns* this
/// year, so for most of the calendar it reads one year high. That is a
/// deliberate trade against three fields most people abandon, and the comparison
/// that matters is not against a perfect date — it is against what this
/// replaced, which was nothing at all.
///
/// **Never synthesise a birthDate from a birthYear.** Writing 1 January into
/// `birthDate` would be indistinguishable later from a real date, and real ones
/// exist on this platform.
library;

/// Below any living member; above it, a typo. Matches the database CHECK.
const int kMinBirthYear = 1900;

/// The floor the platform is built on, everywhere.
const int kMinimumAge = 18;

/// The most recent year of birth that still makes someone an adult this
/// calendar year.
int maxAdultBirthYear([DateTime? now]) =>
    (now ?? DateTime.now().toUtc()).year - kMinimumAge;

/// The age to display, or null when nothing is known.
///
/// **Null is a real answer and every caller must render it as "no age shown".**
/// There is no default, no "unknown" placeholder and no guess: an age is a fact
/// about a person, and inventing one puts a claim on their public profile that
/// they never made.
int? resolveAge({DateTime? birthDate, int? birthYear, DateTime? now}) {
  final DateTime moment = (now ?? DateTime.now()).toUtc();

  // An exact date beats a derived one wherever both exist.
  if (birthDate != null) {
    final DateTime dob = birthDate.toUtc();
    int age = moment.year - dob.year;
    final int monthDiff = moment.month - dob.month;
    if (monthDiff < 0 || (monthDiff == 0 && moment.day < dob.day)) age--;
    return (age >= 0 && age < 130) ? age : null;
  }

  if (birthYear != null) {
    final int age = moment.year - birthYear;
    return (age >= 0 && age < 130) ? age : null;
  }

  return null;
}

/// The result of checking a member-entered year.
sealed class BirthYearCheck {
  const BirthYearCheck();
}

class BirthYearValid extends BirthYearCheck {
  const BirthYearValid(this.year);
  final int year;
}

class BirthYearInvalid extends BirthYearCheck {
  const BirthYearInvalid(this.message);

  /// The backend's own wording, so the member never sees two different
  /// explanations for the same refusal.
  final String message;
}

/// Validates a member-entered year, mirroring `validateBirthYear`.
///
/// Accepts a number or a string, because it arrives from a form. The measure is
/// approximate in the member's favour — somebody born in 2008 is accepted
/// throughout 2026 even if they do not turn 18 until December.
///
/// **This is an age declaration with a sanity bound, never verification**, and
/// it must not be described in the product as the latter. Same rule the 18+
/// tickbox has always had; `verificationStatus` stays NONE either way.
BirthYearCheck validateBirthYear(Object? input, [DateTime? now]) {
  final int? raw = input is int
      ? input
      : int.tryParse(input?.toString().trim() ?? '');

  if (raw == null) {
    return const BirthYearInvalid(
      'Enter your year of birth, for example 1998.',
    );
  }
  if (raw < kMinBirthYear) {
    return const BirthYearInvalid('That year of birth does not look right.');
  }
  if (raw > maxAdultBirthYear(now)) {
    return const BirthYearInvalid(
      'You must be $kMinimumAge or over to use Pinorpinor.',
    );
  }
  return BirthYearValid(raw);
}

/// Form-field convenience: the message, or null when the year is storable.
String? birthYearError(String? input, [DateTime? now]) {
  final BirthYearCheck check = validateBirthYear(input, now);
  return check is BirthYearInvalid ? check.message : null;
}
