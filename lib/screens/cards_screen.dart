import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../export.dart';
import '../models.dart';
import 'card_editor_screen.dart';
import 'card_list_screen.dart';
import 'cards_import_screen.dart';
import 'library_screen.dart';
import 'review_screen.dart';

/// Cards tab: review, revision lists, cards by topic, import and export.
class CardsScreen extends StatelessWidget {
  const CardsScreen({super.key, required this.state});

  final AppState state;

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _export(BuildContext context, {required bool anki}) async {
    if (state.cards.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final text = anki
        ? ankiText(state.cards, topicPath: state.topicPathFor)
        : progressCsv(state.cards, topicPath: state.topicPathFor);
    final name = anki ? 'exam_prep_cards_anki.txt' : 'exam_prep_cards_progress.csv';
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsString(text);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: anki ? 'text/plain' : 'text/csv')],
          subject: name,
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not share the file, so it was copied to the clipboard.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final theme = Theme.of(context);
        final queue = state.reviewQueue;
        final due = state.dueCards.length;
        final fresh = state.newCards.length;
        final topics = state.orderedLeaves.where((t) => state.cardsOf(t.id!).isNotEmpty).toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Cards'),
            actions: [
              IconButton(
                tooltip: 'PDFs',
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed: () => _open(context, LibraryScreen(state: state)),
              ),
              IconButton(
                tooltip: 'Cards from Claude',
                icon: const Icon(Icons.auto_awesome),
                onPressed: () => _open(context, CardsImportScreen(state: state)),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'all') _open(context, CardListScreen(state: state));
                  if (v == 'anki') _export(context, anki: true);
                  if (v == 'csv') _export(context, anki: false);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'all', child: Text('Browse all cards')),
                  PopupMenuItem(value: 'anki', child: Text('Export for Anki')),
                  PopupMenuItem(value: 'csv', child: Text('Export with progress (CSV)')),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _open(context, CardEditorScreen(state: state)),
            icon: const Icon(Icons.add),
            label: const Text('Card'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _Count(label: 'Due', value: due)),
                          Expanded(child: _Count(label: 'New', value: fresh)),
                          Expanded(child: _Count(label: 'Reviewed today', value: state.reviewsToday)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: queue.isEmpty
                              ? null
                              : () => _open(
                                    context,
                                    ReviewScreen(state: state, cards: queue, title: 'Review'),
                                  ),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                            queue.isEmpty ? 'Nothing due' : 'Review ${queue.length} cards',
                          ),
                        ),
                      ),
                      if (fresh > AppState.newPerSession)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Up to ${AppState.newPerSession} new cards come in per session.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Text('Revision lists', style: theme.textTheme.titleMedium),
                    ),
                    for (final f in cardFlags)
                      ListTile(
                        leading: CircleAvatar(backgroundColor: flagColor(f), radius: 8),
                        title: Text(flagLabel(f)),
                        trailing: Text('${state.cardsWithFlag(f).length}'),
                        onTap: () => _open(context, CardListScreen(state: state, flag: f)),
                      ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        'Tag cards while reviewing. Revising a list does not change their schedule.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              if (state.cards.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('No cards yet', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        const Text(
                          'Make cards with Claude from a page range of your PDF, '
                          'or write them yourself with the Card button.',
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => _open(context, CardsImportScreen(state: state)),
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Cards from Claude'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Text('By topic', style: theme.textTheme.titleMedium),
                      ),
                      for (final t in topics)
                        ListTile(
                          title: Text(t.name),
                          subtitle: Text(
                            '${paperShort(state.paperOf(t))} · ${state.pathOf(t)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text('${state.cardsOf(t.id!).length}'),
                          onTap: () => _open(context, CardListScreen(state: state, topicId: t.id)),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value', style: theme.textTheme.headlineSmall),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
