/// Centralized input validation — the single source of truth for what
/// counts as acceptable data going into recruits, conduct records, and
/// companies. Used by every form's TextFormField validator AND mirrored
/// by RecruitService/CompanyService before any write, so validation
/// can't be skipped just because a particular screen forgot to call it.
///
/// IMPORTANT: this is the client-side half of validation. The real,
/// unbypassable enforcement is the CHECK constraints in
/// supabase_schema.sql — a malicious client could skip this class
/// entirely and call the Supabase REST API directly, the same way it
/// could skip the rate limiter. This class exists to give honest users
/// fast, friendly feedback and to keep the app's own write paths clean;
/// it is not the security boundary.
class Validators {
  Validators._();

  // ── Length limits ────────────────────────────────────────────────────
  // Kept in one place so the Dart limits and the SQL CHECK constraints in
  // supabase_schema.sql can be eyeballed against each other and kept in
  // sync if either changes.
  static const int nameMaxLength = 120;
  static const int idNumberMaxLength = 40;
  static const int phoneMaxLength = 20;
  static const int regionMaxLength = 60;
  static const int roleMaxLength = 60;
  static const int companyNameMaxLength = 150;
  static const int licenseNumberMaxLength = 40;
  static const int addressMaxLength = 300;
  static const int emailMaxLength = 254; // RFC 5321 limit
  static const int conductDescriptionMaxLength = 2000;
  static const int reportedByMaxLength = 120;
  static const int exitReasonMaxLength = 500;

  // ── Patterns ─────────────────────────────────────────────────────────
  // Deliberately permissive on name characters (apostrophes, hyphens,
  // accented letters are all common in real names) while still blocking
  // control characters and the kind of payloads used in injection
  // attempts against systems that don't parameterize queries downstream
  // (Supabase's client does, but defense in depth costs nothing here).
  static final _controlCharsPattern = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]');
  static final _emailPattern =
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _phonePattern = RegExp(r'^[0-9+\-\s()]{6,20}$');

  /// Strips control characters and trims whitespace. Applied to every
  /// free-text field before it's sent anywhere — these characters have no
  /// legitimate purpose in a name, description, or address, and have been
  /// used historically to smuggle terminal escape sequences or confuse
  /// naive log parsers.
  static String sanitize(String input) {
    return input.replaceAll(_controlCharsPattern, '').trim();
  }

  // ── Field validators (return null if valid, error string if not) ─────

  static String? fullName(String? value) {
    final v = sanitize(value ?? '');
    if (v.isEmpty) return 'Full name is required';
    if (v.length > nameMaxLength) {
      return 'Name must be $nameMaxLength characters or fewer';
    }
    if (v.length < 2) return 'Name is too short';
    return null;
  }

  static String? idNumber(String? value) {
    final v = sanitize(value ?? '');
    if (v.isEmpty) return 'ID number is required';
    if (v.length > idNumberMaxLength) {
      return 'ID number must be $idNumberMaxLength characters or fewer';
    }
    return null;
  }

  static String? phone(String? value, {bool required = true}) {
    final v = sanitize(value ?? '');
    if (v.isEmpty) return required ? 'Phone number is required' : null;
    if (v.length > phoneMaxLength) {
      return 'Phone number must be $phoneMaxLength characters or fewer';
    }
    if (!_phonePattern.hasMatch(v)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? email(String? value) {
    final v = sanitize(value ?? '');
    if (v.isEmpty) return 'Email is required';
    if (v.length > emailMaxLength) {
      return 'Email must be $emailMaxLength characters or fewer';
    }
    if (!_emailPattern.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? companyName(String? value) {
    final v = sanitize(value ?? '');
    if (v.isEmpty) return 'Company name is required';
    if (v.length > companyNameMaxLength) {
      return 'Company name must be $companyNameMaxLength characters or fewer';
    }
    if (v.length < 2) return 'Company name is too short';
    return null;
  }

  static String? licenseNumber(String? value) {
    final v = sanitize(value ?? '');
    if (v.isEmpty) return 'License number is required';
    if (v.length > licenseNumberMaxLength) {
      return 'License number must be $licenseNumberMaxLength characters or fewer';
    }
    return null;
  }

  static String? region(String? value) {
    final v = sanitize(value ?? '');
    if (v.isEmpty) return 'Region is required';
    if (v.length > regionMaxLength) {
      return 'Region must be $regionMaxLength characters or fewer';
    }
    return null;
  }

  static String? role(String? value) {
    final v = sanitize(value ?? '');
    if (v.isEmpty) return 'Role is required';
    if (v.length > roleMaxLength) {
      return 'Role must be $roleMaxLength characters or fewer';
    }
    return null;
  }

  static String? address(String? value, {bool required = false}) {
    final v = sanitize(value ?? '');
    if (v.isEmpty) return required ? 'Address is required' : null;
    if (v.length > addressMaxLength) {
      return 'Address must be $addressMaxLength characters or fewer';
    }
    return null;
  }

  static String? conductDescription(String? value) {
    final v = sanitize(value ?? '');
    if (v.isEmpty) return 'Description is required';
    if (v.length < 10) {
      return 'Please provide a more detailed description (at least 10 characters)';
    }
    if (v.length > conductDescriptionMaxLength) {
      return 'Description must be $conductDescriptionMaxLength characters or fewer';
    }
    return null;
  }

  static String? reportedBy(String? value) {
    final v = sanitize(value ?? '');
    if (v.isEmpty) return 'Reporter name is required';
    if (v.length > reportedByMaxLength) {
      return 'Must be $reportedByMaxLength characters or fewer';
    }
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    if (v.length > 128) return 'Password is too long';
    final hasLetter = v.contains(RegExp(r'[A-Za-z]'));
    final hasDigit = v.contains(RegExp(r'[0-9]'));
    if (!hasLetter || !hasDigit) {
      return 'Password must include both letters and numbers';
    }
    return null;
  }

  /// Throws ArgumentError if invalid — used in service layer methods as a
  /// belt-and-suspenders check right before a write, independent of
  /// whatever the calling screen's form validation already did. Catches
  /// the case where a screen's validator and the service's expectations
  /// drift apart over time, or a future screen forgets to validate at all.
  static void assertValid(String? error, String fieldLabel) {
    if (error != null) {
      throw ArgumentError('$fieldLabel: $error');
    }
  }
}
