import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calc.dart';
import '../models.dart';
import '../planner.dart';

/// The blunt daily warning. Pops with true if you choose to start studying.
class RealityCheckDialog extends StatelessWidget {
  const RealityCheckDialog({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final alarm = state.alert == Alert.alarm;
    final color = alarm ? Colors.red.shade700 : Colors.orange.shade800;
    final pace = state.weekPace;
    final f = state.forecast;
    final lag = state.laggingPaper;
    final lines = <String>[
      '${state.daysLeft} days to the exam. ${formatHours(f.remaining)} of syllabus still to study.',
      if (pace.planned > 0)
        'Last ${pace.days} study days: ${formatHours(pace.logged)} done of ${formatHours(pace.planned)} '
            'planned. You are ${formatHours(pace.shortfall)} short.',
      if (state.missedDays > 0)
        '${state.missedDays} study ${state.missedDays == 1 ? 'day' : 'days'} this week with nothing done at all.',
      if (!f.canFinish)
        'At your planned hours, ${formatHours(f.shortBy)} of the syllabus will never be covered.'
      else if (!f.fits)
        'You can only finish by eating into your revision days.',
      if (lag != null)
        '${paperShort(lag.paper)} is only ${(lag.doneFraction * 100).round()}% done. It carries the same marks.',
      if (state.dueCards.length > 50) '${state.dueCards.length} flashcards are waiting for review.',
    ];
    return AlertDialog(
      icon: Icon(alarm ? Icons.error : Icons.warning_amber, color: color, size: 40),
      title: Text(
        alarm ? 'You are not on track' : 'You are slipping',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
                      child: Icon(Icons.circle, size: 6, color: color),
                    ),
                    Expanded(child: Text(l)),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              f.studyDays > 0
                  ? 'To finish on time you need ${formatHours(f.needPerDay)} on every study day from today.'
                  : 'There are no study days left before the exam.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Later')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Start studying now'),
        ),
      ],
    );
  }
}
