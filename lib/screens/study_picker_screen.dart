import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calc.dart';
import '../models.dart';
import 'study_sheet.dart';

/// "What are you studying?": pick any chapter, in any order.
class StudyPickerScreen extends StatefulWidget {
  const StudyPickerScreen({super.key, required this.state});

  final AppState state;

  @override
  State<StudyPickerScreen> createState() => _StudyPickerScreenState();
}

class _StudyPickerScreenState extends State<StudyPickerScreen> {
  String _query = '';

  bool _matches(Topic t) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return t.name.toLowerCase().contains(q) ||
        widget.state.pathOf(t).toLowerCase().contains(q);
  }

  Widget _tile(Topic t) {
    final state = widget.state;
    final path = state.pathOf(t);
    final logged = state.loggedHoursOf(t);
    final done = isComplete(t.stage);
    return ListTile(
      leading: CircleAvatar(backgroundColor: t.stage.color, radius: 7),
      title: Text(t.name),
      subtitle: Text(
        '${path.isEmpty ? '' : '$path · '}'
        '${formatHours(logged)} of ${formatHours(t.sizeHours)} · ${t.stage.label}',
      ),
      trailing: done ? const Icon(Icons.check_circle, color: Colors.green) : null,
      onTap: () => showStudySheet(context, state, t),
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      appBar: AppBar(title: const Text('What are you studying?')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final searching = _query.isNotEmpty;
          final children = <Widget>[];

          if (!searching) {
            final started = state.inProgress;
            if (started.isNotEmpty) {
              children.add(_header('In progress'));
              children.addAll(started.map(_tile));
            }
          }

          for (final p in state.papers) {
            final list = state.orderedLeaves
                .where((t) => state.paperOf(t) == p)
                .where((t) => searching ? _matches(t) : !isComplete(t.stage))
                .toList();
            if (list.isEmpty) continue;
            children.add(_header(paperName(p)));
            children.addAll(list.map(_tile));
          }

          if (children.isEmpty) {
            children.add(
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  searching
                      ? 'No chapter matches "$_query".'
                      : 'Nothing left to study. Every chapter is done.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search chapters',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              Expanded(child: ListView(children: children)),
            ],
          );
        },
      ),
    );
  }
}
