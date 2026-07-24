import 'package:flutter/material.dart';

/// The single canonical color-threshold function for contract fit scores.
/// `Contract.fitScorePercent` is the only real, AI-produced percentage in the
/// app — this function must not be duplicated elsewhere.
Color fitScoreColor(int percent) {
  if (percent >= 70) return Colors.green;
  if (percent >= 40) return Colors.orange;
  return Colors.red;
}

/// Renders a contract's fit score. This is the **only** widget in the app
/// that displays a percentage — never introduce a progress/percentage
/// indicator anywhere else (there is no real data source for one).
class FitScoreBadge extends StatelessWidget {
  const FitScoreBadge({super.key, required this.percent, this.size = 40});

  final int percent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = fitScoreColor(percent);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$percent%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.28,
        ),
      ),
    );
  }
}
