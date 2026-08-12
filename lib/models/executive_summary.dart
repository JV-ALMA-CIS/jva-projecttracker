import 'package:cloud_firestore/cloud_firestore.dart';

/// How serious an [ExecutiveInsight] is — drives its accent color on the
/// Executive Dashboard (see `executive_dashboard_screen.dart`). Purely a
/// presentation signal the model itself chooses; not derived client-side.
enum ExecutiveInsightSeverity { info, watch, risk }

extension ExecutiveInsightSeverityX on ExecutiveInsightSeverity {
  String get label => switch (this) {
    ExecutiveInsightSeverity.info => 'Info',
    ExecutiveInsightSeverity.watch => 'Watch',
    ExecutiveInsightSeverity.risk => 'Risk',
  };

  static ExecutiveInsightSeverity fromString(String value) {
    return ExecutiveInsightSeverity.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ExecutiveInsightSeverity.info,
    );
  }
}

/// One bullet of the AI Executive Summary — always includes [reasoning] so
/// the insight explains WHY, per this project's AI Design Philosophy
/// (no insight without an explanation attached).
class ExecutiveInsight {
  final String title;
  final String reasoning;
  final ExecutiveInsightSeverity severity;
  final List<String> relatedOpportunityIds;

  const ExecutiveInsight({
    required this.title,
    required this.reasoning,
    this.severity = ExecutiveInsightSeverity.info,
    this.relatedOpportunityIds = const [],
  });

  factory ExecutiveInsight.fromMap(Map<String, dynamic> map) {
    return ExecutiveInsight(
      title: map['title'] as String? ?? '',
      reasoning: map['reasoning'] as String? ?? '',
      severity: ExecutiveInsightSeverityX.fromString(
        map['severity'] as String? ?? 'info',
      ),
      relatedOpportunityIds: List<String>.from(
        map['relatedOpportunityIds'] as List? ?? const [],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'reasoning': reasoning,
      'severity': severity.name,
      'relatedOpportunityIds': relatedOpportunityIds,
    };
  }
}

/// The AI-generated portfolio-wide narrative shown at the top of the
/// Executive Dashboard (Milestone 5.1). Stored as a single document —
/// `analytics/executiveSummary` — rather than a collection, since there is
/// exactly one current summary for the whole company at any time (older
/// summaries are simply overwritten; see ADR-009). Regenerated on demand
/// via `generateExecutiveSummary`, mirroring the "AI reasons over data
/// that's already in Firestore, writes back a small structured result"
/// shape used by classification/match-analysis/strategic-review/
/// recommendations/proposal-generation.
class ExecutiveSummary {
  final String narrative;
  final List<ExecutiveInsight> insights;
  final DateTime? generatedAt;

  const ExecutiveSummary({
    this.narrative = '',
    this.insights = const [],
    this.generatedAt,
  });

  bool get isEmpty => narrative.isEmpty && insights.isEmpty;

  factory ExecutiveSummary.fromMap(Map<String, dynamic> map) {
    return ExecutiveSummary(
      narrative: map['narrative'] as String? ?? '',
      insights: (map['insights'] as List? ?? const [])
          .map(
            (e) =>
                ExecutiveInsight.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      generatedAt: (map['generatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'narrative': narrative,
      'insights': insights.map((i) => i.toMap()).toList(),
      'generatedAt': generatedAt != null
          ? Timestamp.fromDate(generatedAt!)
          : null,
    };
  }
}
