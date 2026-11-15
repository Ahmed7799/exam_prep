import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calc.dart';
import '../models.dart';
import '../planner.dart';
import 'stage_sheet.dart';

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
              if (hasTopics && days > 0) _AlertBanner(state: state),
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
              if (hasTopics && days > 0) _Slate(state: state),
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

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final level = state.alert;
    if (level == Alert.onTrack) return const SizedBox.shrink();
    final (Color color, IconData icon, String title) = switch (level) {
      Alert.nudge => (Colors.amber.shade800, Icons.info_outline, 'Slightly behind'),
      Alert.warning => (Colors.orange.shade800, Icons.warning_amber, 'You are falling behind'),
      _ => (Colors.red.shade700, Icons.error_outline, 'Serious risk of missing the plan'),
    };
    final behind = state.hasPlan && state.overdue.isNotEmpty;
    final plan = state.plan;
    final message = StringBuffer();
    if (behind) {
      message.write(
        '${state.overdue.length} topics (${formatHours(state.overdueHours)}) are past their planned date. ',
      );
    }
    if (!plan.fits) {
      message.write(
        '${formatHours(plan.overflowHours)} of syllabus will not fit before the exam at this pace. ',
      );
    }
    if (message.isEmpty) message.write('Check the Plan tab.');
    return Card(
      color: color.withOpacity(0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: 1.5),
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        subtitle: Text(message.toString().trim()),
      ),
    );
  }
}

class _Slate extends StatelessWidget {
  const _Slate({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.remainingLeaves.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.celebration_outlined),
          title: Text('All topics complete'),
          subtitle: Text('Use the time left for revision.'),
        ),
      );
    }
    if (!state.hasPlan) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No plan yet', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              const Text(
                'Save a plan and the app will hold you to it, day by day.',
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: state.replan,
                icon: const Icon(Icons.flag),
                label: const Text('Make my plan'),
              ),
            ],
          ),
        ),
      );
    }
    final today = state.todayPlan;
    final todayIds = {for (final i in today?.items ?? const <PlanItem>[]) i.topic.id};
    final overdueAll = state.overdue;
    final overdue = overdueAll.where((t) => !todayIds.contains(t.id)).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today\'s slate', style: theme.textTheme.titleMedium),
            if (state.needsReplan)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Topics changed since you saved the plan.'),
                    ),
                    TextButton(onPressed: state.replan, child: const Text('Re-plan')),
                  ],
                ),
              ),
            if (overdue.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Behind plan',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              for (final t in overdue.take(5))
                _TopicTile(state: state, topic: t, subtitle: 'Was due ${formatDay(t.dueDate!)}'),
              if (overdue.length > 5) Text('and ${overdue.length - 5} more in Syllabus.'),
            ],
            const SizedBox(height: 8),
            if (today == null || today.items.isEmpty)
              Text(
                today == null
                    ? 'Rest day. Come back tomorrow.'
                    : 'Nothing new planned. Review your cards and weak topics.',
              )
            else ...[
              Text(
                'Planned for today (${formatHours(today.used)})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final item in today.items)
                _TopicTile(
                  state: state,
                  topic: item.topic,
                  subtitle: '${overdueAll.any((t) => t.id == item.topic.id) ? 'Behind plan, ' : ''}'
                      '${formatHours(item.hours)}${item.finishes ? '' : ', continues tomorrow'}',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.state, required this.topic, required this.subtitle});

  final AppState state;
  final Topic topic;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: CircleAvatar(backgroundColor: topic.stage.color, radius: 7),
      title: Text(topic.name),
      subtitle: Text('$subtitle · ${topic.stage.label}'),
      trailing: const Icon(Icons.more_horiz),
      onTap: () => pickStage(context, state, topic),
    );
  }
}
