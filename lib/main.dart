import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/exam_setup_screen.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.load();
  runApp(ExamPrepApp(state: state));
}

class ExamPrepApp extends StatelessWidget {
  const ExamPrepApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exam Prep',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          if (state.exam == null) return ExamSetupScreen(state: state);
          return HomeShell(state: state);
        },
      ),
    );
  }
}
