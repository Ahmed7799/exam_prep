import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'pdf_reader_screen.dart';

/// Your PDFs. Picking one with [pickForTopic] set opens it for that topic.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.state, this.pickForTopic});

  final AppState state;
  final Topic? pickForTopic;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _adding = false;

  Future<void> _add() async {
    setState(() => _adding = true);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final source = await widget.state.addSource(file.name, bytes);
      if (!mounted || source == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${source.title}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add the PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  void _open(Source s) {
    final topic = widget.pickForTopic;
    final page = (topic != null && topic.sourceId == s.id) ? topic.sourcePage : null;
    Navigator.of(context).pushReplacementOrPush(
      replace: topic != null,
      route: MaterialPageRoute<void>(
        builder: (_) => PdfReaderScreen(
          state: widget.state,
          source: s,
          topic: topic,
          initialPage: page,
        ),
      ),
    );
  }

  Future<void> _rename(Source s) async {
    final controller = TextEditingController(text: s.title);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) await widget.state.updateSource(s.copyWith(title: name));
  }

  Future<void> _delete(Source s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${s.title}?'),
        content: const Text(
          'The PDF is removed from the app. Your cards stay, but their page links to this PDF stop working.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) await widget.state.deleteSource(s);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final topic = widget.pickForTopic;
    return Scaffold(
      appBar: AppBar(title: Text(topic == null ? 'PDFs' : 'Read: ${topic.name}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adding ? null : _add,
        icon: _adding
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add),
        label: const Text('Add PDF'),
      ),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          if (state.sources.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Add the PDFs you study from. They are copied into the app, '
                  'so they open even if you move the original file.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              if (topic != null)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('Which PDF do you read this chapter from?'),
                ),
              for (final s in state.sources)
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: Text(s.title),
                  subtitle: Text(
                    'Last on page ${s.printedPage(s.lastPage)}'
                    '${s.pageOffset == 0 ? '' : ' (PDF page ${s.lastPage})'}',
                  ),
                  onTap: () => _open(s),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'rename') _rename(s);
                      if (v == 'delete') _delete(s);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Remove')),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

extension on NavigatorState {
  void pushReplacementOrPush({required bool replace, required Route<void> route}) {
    if (replace) {
      pushReplacement(route);
    } else {
      push(route);
    }
  }
}
