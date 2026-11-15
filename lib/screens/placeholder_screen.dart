import 'package:flutter/material.dart';

/// Stand-in for screens that arrive in later phases.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.phase,
    required this.points,
  });

  final String title;
  final IconData icon;
  final String phase;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Coming in $phase', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final p in points)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(p, textAlign: TextAlign.center),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
