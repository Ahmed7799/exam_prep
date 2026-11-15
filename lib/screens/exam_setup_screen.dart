import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calc.dart';
import '../models.dart';

/// First-run exam setup, also used from Syllabus > Exam settings.
class ExamSetupScreen extends StatefulWidget {
  const ExamSetupScreen({super.key, required this.state});

  final AppState state;

  @override
  State<ExamSetupScreen> createState() => _ExamSetupScreenState();
}

class _ExamSetupScreenState extends State<ExamSetupScreen> {
  late final TextEditingController _name;
  DateTime? _date;
  late double _weekday;
  late double _weekend;
  late Set<int> _daysOff;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  bool get _isEdit => widget.state.exam != null;

  @override
  void initState() {
    super.initState();
    final e = widget.state.exam;
    _name = TextEditingController(text: e?.name ?? '');
    _date = e?.date;
    _weekday = e?.weekdayHours ?? 6;
    _weekend = e?.weekendHours ?? 8;
    _daysOff = <int>{...?e?.daysOff};
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final current = _date;
    final initial = (current != null && !current.isBefore(first))
        ? current
        : first.add(const Duration(days: 90));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the exam name and pick its date')),
      );
      return;
    }
    final exam = Exam(
      id: widget.state.exam?.id,
      name: name,
      date: _date!,
      weekdayHours: _weekday,
      weekendHours: _weekend,
      daysOff: _daysOff,
    );
    await widget.state.saveExam(exam);
    if (!mounted) return;
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete exam?'),
        content: const Text(
          'This deletes the exam and its whole syllabus. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.state.deleteExam();
    if (!mounted) return;
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Exam settings' : 'Set up your exam')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Exam name',
              hintText: 'for example EPFO APFC',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event),
            label: Text(_date == null ? 'Pick exam date' : formatDate(_date!)),
          ),
          const SizedBox(height: 24),
          Text('Study hours on weekdays: ${formatHours(_weekday)}'),
          Slider(
            value: _weekday,
            min: 0,
            max: 14,
            divisions: 28,
            onChanged: (v) => setState(() => _weekday = v),
          ),
          Text('Study hours on weekends: ${formatHours(_weekend)}'),
          Slider(
            value: _weekend,
            min: 0,
            max: 14,
            divisions: 28,
            onChanged: (v) => setState(() => _weekend = v),
          ),
          const SizedBox(height: 8),
          const Text('Rest days (no study planned)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < 7; i++)
                FilterChip(
                  label: Text(_dayNames[i]),
                  selected: _daysOff.contains(i + 1),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _daysOff.add(i + 1);
                    } else {
                      _daysOff.remove(i + 1);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: Text(_isEdit ? 'Save changes' : 'Start'),
          ),
          if (_isEdit) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: _delete,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete exam and syllabus'),
            ),
          ],
        ],
      ),
    );
  }
}
