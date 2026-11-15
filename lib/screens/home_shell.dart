import 'package:flutter/material.dart';

import '../app_state.dart';
import 'placeholder_screen.dart';
import 'plan_screen.dart';
import 'syllabus_screen.dart';
import 'today_screen.dart';

/// Bottom navigation with the five main tabs.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});

  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          TodayScreen(state: widget.state),
          PlanScreen(state: widget.state),
          SyllabusScreen(state: widget.state),
          const PlaceholderScreen(
            title: 'Cards',
            icon: Icons.style,
            phase: 'phase 3',
            points: [
              'Spaced-repetition review with FSRS',
              'Card editor, revision lists and Anki export',
            ],
          ),
          const PlaceholderScreen(
            title: 'Progress',
            icon: Icons.insights,
            phase: 'phase 7',
            points: [
              'Syllabus heatmap and readiness score',
              'Weekly reality report',
            ],
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree),
            label: 'Syllabus',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: 'Cards',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Progress',
          ),
        ],
      ),
    );
  }
}
