import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';

/// Bottom sheet to move a topic to another stage.
Future<void> pickStage(BuildContext context, AppState state, Topic t) async {
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
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (picked != null && picked != t.stage) {
    await state.setStage(t, picked);
  }
}
