import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calc.dart';
import '../models.dart';

String formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Big study clock for the chapter you are on. The time is kept even if you
/// close the app; stop it to log the time to the chapter.
class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key, required this.state});

  final AppState state;

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _stop() async {
    final state = widget.state;
    final mins = (state.timerElapsed.inSeconds / 60).round();
    final topic = state.timerTopicId == null ? null : state.topicById(state.timerTopicId!);
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop the timer?'),
        content: Text(
          mins < 1
              ? 'Less than a minute, so there is nothing to log.'
              : 'Log $mins minutes to ${topic?.name ?? 'this chapter'}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep going')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: const Text('Discard')),
          if (mins >= 1)
            FilledButton(onPressed: () => Navigator.pop(ctx, 'log'), child: const Text('Log it')),
        ],
      ),
    );
    if (choice == null) return;
    final hours = await state.stopTimer(log: choice == 'log');
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (hours > 0) {
      messenger.showSnackBar(SnackBar(content: Text('Logged ${formatHours(hours)}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final topic = state.timerTopicId == null ? null : state.topicById(state.timerTopicId!);
        if (topic == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Study timer')),
            body: const Center(child: Text('No timer running. Start one from a chapter.')),
          );
        }
        final running = state.timerRunning;
        final today = state.hoursOn(DateTime.now()) + state.timerElapsed.inSeconds / 3600;
        final target = state.todayTarget;
        return Scaffold(
          appBar: AppBar(title: const Text('Study timer')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(topic.name, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                  Text(
                    '${paperShort(state.paperOf(topic))} · ${state.pathOf(topic)}',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  Text(
                    formatClock(state.timerElapsed),
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: running ? theme.colorScheme.primary : theme.disabledColor,
                    ),
                  ),
                  Text(running ? 'Studying' : 'Paused'),
                  const SizedBox(height: 16),
                  if (target > 0)
                    Text(
                      'Today with this session: ${formatHours(today)} of ${formatHours(target)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: running ? state.pauseTimer : state.resumeTimer,
                            icon: Icon(running ? Icons.pause : Icons.play_arrow),
                            label: Text(running ? 'Pause' : 'Resume'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: FilledButton.icon(
                            onPressed: _stop,
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Small strip showing a running timer, for the Today tab.
class TimerStrip extends StatefulWidget {
  const TimerStrip({super.key, required this.state});

  final AppState state;

  @override
  State<TimerStrip> createState() => _TimerStripState();
}

class _TimerStripState extends State<TimerStrip> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.state.timerActive) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final topic = state.timerTopicId == null ? null : state.topicById(state.timerTopicId!);
    if (topic == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: ListTile(
        leading: Icon(state.timerRunning ? Icons.timer : Icons.pause_circle_outline),
        title: Text(topic.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${state.timerRunning ? 'Studying' : 'Paused'} · ${formatClock(state.timerElapsed)}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => TimerScreen(state: state)),
        ),
      ),
    );
  }
}
