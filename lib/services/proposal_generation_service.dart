import 'package:cloud_functions/cloud_functions.dart';
import 'package:jva_projecttracker/services/proposal_generation_parser.dart';

/// The five ways `generateProposalSection` can be invoked — "reset to
/// previous version" is deliberately not here, since it's a plain local
/// Firestore write (`ProposalSectionService.restorePreviousVersion`), not
/// an AI call.
enum ProposalGenerationMode { generate, regenerate, improve, expand, shorten }

/// Thrown for every failure mode `ProposalGenerationService.generateSection`
/// can hit — API failures, timeouts, invalid/empty model output — so the UI
/// layer only ever needs to catch one exception type and show its message.
/// Mirrors `StrategicReviewException` exactly.
class ProposalGenerationException implements Exception {
  const ProposalGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the `generateProposalSection` Cloud Function, which reasons over
/// the opportunity's full AI chain (classification → match analysis →
/// strategic review → recommendations) plus the Company Knowledge Graph
/// (see `functions/index.js`) and writes the generated content directly to
/// the `proposalSections` document — the live
/// `proposalSectionsByProposalIdProvider` stream picks that up on its own.
/// The parsed-and-validated result is also returned here so the calling
/// card can render it immediately, without waiting for the stream. Mirrors
/// `StrategicReviewService` exactly — see ADR-006 for why this shape is
/// used by every Gemini-backed service in this app.
class ProposalGenerationService {
  /// [invokeOverride] replaces the actual Cloud Function call entirely —
  /// used by tests to supply canned responses with no Firebase involved at
  /// all. Production code never sets it.
  ProposalGenerationService({
    FirebaseFunctions? functions,
    Future<Map<String, dynamic>?> Function({
      required String sectionId,
      required String mode,
    })?
    invokeOverride,
  }) : _functionsOverride = functions,
       // ignore: prefer_initializing_formals
       _invokeOverride = invokeOverride;

  final FirebaseFunctions? _functionsOverride;
  final Future<Map<String, dynamic>?> Function({
    required String sectionId,
    required String mode,
  })?
  _invokeOverride;

  // Resolved lazily — constructing this with only invokeOverride set (the
  // shape every test in this app uses) must not require Firebase Core to
  // be initialized.
  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  Future<Map<String, dynamic>?> _invoke(String sectionId, String mode) {
    final override = _invokeOverride;
    if (override != null) return override(sectionId: sectionId, mode: mode);
    return _callCloudFunction(sectionId, mode);
  }

  Future<Map<String, dynamic>?> _callCloudFunction(
    String sectionId,
    String mode,
  ) async {
    final callable = _functions.httpsCallable(
      'generateProposalSection',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );
    final response = await callable.call<Map<String, dynamic>>({
      'sectionId': sectionId,
      'mode': mode,
    });
    return response.data;
  }

  Future<ProposalGenerationResult> generateSection({
    required String sectionId,
    required ProposalGenerationMode mode,
  }) async {
    Map<String, dynamic>? raw;
    try {
      raw = await _invoke(sectionId, mode.name);
    } on FirebaseFunctionsException catch (e) {
      throw ProposalGenerationException(_messageForFunctionsException(e));
    } catch (e) {
      throw ProposalGenerationException('$e');
    }

    final result = parseProposalGenerationResponse(raw);
    if (result == null) {
      throw const ProposalGenerationException('the response was unusable.');
    }
    return result;
  }

  /// Every branch returns a lowercase-leading fragment, not a full sentence
  /// — see the comment above on why (avoids doubling up with the caller's
  /// own "Proposal generation failed:" prefix).
  String _messageForFunctionsException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'deadline-exceeded':
        return 'it timed out. Please try again.';
      case 'not-found':
        return 'the section was not found.';
      case 'invalid-argument':
        return 'the request was invalid.';
      default:
        return e.message ?? 'of an unknown error.';
    }
  }
}
