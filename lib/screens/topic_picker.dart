import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';

/// Full-screen, searchable list of topics, grouped under their section, with
/// the topic name in full. Returns the chosen topic's id.
Future<int?> pickTopic(BuildContext context, AppState state, {int? selected}) {
  return Navigator.of(context).push<int>(
    MaterialPageRoute<int>(
      builder: (_) => _TopicPicker(state: state, selected: selected),
    ),
  );
}

/// A tappable box showing the chosen topic, wrapping long names.
class TopicField extends StatelessWidget {
  const TopicField({super.key, required this.state, required this.topicId, required this.onChanged});

  final AppState state;
  final int? topicId;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = topicId == null ? null : state.topicById(topicId!);
    final path = t == null ? '' : state.pathOf(t);
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final id = await pickTopic(context, state, selected: topicId);
        if (id != null) onChanged(id);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Topic',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: t == null
            ? Text('Tap to choose', style: TextStyle(color: theme.hintColor))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, style: theme.textTheme.titleSmall),
                  if (path.isNotEmpty) Text(path, style: theme.textTheme.bodySmall),
                ],
              ),
      ),
    );
  }
}

class _TopicPicker extends StatefulWidget {
  const _TopicPicker({required this.state, this.selected});

  final AppState state;
  final int? selected;

  @override
  State<_TopicPicker> createState() => _TopicPickerState();
}

class _TopicPickerState extends State<_TopicPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    final q = _query.toLowerCase();
    final children = <Widget>[];
    String? lastGroup;
    for (final t in state.orderedLeaves) {
      final path = state.pathOf(t);
      if (q.isNotEmpty &&
          !t.name.toLowerCase().contains(q) &&
          !path.toLowerCase().contains(q)) {
        continue;
      }
      if (path != lastGroup) {
        lastGroup = path;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              path.isEmpty ? 'Top level' : path,
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
        );
      }
      final count = state.cardsOf(t.id!).length;
      children.add(
        ListTile(
          leading: CircleAvatar(backgroundColor: t.stage.color, radius: 7),
          title: Text(t.name),
          subtitle: count > 0 ? Text('$count cards') : null,
          selected: t.id == widget.selected,
          trailing: t.id == widget.selected ? const Icon(Icons.check) : null,
          onTap: () => Navigator.of(context).pop(t.id),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Choose topic')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              autofocus: false,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search topics',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: children.isEmpty
                ? const Center(child: Text('No topic matches.'))
                : ListView(children: children),
          ),
        ],
      ),
    );
  }
}
