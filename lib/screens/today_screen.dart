import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calc.dart';
import '../models.dart';

/// Home tab: countdown, how much syllabus is left against the hours you have.
/// The daily slate itself arrives with the planner in phase 2.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final exam = state.exam;
        if (exam == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final days = state.daysLeft;
        final available = state.availableHours;
        final remaining = state.remainingHours;
        final gap = available - remaining;
        final counts = state.stageCounts;
        final hasTopics = state.leaves.isNotEmpty;

        return Scaffold(
          appBar: AppBar(title: Text(exam.name)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        days > 0 ? '$days' : (days == 0 ? 'Today' : 'Passed'),
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        days > 0
                            ? 'days to go until ${formatDate(exam.date)}'
                            : 'Exam date: ${formatDate(exam.date)}. Update it in Syllabus > Exam settings.',
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: state.doneFraction,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasTopics
                            ? '${(state.doneFraction * 100).round()}% of topics complete'
                            : 'No topics yet. Add your syllabus in the Syllabus tab.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              if (hasTopics && days > 0)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Time check', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _Number(
                                label: 'Hours you have',
                                value: formatHours(available),
                              ),
                            ),
                            Expanded(
                              child: _Number(
                                label: 'Hours left in syllabus',
                                value: formatHours(remaining),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          gap >= 0
                              ? 'Buffer of ${formatHours(gap)} before revision time is counted.'
                              : 'Short by ${formatHours(-gap)}. Add hours, cut topics or move the date.',
                          style: TextStyle(
                            color: gap >= 0 ? Colors.green : theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Estimates use each topic\'s size, which you can edit in Syllabus.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              if (hasTopics)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Topics by stage', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final s in Stage.values)
                              Chip(
                                avatar: CircleAvatar(
                                  backgroundColor: s.color,
                                  radius: 6,
                                ),
                                label: Text('${s.label}: ${counts[s]}'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Today\'s slate'),
                  subtitle: const Text(
                    'Your daily plan and due reviews appear here from phase 2 on.',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Number extends StatelessWidget {
  const _Number({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.headlineSmall),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
