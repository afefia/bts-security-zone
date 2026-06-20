import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Result of a fingerprint capture attempt.
class FingerprintCaptureResult {
  final bool success;
  final String? template; // what gets stored in recruits.fingerprint_hash
  final String? error;

  const FingerprintCaptureResult({
    required this.success,
    this.template,
    this.error,
  });
}

/// Result of comparing a freshly-scanned finger against a stored template.
class FingerprintMatchResult {
  final bool isMatch;
  final double score; // 0.0–1.0, vendor-normalized confidence
  const FingerprintMatchResult({required this.isMatch, required this.score});
}

/// Abstraction over "however we currently get and compare a fingerprint."
///
/// WHY THIS EXISTS:
/// Matching one person's finger against thousands of stored records (1:N
/// identification) requires a dedicated fingerprint scanner and its vendor
/// SDK (Mantra MFS100, SecuGen, DigitalPersona, etc.) — phone biometrics
/// (Face ID / Android fingerprint unlock) only do 1:1 "is this the device
/// owner," which isn't useful for "who is standing in front of me."
///
/// THE TWO THINGS A REAL PROVIDER MUST DO, AND WHY BOTH MATTER:
/// 1. CAPTURE — get a template off the scanner hardware.
/// 2. MATCH   — compare two templates and say whether they're the same
///    finger. This is the part the software fallback genuinely cannot
///    do: no two scans of the same finger produce identical bytes, so a
///    simple `template1 == template2` check (which is all a hash
///    comparison can ever do) will never match, even for the right
///    person. Real fingerprint matching needs minutiae-based comparison,
///    which is why this interface has a dedicated `match()` method
///    instead of leaving callers to compare templates themselves.
abstract class FingerprintProvider {
  bool get isHardwareAvailable;

  Future<FingerprintCaptureResult> capture();

  /// Compares a freshly-captured template against one previously stored
  /// for a candidate recruit. Called once per candidate during search —
  /// see [FingerprintService.findMatch] for how multiple candidates are
  /// narrowed down before this gets called, since running full minutiae
  /// matching against every recruit in the database on every scan would
  /// be far too slow.
  Future<FingerprintMatchResult> match(String capturedTemplate, String storedTemplate);
}

/// Default provider used until real scanner hardware is connected.
/// This does NOT do real biometric capture or matching — it exists so the
/// rest of the app (UI, database writes, audit logging, search flow) can
/// be built and demoed today without hardware on hand. Every value it
/// returns is clearly marked as simulated so nobody mistakes a demo run
/// for a working biometric system.
class SoftwareFallbackProvider implements FingerprintProvider {
  @override
  bool get isHardwareAvailable => false;

  @override
  Future<FingerprintCaptureResult> capture() async {
    await Future.delayed(const Duration(seconds: 2));

    final randomSeed =
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    final hash = sha256.convert(utf8.encode(randomSeed)).toString();

    return FingerprintCaptureResult(
      success: true,
      template: 'sw_${hash.substring(0, 32)}',
    );
  }

  @override
  Future<FingerprintMatchResult> match(
      String capturedTemplate, String storedTemplate) async {
    // Deliberately exact-match only, and only ever true if somehow the
    // same simulated value were captured twice in a row (it won't be,
    // since capture() above is randomized) — this provider exists to let
    // the UI flow be tested, not to pretend it can identify anyone.
    final isMatch = capturedTemplate == storedTemplate;
    return FingerprintMatchResult(isMatch: isMatch, score: isMatch ? 1.0 : 0.0);
  }
}

// ============================================================
//  REAL HARDWARE INTEGRATION — Mantra MFS100 reference implementation
// ============================================================
//
// This class is fully written out (not a sketch) so wiring in real
// hardware is "uncomment + add one pubspec line", not "design this from
// scratch". It's commented out because the `mantra_mfs100` package isn't
// on pub.dev under a stable public API at the time this was written, and
// because shipping a reference to an uninstalled package would break the
// build for everyone who hasn't bought the scanner yet.
//
// TO ACTIVATE:
// 1. Obtain the Mantra MFS100 Flutter plugin (via their SDK portal or a
//    community wrapper) and add it to pubspec.yaml.
// 2. Delete the /* and */ below.
// 3. Replace `MantraMfs100` calls with whatever the actual plugin's API
//    surface turns out to be — vendor plugin APIs vary and may not match
//    this exactly, but the shape (capture returns a template + quality
//    score, matching is a separate vendor-provided call) is standard
//    across fingerprint SDKs, including SecuGen and DigitalPersona.
// 4. Pass `MantraFingerprintProvider()` into `FingerprintService()` in
//    search_screen.dart and register_recruit_screen.dart.
//
/*
class MantraFingerprintProvider implements FingerprintProvider {
  @override
  bool get isHardwareAvailable => MantraMfs100.isDeviceConnected();

  @override
  Future<FingerprintCaptureResult> capture() async {
    try {
      final scan = await MantraMfs100.captureFinger(
        timeoutSeconds: 10,
        qualityThreshold: 60, // vendor-specific 0-100 scale
      );

      if (scan == null || scan.quality < 60) {
        return const FingerprintCaptureResult(
          success: false,
          error: 'Scan quality too low. Clean the sensor and the finger, then try again.',
        );
      }

      // Store the vendor's template format (commonly base64-encoded
      // ISO/IEC 19794-2), NOT a hash of it — matching needs the real
      // template, and a hash destroys the structure matching relies on.
      return FingerprintCaptureResult(
        success: true,
        template: scan.isoTemplateBase64,
      );
    } catch (e) {
      return FingerprintCaptureResult(success: false, error: 'Scanner error: $e');
    }
  }

  @override
  Future<FingerprintMatchResult> match(
      String capturedTemplate, String storedTemplate) async {
    // Most vendor SDKs expose a match score (0-100) between two
    // templates rather than a boolean — pick a threshold that matches
    // your SDK's documented false-accept-rate guidance. 70+ is a common
    // conservative starting point in vendor docs.
    final score = await MantraMfs100.matchTemplates(
      template1: capturedTemplate,
      template2: storedTemplate,
    );
    return FingerprintMatchResult(
      isMatch: score >= 70,
      score: score / 100.0,
    );
  }
}
*/

class FingerprintService {
  final FingerprintProvider provider;

  FingerprintService({FingerprintProvider? provider})
      : provider = provider ?? SoftwareFallbackProvider();

  bool get isUsingRealHardware => provider.isHardwareAvailable;

  Future<FingerprintCaptureResult> capture() => provider.capture();

  /// Finds which (if any) of [candidates] matches a freshly-captured
  /// fingerprint. This is the actual 1:N identification flow: rather than
  /// running expensive minutiae matching against every recruit in the
  /// database, [candidates] should already be narrowed down by the
  /// caller (e.g. recruits in the same region, or all recruits if the
  /// dataset is small enough) before reaching this method.
  ///
  /// Returns the matching candidate's id, or null if no candidate's
  /// stored template matches strongly enough.
  Future<String?> findMatch({
    required String capturedTemplate,
    required Map<String, String> candidates, // recruitId -> storedTemplate
  }) async {
    String? bestId;
    double bestScore = 0;

    for (final entry in candidates.entries) {
      final result = await provider.match(capturedTemplate, entry.value);
      if (result.isMatch && result.score > bestScore) {
        bestScore = result.score;
        bestId = entry.key;
      }
    }

    return bestId;
  }
}
