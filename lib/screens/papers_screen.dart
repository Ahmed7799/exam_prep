import 'package:flutter/material.dart';

import '../app_state.dart';

/// Assign each top-level section of the syllabus to Paper 1 or Paper 2.
class PapersScreen extends StatelessWidget {
  const PapersScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign papers')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final sections = state.sections;
          if (sections.isEmpty) {
            return const Center(child: Text('Add your syllabus first.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Paper 1 is General Studies and Paper 2 is the core subject. '
                'Everything inside a section follows the section\'s paper.',
              ),
              const SizedBox(height: 12),
              for (final s in sections)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name, style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment<int>(value: 1, label: Text('Paper 1')),
                            ButtonSegment<int>(value: 2, label: Text('Paper 2')),
                          ],
                          selected: s.paper == 1 || s.paper == 2 ? {s.paper} : <int>{},
                          emptySelectionAllowed: true,
                          showSelectedIcon: false,
                          onSelectionChanged: (sel) =>
                              state.setPaper(s, sel.isEmpty ? 0 : sel.first),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
