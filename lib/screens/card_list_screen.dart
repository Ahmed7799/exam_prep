import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calc.dart';
import '../markup.dart';
import '../models.dart';
import 'card_editor_screen.dart';
import 'markup_text.dart';
import 'review_screen.dart';

/// Cards of one topic, one revision list, or all of them, with search.
class CardListScreen extends StatefulWidget {
  const CardListScreen({super.key, required this.state, this.topicId, this.flag});

  final AppState state;
  final int? topicId;
  final int? flag;

  @override
  State<CardListScreen> createState() => _CardListScreenState();
}

class _CardListScreenState extends State<CardListScreen> {
  String _query = '';

  String get _title {
    if (widget.flag != null) return flagLabel(widget.flag!);
    if (widget.topicId != null) return widget.state.topicById(widget.topicId!)?.name ?? 'Cards';
    return 'All cards';
  }

  String _dueText(Flashcard c) {
    if (c.isNew) return 'New';
    if (!c.due.isAfter(DateTime.now())) return 'Due now';
    return 'Due ${formatDay(c.due)}';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        var list = state.cards;
        if (widget.topicId != null) list = list.where((c) => c.topicId == widget.topicId).toList();
        if (widget.flag != null) list = list.where((c) => c.flag == widget.flag).toList();
        final all = list;
        if (_query.isNotEmpty) {
          final q = _query.toLowerCase();
          list = list
              .where((c) =>
                  plainText(c.front).toLowerCase().contains(q) ||
                  plainText(c.back).toLowerCase().contains(q))
              .toList();
        }
        return Scaffold(
          appBar: AppBar(title: Text('$_title (${all.length})')),
          floatingActionButton: widget.flag == null
              ? FloatingActionButton(
                  tooltip: 'New card',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CardEditorScreen(state: state, topicId: widget.topicId),
                    ),
                  ),
                  child: const Icon(Icons.add),
                )
              : null,
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search cards',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              if (all.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ReviewScreen(
                            state: state,
                            cards: list,
                            title: 'Revise: $_title',
                            scheduled: false,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.replay),
                      label: Text('Revise these ${list.length} cards'),
                    ),
                  ),
                ),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            all.isEmpty ? 'No cards here yet.' : 'No card matches "$_query".',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final c = list[i];
                          return ListTile(
                            leading: c.flag == 0
                                ? null
                                : CircleAvatar(backgroundColor: flagColor(c.flag), radius: 6),
                            title: MarkupText(c.front, maxLines: 2),
                            subtitle: Text(
                              [
                                if (widget.topicId == null) state.topicById(c.topicId)?.name ?? '',
                                if (c.page != null) 'p. ${c.page}',
                                _dueText(c),
                              ].where((s) => s.isNotEmpty).join(' · '),
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => CardEditorScreen(state: state, card: c),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
