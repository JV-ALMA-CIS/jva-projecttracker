import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/team_share.dart';

/// Public link to one opportunity in the web app — opens it directly (see
/// PushNotificationService's `?opportunityId=` handling). For forwarding on
/// WhatsApp / email.
String opportunityShareLink(String opportunityId) =>
    'https://jva-projecttracker.web.app/?opportunityId='
    '${Uri.encodeQueryComponent(opportunityId)}';

/// "Share with team": reads recent shares and asks the
/// `shareOpportunityWithTeam` Cloud Function to record + push a new one.
class TeamShareService {
  TeamShareService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestoreOverride = firestore,
      _functionsOverride = functions;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseFunctions? _functionsOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  /// Shares from the last [days] days, newest first.
  Stream<List<TeamShare>> watchRecent({int days = 14}) {
    final since = Timestamp.fromDate(
      DateTime.now().subtract(Duration(days: days)),
    );
    return _firestore
        .collection('teamShares')
        .where('createdAt', isGreaterThanOrEqualTo: since)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => TeamShare.fromMap(d.id, d.data())).toList(),
        );
  }

  /// Pushes [opportunityId] to everyone else's devices with an optional
  /// [note]. [justAdded] announces an opportunity the person just added.
  /// Returns how many devices it reached.
  Future<int> share(
    String opportunityId, {
    String note = '',
    bool justAdded = false,
  }) async {
    final result = await _functions
        .httpsCallable('shareOpportunityWithTeam')
        .call<Map<String, dynamic>>({
          'opportunityId': opportunityId,
          'note': note,
          'justAdded': justAdded,
        });
    return (result.data['recipients'] as num?)?.toInt() ?? 0;
  }
}

final teamShareServiceProvider = Provider((ref) => TeamShareService());

final recentTeamSharesProvider = StreamProvider<List<TeamShare>>(
  (ref) => ref.watch(teamShareServiceProvider).watchRecent(),
);
