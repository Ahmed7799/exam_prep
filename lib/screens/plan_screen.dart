import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calc.dart';
import '../models.dart';
import '../planner.dart';
import 'papers_screen.dart';

/// Forecast, progress per paper and a look at the last week.
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
        return Scaffold(
          appBar: AppBar(
            title: const Text('Plan'),
            actions: [
              IconButton(
                tooltip: 'Assign papers',
                icon: const Icon(Icons.swap_horiz),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => PapersScreen(state: state)),
                ),
              ),
            ],
          ),
          body: state.leaves.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Add your syllabus first. The plan is built from its topics.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ForecastCard(state: state),
                    if (state.hasUntaggedPaper) _UntaggedCard(state: state),
                    for (final p in state.papers)
                      if (p != 0) _PaperCard(stats: state.statsFor(p)),
                    _BalanceNote(state: state),
                    _WeekCard(state: state),
                  ],
                ),
        );
      },
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = state.forecast;
    final exam = state.exam!;
    String title;
    String detail;
    Color? color;
    if (f.done) {
      title = 'Every chapter is complete';
      detail = 'Use the days left for revision.';
    } else if (f.studyDays == 0) {
      title = 'No study days left before ${formatDate(exam.date)}';
      detail = 'Move the exam date or add study hours in Exam settings.';
      color = theme.colorScheme.error;
    } else if (!f.canFinish) {
      title = 'Short by ${formatHours(f.shortBy)}';
      detail = 'Even using every study hour, ${formatHours(f.shortBy)} will not fit before '
          '${formatDate(exam.date)}. Add hours, trim topic sizes or move the date.';
      color = theme.colorScheme.error;
    } else if (!f.fits) {
      title = 'Tight: revision time will be squeezed';
      detail = 'You can finish by ${formatDay(f.finish!)}, but only by using the days '
          'kept for revision.';
      color = Colors.orange.shade800;
    } else {
      title = 'On course to finish by ${formatDay(f.finish!)}';
      detail = 'That is if you study every planned hour. Revision days stay free.';
      color = Colors.green.shade700;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(color: color),
            ),
            const SizedBox(height: 6),
            Text(detail),
            if (!f.done && f.studyDays > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Stat(label: 'Left to study', value: formatHours(f.remaining))),
                  Expanded(
                    child: _Stat(label: 'Needed per study day', value: formatHours(f.needPerDay)),
                  ),
                  Expanded(
                    child: _Stat(label: 'You plan per day', value: formatHours(state.typicalDayHours)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.titleLarge),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _UntaggedCard extends StatelessWidget {
  const _UntaggedCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.help_outline),
        title: const Text('Some sections have no paper'),
        subtitle: const Text('Tell the app which are Paper 1 and which are Paper 2.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => PapersScreen(state: state)),
        ),
      ),
    );
  }
}

class _PaperCard extends StatelessWidget {
  const _PaperCard({required this.stats});

  final PaperStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(paperName(stats.paper), style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: stats.doneFraction,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            Text(
              '${(stats.doneFraction * 100).round()}% done · '
              '${stats.topicsDone} of ${stats.topicsTotal} chapters · '
              '${formatHours(stats.remainingHours)} left',
            ),
            Text(
              '${formatHours(stats.loggedWeek)} studied in the last 7 days',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceNote extends StatelessWidget {
  const _BalanceNote({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final a = state.statsFor(1);
    final b = state.statsFor(2);
    if (a.topicsTotal == 0 || b.topicsTotal == 0) return const SizedBox.shrink();
    final gap = a.doneFraction - b.doneFraction;
    if (gap.abs() < 0.15) return const SizedBox.shrink();
    final behind = gap > 0 ? b : a;
    final ahead = gap > 0 ? a : b;
    return Card(
      color: Colors.orange.withOpacity(0.12),
      child: ListTile(
        leading: Icon(Icons.balance, color: Colors.orange.shade800),
        title: Text('${paperShort(behind.paper)} is behind'),
        subtitle: Text(
          '${(behind.doneFraction * 100).round()}% done against '
          '${(ahead.doneFraction * 100).round()}% for ${paperShort(ahead.paper)}. '
          'Both papers carry the same marks.',
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exam = state.exam!;
    final today = dayOnly(DateTime.now());
    final rows = <Widget>[];
    for (var i = 0; i < 8; i++) {
      final day = DateTime(today.year, today.month, today.day - i);
      final cap = capacityOn(exam, day);
      final total = state.hoursOn(day);
      if (cap <= 0 && total <= 0) {
        rows.add(_DayRow(label: i == 0 ? 'Today' : formatDay(day), value: null, text: 'Rest day'));
        continue;
      }
      final parts = <String>[];
      for (final p in state.papers) {
        final h = state.hoursOn(day, paper: p);
        if (h > 0) parts.add('${paperShort(p)} ${formatHours(h)}');
      }
      final fraction = cap > 0 ? (total / cap) : 1.0;
      rows.add(
        _DayRow(
          label: i == 0 ? 'Today' : formatDay(day),
          value: fraction > 1 ? 1.0 : fraction,
          text: '${formatHours(total)} of ${formatHours(cap)}'
              '${parts.isEmpty ? '' : '  (${parts.join(', ')})'}',
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last 7 days', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.label, required this.value, required this.text});

  final String label;
  final double? value;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label · $text', style: Theme.of(context).textTheme.bodySmall),
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}
