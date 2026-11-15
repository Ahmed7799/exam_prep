import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calc.dart';
import '../planner.dart';

/// The day-by-day schedule built backwards from the exam date.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final exam = state.exam;
        if (exam == null) return const SizedBox.shrink();
        final plan = state.plan;
        final remaining = state.remainingLeaves;

        if (remaining.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Plan')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  state.leaves.isEmpty
                      ? 'Add your syllabus first, then the plan is built from it.'
                      : 'Every topic is complete. Nothing left to plan.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final days = plan.days.where((d) => d.items.isNotEmpty || d.isRevision).toList();
        final last = plan.lastFinish;

        return Scaffold(
          appBar: AppBar(title: const Text('Plan')),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: days.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) return _Summary(state: state, plan: plan, last: last);
              final d = days[i - 1];
              return _DayCard(day: d, isToday: d.date == dayOnly(DateTime.now()));
            },
          ),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.state, required this.plan, required this.last});

  final AppState state;
  final Plan plan;
  final DateTime? last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exam = state.exam!;
    final overdue = state.overdue;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan.fits
                  ? (last == null
                      ? 'Plan ready'
                      : 'Syllabus finishes ${formatDay(last!)}')
                  : 'Does not fit before ${formatDate(exam.date)}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            if (!plan.fits)
              Text(
                '${plan.overflow.length} topics (${formatHours(plan.overflowHours)}) are left over. '
                'Add study hours, trim topic sizes or move the exam date.',
                style: TextStyle(color: theme.colorScheme.error),
              )
            else if (plan.revisionDaysUsed)
              Text(
                'Tight: new topics run into your revision days, so revision will be short.',
                style: TextStyle(color: Colors.orange.shade800),
              )
            else
              const Text('Revision days are kept free at the end.'),
            if (state.hasPlan && overdue.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${overdue.length} topics are behind your saved plan '
                '(${formatHours(state.overdueHours)}).',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    await state.replan();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Plan saved. You are held to these dates.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.flag),
                  label: Text(state.hasPlan ? 'Re-plan from today' : 'Save as my plan'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              state.hasPlan
                  ? 'Re-planning resets the dates you are measured against.'
                  : 'Saving fixes the dates. After that, missed topics are flagged as behind.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.isToday});

  final PlanDay day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: isToday ? theme.colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isToday ? 'Today, ${formatDay(day.date)}' : formatDay(day.date),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  day.isRevision && day.items.isEmpty
                      ? 'Revision'
                      : formatHours(day.used),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            if (day.items.isEmpty && day.isRevision)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Review your cards and weak topics.'),
              ),
            for (final item in day.items)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      item.finishes ? Icons.check_circle_outline : Icons.timelapse,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${item.topic.name} (${formatHours(item.hours)}'
                        '${item.finishes ? '' : ', continues'})',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
