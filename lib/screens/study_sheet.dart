import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calc.dart';
import '../models.dart';
import 'library_screen.dart';
import 'pdf_reader_screen.dart';

/// Bottom sheet for one chapter: log time studied today and set its stage.
Future<void> showStudySheet(BuildContext context, AppState state, Topic topic) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _StudySheet(state: state, topicId: topic.id!),
  );
}

class _StudySheet extends StatelessWidget {
  const _StudySheet({required this.state, required this.topicId});

  final AppState state;
  final int topicId;

  Future<void> _custom(BuildContext context, Topic t) async {
    final controller = TextEditingController();
    final hours = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hours studied'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'For example 1.25'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim().replaceAll(',', '.'));
              Navigator.pop(ctx, (v != null && v > 0 && v <= 24) ? v : null);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (hours != null) await state.logStudy(t, hours);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final t = state.topicById(topicId);
        if (t == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final path = state.pathOf(t);
        final logged = state.loggedHoursOf(t);
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name, style: theme.textTheme.titleLarge),
                if (path.isNotEmpty) Text(path, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  '${paperShort(state.paperOf(t))} · ${formatHours(logged)} logged of '
                  '${formatHours(t.sizeHours)} · ${formatHours(state.remainingOf(t))} left',
                ),
                const SizedBox(height: 12),
                _ReadButton(state: state, topic: t),
                const SizedBox(height: 16),
                Text('Log time studied today', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final h in const [0.5, 1.0, 1.5, 2.0])
                      ActionChip(
                        label: Text('+${formatHours(h)}'),
                        onPressed: () => state.logStudy(t, h),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.edit, size: 16),
                      label: const Text('Other'),
                      onPressed: () => _custom(context, t),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Stage', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in Stage.values)
                      ChoiceChip(
                        avatar: CircleAvatar(backgroundColor: s.color, radius: 6),
                        label: Text(s.label),
                        selected: t.stage == s,
                        onSelected: (_) => state.setStage(t, s),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await state.setStage(t, Stage.done);
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Mark chapter done'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReadButton extends StatelessWidget {
  const _ReadButton({required this.state, required this.topic});

  final AppState state;
  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final source = state.sourceById(topic.sourceId);
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () {
              final nav = Navigator.of(context);
              nav.pop();
              nav.push(
                MaterialPageRoute<void>(
                  builder: (_) => source == null
                      ? LibraryScreen(state: state, pickForTopic: topic)
                      : PdfReaderScreen(
                          state: state,
                          source: source,
                          topic: topic,
                          initialPage: topic.sourcePage,
                        ),
                ),
              );
            },
            icon: const Icon(Icons.chrome_reader_mode_outlined),
            label: Text(
              source == null ? 'Read from a PDF' : 'Continue reading: ${source.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (source != null)
          IconButton(
            tooltip: 'Use a different PDF',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () {
              final nav = Navigator.of(context);
              nav.pop();
              nav.push(
                MaterialPageRoute<void>(
                  builder: (_) => LibraryScreen(state: state, pickForTopic: topic),
                ),
              );
            },
          ),
      ],
    );
  }
}
