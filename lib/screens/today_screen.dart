import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calc.dart';
import '../models.dart';
import '../planner.dart';
import 'study_picker_screen.dart';
import 'study_sheet.dart';

/// Home tab: countdown, today's study hours, and the chapter picker.
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
              if (hasTopics && days > 0) _TodayCard(state: state),
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
    final Color color;
    final IconData icon;
    final String title;
    switch (level) {
      case Alert.nudge:
        color = Colors.amber.shade800;
        icon = Icons.info_outline;
        title = 'Slightly behind';
      case Alert.warning:
        color = Colors.orange.shade800;
        icon = Icons.warning_amber;
        title = 'You are falling behind';
      default:
        color = Colors.red.shade700;
        icon = Icons.error_outline;
        title = 'Serious risk of missing the exam plan';
    }
    final pace = state.weekPace;
    final f = state.forecast;
    final message = StringBuffer();
    if (pace.shortfall > 0.0001) {
      message.write(
        'You logged ${formatHours(pace.logged)} of ${formatHours(pace.planned)} '
        'planned over the last ${pace.days} study days. ',
      );
    }
    if (!f.canFinish) {
      message.write(
        '${formatHours(f.shortBy)} of syllabus will not fit before the exam at your current hours. ',
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

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = state.todayTarget;
    final done = state.hoursOn(DateTime.now());
    final fraction = target > 0 ? (done / target) : (done > 0 ? 1.0 : 0.0);
    final suggested = state.suggestedPaper;
    final started = state.inProgress.take(3).toList();
    final todays = state.logsOn(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              target > 0
                  ? '${formatHours(done)} of ${formatHours(target)} studied'
                  : (done > 0
                      ? '${formatHours(done)} studied on a rest day'
                      : 'Rest day. Come back tomorrow.'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: fraction > 1 ? 1.0 : fraction,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            if (done > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in state.papers)
                    if (state.hoursOn(DateTime.now(), paper: p) > 0)
                      Chip(
                        label: Text(
                          '${paperShort(p)}: ${formatHours(state.hoursOn(DateTime.now(), paper: p))}',
                        ),
                      ),
                ],
              ),
            ],
            if (suggested != null) ...[
              const SizedBox(height: 8),
              Text(
                '${paperShort(suggested)} got less time this week. Consider a '
                '${paperShort(suggested)} chapter today.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StudyPickerScreen(state: state),
                  ),
                ),
                icon: const Icon(Icons.menu_book),
                label: const Text('What are you studying?'),
              ),
            ),
            if (started.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Continue', style: theme.textTheme.titleSmall),
              for (final t in started)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: CircleAvatar(backgroundColor: t.stage.color, radius: 7),
                  title: Text(t.name),
                  subtitle: Text(
                    '${paperShort(state.paperOf(t))} \u00b7 '
                    '${formatHours(state.loggedHoursOf(t))} of ${formatHours(t.sizeHours)}',
                  ),
                  onTap: () => showStudySheet(context, state, t),
                ),
            ],
            if (todays.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Logged today', style: theme.textTheme.titleSmall),
              for (final l in todays)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(state.topicById(l.topicId)?.name ?? 'Removed topic'),
                  subtitle: Text(formatHours(l.hours)),
                  trailing: IconButton(
                    tooltip: 'Remove this entry',
                    icon: const Icon(Icons.close),
                    onPressed: () => state.deleteLog(l),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
