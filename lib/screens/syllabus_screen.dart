import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calc.dart';
import '../models.dart';
import '../parser.dart';
import 'exam_setup_screen.dart';
import 'paste_claude_screen.dart';

/// The topic tree. Tap a topic's stage to move it along your pipeline.
class SyllabusScreen extends StatefulWidget {
  const SyllabusScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SyllabusScreen> createState() => _SyllabusScreenState();
}

class _Row {
  const _Row(this.topic, this.depth);
  final Topic topic;
  final int depth;
}

class _SyllabusScreenState extends State<SyllabusScreen> {
  final Set<int> _collapsed = <int>{};

  void _walk(int? parentId, int depth, List<_Row> out) {
    for (final t in widget.state.childrenOf(parentId)) {
      out.add(_Row(t, depth));
      if (!_collapsed.contains(t.id)) _walk(t.id, depth + 1, out);
    }
  }

  Future<void> _pickStage(Topic t) async {
    final picked = await showModalBottomSheet<Stage>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                t.name,
                style: Theme.of(ctx).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (final s in Stage.values)
              ListTile(
                leading: CircleAvatar(backgroundColor: s.color, radius: 8),
                title: Text(s.label),
                trailing: s == t.stage ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, s),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'Once flashcards arrive, Done will be set from your card progress.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null && picked != t.stage) {
      await widget.state.setStage(t, picked);
    }
  }

  Future<void> _editTopic({Topic? existing, int? parentId}) async {
    final result = await showDialog<_TopicInput>(
      context: context,
      builder: (_) => _TopicDialog(
        title: existing == null
            ? (parentId == null ? 'Add topic' : 'Add subtopic')
            : 'Edit topic',
        existing: existing,
      ),
    );
    if (result == null) return;
    if (existing == null) {
      await widget.state.addTopic(
        parentId: parentId,
        name: result.name,
        sizeHours: result.sizeHours,
        difficulty: result.difficulty,
        importance: result.importance,
      );
      if (!mounted) return;
      if (parentId != null) setState(() => _collapsed.remove(parentId));
    } else {
      await widget.state.updateTopic(existing.copyWith(
        name: result.name,
        sizeHours: result.sizeHours,
        difficulty: result.difficulty,
        importance: result.importance,
      ));
    }
  }

  Future<void> _confirmDelete(Topic t) async {
    final extra = widget.state.descendantCount(t);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete topic?'),
        content: Text(
          extra == 0
              ? '"${t.name}" will be deleted.'
              : '"${t.name}" and its $extra subtopics will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await widget.state.deleteTopic(t);
  }

  Future<void> _importFromClaude() async {
    final n = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => ClaudeImportScreen(state: widget.state),
      ),
    );
    if (!mounted || n == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $n topics')),
    );
  }

  Future<void> _importDialog() async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );
    if (text == null || text.trim().isEmpty) return;
    final n = await widget.state.importText(text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $n topics')),
    );
  }

  Widget _tile(BuildContext context, Topic t, int depth) {
    final state = widget.state;
    final theme = Theme.of(context);
    final isParent = state.hasChildren(t);
    final collapsed = _collapsed.contains(t.id);

    void toggle() => setState(() {
          if (collapsed) {
            _collapsed.remove(t.id);
          } else {
            _collapsed.add(t.id!);
          }
        });

    Widget subtitle;
    if (isParent) {
      final p = state.progressOf(t);
      subtitle = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${p.$1} of ${p.$2} topics complete', style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: p.$2 == 0 ? 0 : p.$1 / p.$2, minHeight: 4),
        ],
      );
    } else {
      subtitle = Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            _StageChip(stage: t.stage, onTap: () => _pickStage(t)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${formatHours(t.sizeHours)} · ${difficultyLabel(t.difficulty)}',
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.only(left: 8.0 + depth * 18, right: 4),
      leading: isParent
          ? IconButton(
              icon: Icon(collapsed ? Icons.chevron_right : Icons.expand_more),
              onPressed: toggle,
            )
          : const SizedBox(width: 48),
      title: Text(
        t.name,
        style: isParent ? const TextStyle(fontWeight: FontWeight.w600) : null,
      ),
      subtitle: subtitle,
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          switch (v) {
            case 'add':
              _editTopic(parentId: t.id);
            case 'edit':
              _editTopic(existing: t);
            case 'delete':
              _confirmDelete(t);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'add', child: Text('Add subtopic')),
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
      onTap: isParent ? toggle : () => _pickStage(t),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text('No topics yet', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              'Break your syllabus PDF down in the Claude app and import the result, or paste it as text, or add topics one by one.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _importFromClaude,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Import from Claude'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _importDialog,
              icon: const Icon(Icons.playlist_add),
              label: const Text('Paste syllabus text'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final state = widget.state;
        final rows = <_Row>[];
        _walk(null, 0, rows);
        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Syllabus'),
            actions: [
              IconButton(
                tooltip: 'Import from Claude',
                icon: const Icon(Icons.auto_awesome),
                onPressed: _importFromClaude,
              ),
              IconButton(
                tooltip: 'Paste syllabus',
                icon: const Icon(Icons.playlist_add),
                onPressed: _importDialog,
              ),
              IconButton(
                tooltip: 'Exam settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ExamSetupScreen(state: state),
                  ),
                ),
              ),
            ],
          ),
          body: state.topics.isEmpty
              ? _empty(context)
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: rows.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${(state.doneFraction * 100).round()}% complete · '
                              '${state.leaves.length} topics',
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: state.doneFraction,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ],
                        ),
                      );
                    }
                    final row = rows[i - 1];
                    return _tile(context, row.topic, row.depth);
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _editTopic(),
            icon: const Icon(Icons.add),
            label: const Text('Add topic'),
          ),
        );
      },
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.stage, required this.onTap});

  final Stage stage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: stage.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: stage.color),
        ),
        child: Text(
          stage.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: stage.color,
          ),
        ),
      ),
    );
  }
}

