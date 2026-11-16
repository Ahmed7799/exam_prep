import 'package:flutter/material.dart';

import '../app_state.dart';
import '../planner.dart';
import 'reality_check.dart';
import 'study_picker_screen.dart';
import 'cards_screen.dart';
import 'progress_screen.dart';
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

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _realityCheck());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _realityCheck();
  }

  /// Once a day, if you are behind, says so plainly before anything else.
  Future<void> _realityCheck() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final shown = await widget.state.checkShownToday();
      if (shown || !mounted) return;
      final level = widget.state.alert;
      if (level != Alert.warning && level != Alert.alarm) return;
      await widget.state.markCheckShown();
      if (!mounted) return;
      final start = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => RealityCheckDialog(state: widget.state),
      );
      if (start == true && mounted) {
        setState(() => _index = 0);
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => StudyPickerScreen(state: widget.state)),
        );
      }
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          TodayScreen(state: widget.state),
          PlanScreen(state: widget.state),
          SyllabusScreen(state: widget.state),
          CardsScreen(state: widget.state),
          ProgressScreen(state: widget.state),
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
