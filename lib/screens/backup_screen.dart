import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../anki_import.dart';
import '../app_state.dart';
import '../calc.dart';
import '../models.dart';
import 'markup_text.dart';
import 'topic_picker.dart';

/// Save everything to a file, bring it back, or import an Anki deck.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.state});

  final AppState state;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final stamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final target = '${dir.path}/exam_prep_backup_$stamp.db';
      await widget.state.backupTo(target);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(target, mimeType: 'application/octet-stream')],
          subject: 'Exam Prep backup $stamp',
        ),
      );
    } catch (e) {
      _say('Backup failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore a backup?'),
        content: const Text(
          'Everything in the app now (syllabus, hours, cards and reviews) is replaced by the '
          'backup. Make a backup of the current data first if you might need it.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Choose backup')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final dir = await getTemporaryDirectory();
      final tmp = File('${dir.path}/restore_${DateTime.now().millisecondsSinceEpoch}.db');
      await tmp.writeAsBytes(bytes, flush: true);
      await widget.state.restoreFrom(tmp.path);
      _say('Backup restored.');
    } on FormatException catch (e) {
      _say(e.message);
    } catch (e) {
      _say('Restore failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importAnki() async {
    setState(() => _busy = true);
    List<CardDraft> drafts;
    try {
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      drafts = parseAnkiText(utf8.decode(bytes, allowMalformed: true));
    } catch (e) {
      _say('Could not read the file: $e');
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (drafts.isEmpty) {
      _say('No cards found. In Anki, export as "Notes in Plain Text (.txt)".');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AnkiPreview(state: widget.state, drafts: drafts),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Backup and import')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(Icons.backup_outlined),
                    title: const Text('Back up everything'),
                    subtitle: const Text(
                      'Saves one file with your syllabus, hours, cards and review history. '
                      'Send it to Google Drive, email or WhatsApp to keep it safe.',
                    ),
                    onTap: _backup,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.restore),
                    title: const Text('Restore from a backup'),
                    subtitle: const Text('Replaces what is in the app with a backup file.'),
                    onTap: _restore,
                  ),
                ],
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Import cards from Anki'),
                subtitle: const Text(
                  'In Anki: File > Export > "Notes in Plain Text (.txt)". Then choose that file here. '
                  'Cards come in as new, under the topic you choose.',
                ),
                onTap: _importAnki,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'What is in the app: ${state.topics.length} topics, ${state.cards.length} cards, '
              '${formatHours(state.logs.fold(0.0, (s, l) => s + l.hours))} logged.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnkiPreview extends StatefulWidget {
  const _AnkiPreview({required this.state, required this.drafts});

  final AppState state;
  final List<CardDraft> drafts;

  @override
  State<_AnkiPreview> createState() => _AnkiPreviewState();
}

class _AnkiPreviewState extends State<_AnkiPreview> {
  int? _topicId;

  Future<void> _add() async {
    if (_topicId == null) return;
    final n = await widget.state.addCards(_topicId!, widget.drafts);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $n cards')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final drafts = widget.drafts;
    return Scaffold(
      appBar: AppBar(title: Text('${drafts.length} cards from Anki')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TopicField(
            state: widget.state,
            topicId: _topicId,
            onChanged: (id) => setState(() => _topicId = id),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _topicId == null ? null : _add,
            icon: const Icon(Icons.add),
            label: Text('Import ${drafts.length} cards'),
          ),
          const SizedBox(height: 12),
          for (final d in drafts.take(50))
            Card(
              child: ListTile(
                title: MarkupText(d.front, maxLines: 2),
                subtitle: MarkupText(
                  '${d.back}${d.page == null ? '' : '  (p. ${d.page})'}',
                  maxLines: 3,
                ),
              ),
            ),
          if (drafts.length > 50) Text('and ${drafts.length - 50} more'),
        ],
      ),
    );
  }
}
