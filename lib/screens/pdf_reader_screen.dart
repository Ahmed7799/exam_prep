import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../app_state.dart';
import '../calc.dart';
import '../models.dart';
import 'cards_import_screen.dart';

/// Reads a PDF inside the app. Mark a From and a To page, then make cards
/// from that range with Claude. Time spent reading can be logged to the topic.
class PdfReaderScreen extends StatefulWidget {
  const PdfReaderScreen({
    super.key,
    required this.state,
    required this.source,
    this.topic,
    this.initialPage,
    this.printedPage,
  });

  final AppState state;
  final Source source;
  final Topic? topic;

  /// PDF page index to open at.
  final int? initialPage;

  /// Printed page number to open at (used from a card's page link).
  final int? printedPage;

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  final _controller = PdfViewerController();
  late Source _source = widget.source;
  late int? _topicId = widget.topic?.id ?? widget.source.lastTopicId;
  PdfDocument? _doc;
  int _page = 1;
  int? _from;
  int? _to;
  bool _extracting = false;
  final DateTime _opened = DateTime.now();
  Timer? _tick;
  bool _leaving = false;

  int get _startPage {
    final printed = widget.printedPage;
    if (printed != null) return _source.pdfPage(printed);
    return widget.initialPage ?? _source.lastPage;
  }

  @override
  void initState() {
    super.initState();
    _page = _startPage < 1 ? 1 : _startPage;
    // Refresh the reading timer shown in the app bar.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Topic? get _topic => _topicId == null ? null : widget.state.topicById(_topicId!);

  int get _minutes => DateTime.now().difference(_opened).inMinutes;

  int get _pageCount => _doc?.pages.length ?? 0;

  String _pageLabel(int pdfPage) {
    final printed = _source.printedPage(pdfPage);
    return _source.pageOffset == 0 ? 'p. $pdfPage' : 'p. $printed (PDF $pdfPage)';
  }

  Future<void> _savePosition() async {
    await widget.state.saveReadingPosition(_source, _page, topic: _topic);
  }

  /// Offers to log reading time to the topic, then leaves.
  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    await _savePosition();
    final topic = _topic;
    final mins = _minutes;
    if (topic != null && mins >= 5 && mounted) {
      final hours = (mins / 60 * 4).round() / 4; // to the nearest quarter hour
      final log = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Log reading time?'),
          content: Text('You read for $mins minutes. Add ${formatHours(hours < 0.25 ? 0.25 : hours)} '
              'to ${topic.name}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log it')),
          ],
        ),
      );
      if (log == true) await widget.state.logStudy(topic, hours < 0.25 ? 0.25 : hours);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _goTo() async {
    final controller = TextEditingController();
    final printed = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Go to page'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Printed page number'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text.trim())),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    if (printed == null) return;
    var target = _source.pdfPage(printed);
    if (target < 1) target = 1;
    if (_pageCount > 0 && target > _pageCount) target = _pageCount;
    if (_controller.isReady) await _controller.goToPage(pageNumber: target);
  }

  Future<void> _setPrinted() async {
    final controller = TextEditingController(text: '${_source.printedPage(_page)}');
    final printed = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Printed page number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What number is printed on this page (PDF page $_page)? '
                'Cards and page jumps will use the printed numbers.'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (printed == null) return;
    final updated = _source.copyWith(pageOffset: _page - printed);
    await widget.state.updateSource(updated);
    setState(() => _source = updated);
  }

  Future<void> _chooseTopic() async {
    final leaves = widget.state.orderedLeaves;
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Which topic are you reading?'),
            ),
            for (final t in leaves)
              ListTile(
                title: Text(t.name),
                subtitle: Text(
                  '${paperShort(widget.state.paperOf(t))} · ${widget.state.pathOf(t)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: t.id == _topicId,
                onTap: () => Navigator.pop(ctx, t.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _topicId = picked);
  }

  /// Reads the text of the marked pages, labelled with printed page numbers.
  Future<String?> _rangeText(int from, int to) async {
    final doc = _doc;
    if (doc == null) return null;
    final b = StringBuffer();
    for (var i = from; i <= to && i <= doc.pages.length; i++) {
      final text = await doc.pages[i - 1].loadStructuredText(ensureLoaded: true);
      b
        ..writeln('--- Page ${_source.printedPage(i)} ---')
        ..writeln(text.fullText.trim())
        ..writeln();
    }
    return b.toString();
  }

  Future<void> _makeCards() async {
    final from = _from;
    final to = _to ?? _from;
    if (from == null || to == null) return;
    final a = from <= to ? from : to;
    final b = from <= to ? to : from;
    if (b - a + 1 > 40) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at most 40 pages at a time.')),
      );
      return;
    }
    setState(() => _extracting = true);
    String? text;
    try {
      text = await _rangeText(a, b);
    } catch (_) {
      text = null;
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
    if (!mounted) return;
    final hasText = text != null && text.replaceAll(RegExp(r'--- Page -?\d+ ---|\s'), '').length > 50;
    await _savePosition();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CardsImportScreen(
          state: widget.state,
          topicId: _topicId,
          fromPage: _source.printedPage(a),
          toPage: _source.printedPage(b),
          pageText: hasText ? text : null,
          sourceId: _source.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topic = _topic;
    final file = File(_source.filePath);
    final rangeText = _from == null
        ? 'Mark the first page'
        : (_to == null
            ? 'From ${_pageLabel(_from!)}'
            : '${_pageLabel(_from! <= _to! ? _from! : _to!)} to ${_pageLabel(_from! <= _to! ? _to! : _from!)}');
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _leave),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_source.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                '${_pageLabel(_page)}${_pageCount > 0 ? ' of $_pageCount' : ''} · $_minutes min',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            IconButton(tooltip: 'Go to page', icon: const Icon(Icons.find_in_page_outlined), onPressed: _goTo),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'printed') _setPrinted();
                if (v == 'topic') _chooseTopic();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'printed', child: Text('Set printed page number')),
                PopupMenuItem(value: 'topic', child: Text('Change topic')),
              ],
            ),
          ],
        ),
        body: !file.existsSync()
            ? const Center(child: Text('This PDF file is missing. Remove it and add it again.'))
            : PdfViewer.file(
                _source.filePath,
                controller: _controller,
                initialPageNumber: _page,
                params: PdfViewerParams(
                  onViewerReady: (doc, controller) {
                    if (mounted) setState(() => _doc = doc);
                  },
                  onPageChanged: (page) {
                    if (page != null && mounted) setState(() => _page = page);
                  },
                ),
              ),
        bottomNavigationBar: SafeArea(
          child: Material(
            elevation: 8,
            color: theme.colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _chooseTopic,
                    child: Row(
                      children: [
                        const Icon(Icons.bookmark_outline, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            topic == null ? 'Choose the topic you are reading' : topic.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: topic == null ? theme.colorScheme.error : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(rangeText, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => setState(() {
                          _from = _page;
                          if (_to != null && _to! < _page) _to = null;
                        }),
                        child: const Text('From here'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _from == null ? null : () => setState(() => _to = _page),
                        child: const Text('To here'),
                      ),
                      const Spacer(),
                      if (_from != null)
                        IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _from = null;
                            _to = null;
                          }),
                        ),
                      FilledButton.icon(
                        onPressed: (_from == null || topic == null || _extracting) ? null : _makeCards,
                        icon: _extracting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Cards'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
