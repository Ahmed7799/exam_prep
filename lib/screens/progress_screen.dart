import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../calc.dart';
import '../models.dart';
import '../planner.dart';
import 'backup_screen.dart';
import 'card_list_screen.dart';

/// The overall picture: readiness, consistency, a 12-week calendar, the
/// syllabus map, weak topics, and a report to ask Claude about.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, required this.state});

  final AppState state;

  Future<void> _coach(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: state.coachPrompt()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your progress report is copied. Paste it into the Claude app for advice.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        if (state.exam == null) return const SizedBox.shrink();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Progress'),
            actions: [
              IconButton(
                tooltip: 'Backup and import',
                icon: const Icon(Icons.settings_backup_restore),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => BackupScreen(state: state)),
                ),
              ),
            ],
          ),
          body: state.leaves.isEmpty
              ? const Center(child: Text('Add your syllabus to see your progress.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _Readiness(state: state),
                    _Consistency(state: state),
                    _Calendar(state: state),
                    _SyllabusMap(state: state),
                    _WeakTopics(state: state),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.auto_awesome),
                        title: const Text('Ask Claude for a plan'),
                        subtitle: const Text(
                          'Copies a report of where you stand. Paste it into the Claude app '
                          'and it will tell you what to study next.',
                        ),
                        onTap: () => _coach(context),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

Color _scoreColor(double f) {
  if (f >= 0.7) return Colors.green.shade600;
  if (f >= 0.4) return Colors.orange.shade700;
  return Colors.red.shade600;
}

class _Readiness extends StatelessWidget {
  const _Readiness({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = state.readiness;
    final memory = state.memory;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 10,
                    color: _scoreColor(score / 100),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  Center(
                    child: Text('$score%', style: theme.textTheme.headlineSmall),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Exam readiness', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text('Syllabus covered: ${(state.coverage * 100).round()}%'),
                  Text(
                    memory == null
                        ? 'Memory: review some cards to measure it'
                        : 'Remembered now: ${(memory * 100).round()}% of reviewed cards',
                  ),
                  if (state.cards.isNotEmpty)
                    Text('Cards reviewed at least once: ${(state.cardsStarted * 100).round()}%'),
                  Text(
                    '${state.daysLeft} days left',
                    style: theme.textTheme.bodySmall,
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

class _Consistency extends StatelessWidget {
  const _Consistency({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (thisHours, thisReviews) = state.weekTotals(0);
    final (lastHours, lastReviews) = state.weekTotals(1);
    final missed = state.missedDays;
    final change = lastHours <= 0 ? null : ((thisHours - lastHours) / lastHours * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This week', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _Stat(value: formatHours(thisHours), label: 'studied')),
                Expanded(child: _Stat(value: '$thisReviews', label: 'cards reviewed')),
                Expanded(child: _Stat(value: '${state.streak}', label: 'day streak')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Last week: ${formatHours(lastHours)} studied, $lastReviews cards'
              '${change == null ? '' : ' (${change >= 0 ? '+' : ''}$change% hours this week)'}',
              style: theme.textTheme.bodySmall,
            ),
            if (missed > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '$missed study ${missed == 1 ? 'day' : 'days'} in the last week with nothing done.',
                  style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

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

/// 12 weeks of days, darker the more of your planned hours you studied.
class _Calendar extends StatelessWidget {
  const _Calendar({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exam = state.exam!;
    final today = dayOnly(DateTime.now());
    // Start on the Monday 11 weeks before this week's Monday.
    final thisMonday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    final start = DateTime(thisMonday.year, thisMonday.month, thisMonday.day - 77);
    final base = theme.colorScheme.primary;
    final empty = theme.colorScheme.surfaceContainerHighest;

    Color colorFor(DateTime day) {
      if (day.isAfter(today)) return Colors.transparent;
      final cap = capacityOn(exam, day);
      final hours = state.loggedOn(day);
      final reviews = state.reviewsOn(day);
      if (hours <= 0 && reviews <= 0) {
        return cap <= 0 ? empty.withOpacity(0.4) : empty;
      }
      var f = cap > 0 ? hours / cap : 1.0;
      if (hours <= 0 && reviews > 0) f = 0.2;
      if (f > 1) f = 1;
      return base.withOpacity(0.25 + 0.75 * f);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last 12 weeks', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, box) {
                final size = ((box.maxWidth - 24) / 12 - 3).clamp(8.0, 22.0);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                          SizedBox(
                            height: size + 3,
                            width: 20,
                            child: Text(d, style: theme.textTheme.labelSmall),
                          ),
                      ],
                    ),
                    for (var w = 0; w < 12; w++)
                      Column(
                        children: [
                          for (var d = 0; d < 7; d++)
                            Builder(
                              builder: (context) {
                                final day = DateTime(start.year, start.month, start.day + w * 7 + d);
                                return Tooltip(
                                  message: '${formatDay(day)}: ${formatHours(state.loggedOn(day))}, '
                                      '${state.reviewsOn(day)} reviews',
                                  child: Container(
                                    width: size,
                                    height: size,
                                    margin: const EdgeInsets.all(1.5),
                                    decoration: BoxDecoration(
                                      color: colorFor(day),
                                      borderRadius: BorderRadius.circular(3),
                                      border: day == today
                                          ? Border.all(color: theme.colorScheme.onSurface)
                                          : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            Text(
              'Darker means closer to your planned hours. Faint squares are rest days.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Every section of the syllabus with how much of it is done, by paper.
class _SyllabusMap extends StatelessWidget {
  const _SyllabusMap({required this.state});

  final AppState state;

  (double, double) _hours(Topic t) {
    final kids = state.childrenOf(t.id);
    if (kids.isEmpty) return (t.sizeHours, state.remainingOf(t));
    var total = 0.0;
    var left = 0.0;
    for (final k in kids) {
      final (a, b) = _hours(k);
      total += a;
      left += b;
    }
    return (total, left);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Widget>[];
    for (final p in state.papers) {
      final sections = state.sections.where((s) => s.paper == p).toList();
      if (sections.isEmpty) continue;
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(paperName(p), style: theme.textTheme.titleSmall),
      ));
      for (final s in sections) {
        final kids = state.childrenOf(s.id);
        final groups = kids.isEmpty ? [s] : kids;
        for (final g in groups) {
          final (total, left) = _hours(g);
          final f = total <= 0 ? 0.0 : (1 - left / total).clamp(0.0, 1.0);
          rows.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        kids.isEmpty ? g.name : '${s.name} › ${g.name}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text('${(f * 100).round()}%', style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 2),
                LinearProgressIndicator(
                  value: f,
                  minHeight: 6,
                  color: _scoreColor(f),
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ));
        }
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Syllabus map', style: theme.textTheme.titleMedium),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _WeakTopics extends StatelessWidget {
  const _WeakTopics({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weak = state.weakTopics.take(6).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weakest topics', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            if (weak.isEmpty)
              const Text('Shows up once you have reviewed at least 3 cards in a topic.')
            else
              for (final w in weak)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: _scoreColor(w.recall).withOpacity(0.2),
                    child: Text(
                      '${(w.recall * 100).round()}',
                      style: TextStyle(color: _scoreColor(w.recall), fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(w.topic.name),
                  subtitle: Text('${w.cards} cards reviewed · forgotten ${w.lapses} times'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CardListScreen(state: state, topicId: w.topic.id),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