class _TopicInput {
  const _TopicInput(this.name, this.sizeHours, this.difficulty, this.importance);
  final String name;
  final double sizeHours;
  final int difficulty;
  final int importance;
}

class _TopicDialog extends StatefulWidget {
  const _TopicDialog({required this.title, this.existing});

  final String title;
  final Topic? existing;

  @override
  State<_TopicDialog> createState() => _TopicDialogState();
}

class _TopicDialogState extends State<_TopicDialog> {
  late final TextEditingController _name;
  late final TextEditingController _size;
  late int _difficulty;
  late double _importance;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _name = TextEditingController(text: t?.name ?? '');
    _size = TextEditingController(
      text: t == null ? '1' : t.sizeHours.toString().replaceAll(RegExp(r'\.0$'), ''),
    );
    _difficulty = t?.difficulty ?? 2;
    _importance = (t?.importance ?? 0).toDouble();
  }

  @override
  void dispose() {
    _name.dispose();
    _size.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final parsed = double.tryParse(_size.text.trim().replaceAll(',', '.')) ?? 1;
    Navigator.pop(
      context,
      _TopicInput(name, parsed.clamp(0, 200).toDouble(), _difficulty, _importance.round()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Topic name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _size,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Study time estimate (hours)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Difficulty'),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(value: 1, label: Text('Easy')),
                ButtonSegment<int>(value: 2, label: Text('Medium')),
                ButtonSegment<int>(value: 3, label: Text('Hard')),
              ],
              selected: {_difficulty},
              onSelectionChanged: (s) => setState(() => _difficulty = s.first),
            ),
            const SizedBox(height: 16),
            Text('Importance: ${_importance.round()} of 5'),
            Slider(
              value: _importance,
              min: 0,
              max: 5,
              divisions: 5,
              onChanged: (v) => setState(() => _importance = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final TextEditingController _text = TextEditingController();
  int _count = 0;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paste syllabus'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'One topic per line. Indent a line to make it a subtopic of the line above.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              minLines: 8,
              maxLines: 12,
              onChanged: (v) => setState(() => _count = parseSyllabusText(v).length),
              decoration: const InputDecoration(
                hintText: 'Polity\n  Preamble\n  Fundamental Rights\nEconomy\n  Inflation',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text('$_count topics found'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _count == 0 ? null : () => Navigator.pop(context, _text.text),
          child: const Text('Add topics'),
        ),
      ],
    );
  }
}
