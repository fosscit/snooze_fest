import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snooze_fest/widgets/calculator_keypad.dart';
import 'package:expressions/expressions.dart';
import 'package:snooze_fest/helpers/alarm_provider.dart';
import 'package:intl/intl.dart';
import '../app.dart'; // Import CustomAlarm and AlarmRecurrence
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:math'; // Added for random number generation

class EquationDiffuseDialog extends ConsumerStatefulWidget {
  final AlarmSettings alarm;
  final List tasks;
  final VoidCallback? onDismissed;
  const EquationDiffuseDialog({
    super.key,
    required this.alarm,
    required this.tasks,
    this.onDismissed,
  });

  @override
  ConsumerState<EquationDiffuseDialog> createState() =>
      _EquationDiffuseDialogState();
}

class _EquationDiffuseDialogState extends ConsumerState<EquationDiffuseDialog> {
  int _currentTaskIndex = 0;
  String _input = '';
  String _error = '';
  String _formula = '(A+B)';
  bool _justEvaluated = false;

  // --- Store generated questions/answers to avoid re-randomizing on rebuild ---
  final Map<int, dynamic> _taskCache = {};
  bool _showMemoryInput = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alarmNotifier = ref.read(alarmListProvider.notifier);
    final mq = MediaQuery.of(context);
    final tasks = widget.tasks;
    if (_currentTaskIndex >= tasks.length) {
      // All tasks solved
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Alarm Diffused!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await alarmNotifier.stopAlarm(widget.alarm.id);
                  widget.onDismissed?.call();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ),
      );
    }
    final currentTask = tasks[_currentTaskIndex];
    // --- Task Logic ---
    if (currentTask.type == AlarmTaskType.timeBased) {
      final formula = currentTask.settings['formula'] ?? '';
      final now = DateTime.now();
      final timeStr = DateFormat('HH:mm').format(now);
      final a = int.parse(timeStr[0]);
      final b = int.parse(timeStr[1]);
      final c = int.parse(timeStr[3]);
      final d = int.parse(timeStr[4]);
      final expected = _evaluateFormula(formula, a, b, c, d);
      return _buildTimeBasedTask(formula, timeStr, expected);
    }
    if (currentTask.type == AlarmTaskType.math) {
      final difficulty = currentTask.settings['difficulty'] ?? 'easy';
      if (!_taskCache.containsKey(_currentTaskIndex)) {
        _taskCache[_currentTaskIndex] = _generateRandomMath(difficulty);
      }
      final math = _taskCache[_currentTaskIndex];
      return _buildMathTask(math['question'], math['answer']);
    }
    if (currentTask.type == AlarmTaskType.retype) {
      if (!_taskCache.containsKey(_currentTaskIndex)) {
        _taskCache[_currentTaskIndex] = _generateRandomPhrase();
      }
      final phrase = _taskCache[_currentTaskIndex];
      return _buildRetypeTask(phrase);
    }
    if (currentTask.type == AlarmTaskType.sequence) {
      if (!_taskCache.containsKey(_currentTaskIndex)) {
        _taskCache[_currentTaskIndex] = _generateRandomSequence();
      }
      final sequence = _taskCache[_currentTaskIndex];
      return _buildSequenceTask(sequence);
    }
    if (currentTask.type == AlarmTaskType.memory) {
      if (!_taskCache.containsKey(_currentTaskIndex)) {
        _taskCache[_currentTaskIndex] = _generateRandomMemory();
      }
      final memory = _taskCache[_currentTaskIndex];
      return _buildMemoryTask(memory);
    }
    // Fallback for unknown types
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Task ${_currentTaskIndex + 1} of ${tasks.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Task type: ${currentTask.type} (not implemented)'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() => _currentTaskIndex++);
              },
              child: const Text('Mark as Solved'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Task Widgets ---
  Widget _buildTimeBasedTask(String formula, String timeStr, int? expected) {
    // Use calculator keypad layout for time-based questions
    final alarmNotifier = ref.read(alarmListProvider.notifier);
    return Dialog(
      insetPadding: const EdgeInsets.all(8),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.98,
        height: MediaQuery.of(context).size.height * 0.92,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Task ${_currentTaskIndex + 1} of ${widget.tasks.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Time-based Formula',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current time: $timeStr',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _input.isEmpty ? 'Enter answer' : _input,
                      style: const TextStyle(fontSize: 24, letterSpacing: 2),
                    ),
                  ),
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _error,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: CalculatorKeypad(
                      onKey: (val) {
                        setState(() {
                          if (val == 'C') {
                            _input = '';
                          } else if (val == '<') {
                            if (_input.isNotEmpty) {
                              _input = _input.substring(0, _input.length - 1);
                            }
                          } else if (val == '=') {
                            if (_input.isEmpty) return;
                            try {
                              final expression = Expression.parse(_input);
                              final evaluator = const ExpressionEvaluator();
                              final result = evaluator.eval(expression, {});
                              if (result is num) {
                                _checkPassword(
                                  result.toInt().toString(),
                                  expected,
                                );
                                _input = result.toString();
                              } else {
                                _error = 'Invalid calculation!';
                              }
                            } catch (_) {
                              _error = 'Invalid calculation!';
                            }
                          } else {
                            _input += val;
                          }
                          if (_error.isNotEmpty && val != '=') _error = '';
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Formula: $formula',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A = hour tens, B = hour units, C = min tens, D = min units',
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () async {
                            await alarmNotifier.snoozeAlarm(
                              CustomAlarm(
                                settings: widget.alarm,
                                recurrence: const AlarmRecurrence.once(),
                              ),
                              const Duration(minutes: 1),
                            );
                            widget.onDismissed?.call();
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          child: const Text('Snooze'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            widget.onDismissed?.call();
                            Navigator.of(context).pop();
                          },
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMathTask(String question, int answer) {
    return Dialog(
      insetPadding: const EdgeInsets.all(8),
      child: Card(
        margin: const EdgeInsets.all(0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Math Challenge',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Solve:',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              Text(
                question,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Answer',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (val) => _input = val,
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_error, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _checkPassword(_input, answer),
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRetypeTask(String phrase) {
    return Dialog(
      insetPadding: const EdgeInsets.all(8),
      child: Card(
        margin: const EdgeInsets.all(0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Retype Challenge',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Retype the following phrase exactly:',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"$phrase"',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Type here',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => _input = val,
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_error, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (_input == phrase) {
                    setState(() {
                      _error = '';
                      _input = '';
                      _currentTaskIndex++;
                    });
                  } else {
                    setState(() {
                      _error = 'Incorrect!';
                    });
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSequenceTask(List<int> sequence) {
    return Dialog(
      insetPadding: const EdgeInsets.all(8),
      child: Card(
        margin: const EdgeInsets.all(0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Sequence Challenge',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Repeat this sequence:',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sequence.join(', '),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Enter sequence (comma separated)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => _input = val,
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_error, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final userSeq = _input
                      .split(',')
                      .map((e) => int.tryParse(e.trim()))
                      .toList();
                  if (userSeq.length == sequence.length &&
                      List.generate(
                        sequence.length,
                        (i) => userSeq[i] == sequence[i],
                      ).every((x) => x)) {
                    setState(() {
                      _error = '';
                      _input = '';
                      _currentTaskIndex++;
                    });
                  } else {
                    setState(() {
                      _error = 'Incorrect!';
                    });
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemoryTask(List<int> memory) {
    return Dialog(
      insetPadding: const EdgeInsets.all(8),
      child: Card(
        margin: const EdgeInsets.all(0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Memory Challenge',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Memorize this sequence:',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  memory.join(', '),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showMemoryInput = true;
                  });
                },
                child: const Text('Ready to recall'),
              ),
              if (_showMemoryInput)
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Enter sequence (comma separated)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _input = val,
                ),
              if (_showMemoryInput && _error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_error, style: const TextStyle(color: Colors.red)),
              ],
              if (_showMemoryInput)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: ElevatedButton(
                    onPressed: () {
                      final userSeq = _input
                          .split(',')
                          .map((e) => int.tryParse(e.trim()))
                          .toList();
                      if (userSeq.length == memory.length &&
                          List.generate(
                            memory.length,
                            (i) => userSeq[i] == memory[i],
                          ).every((x) => x)) {
                        setState(() {
                          _error = '';
                          _input = '';
                          _currentTaskIndex++;
                        });
                      } else {
                        setState(() {
                          _error = 'Incorrect!';
                        });
                      }
                    },
                    child: const Text('Submit'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Random Generators ---
  Map<String, dynamic> _generateRandomMath(String difficulty) {
    final rand = Random();
    int a, b, c;
    String question;
    int answer;
    switch (difficulty) {
      case 'easy':
        a = rand.nextInt(10) + 1;
        b = rand.nextInt(10) + 1;
        question = '$a + $b';
        answer = a + b;
        break;
      case 'medium':
        a = rand.nextInt(50) + 10;
        b = rand.nextInt(50) + 10;
        question = '$a - $b';
        answer = a - b;
        break;
      case 'hard':
        a = rand.nextInt(20) + 1;
        b = rand.nextInt(20) + 1;
        c = rand.nextInt(10) + 1;
        question = '($a + $b) * $c';
        answer = (a + b) * c;
        break;
      default:
        a = rand.nextInt(10) + 1;
        b = rand.nextInt(10) + 1;
        question = '$a + $b';
        answer = a + b;
    }
    return {'question': question, 'answer': answer};
  }

  String _generateRandomPhrase() {
    const phrases = [
      'Flutter is awesome!',
      'Wake up and shine!',
      'Solve to stop the alarm',
      'Good morning!',
      'Stay productive!',
      'Never give up!',
      'Keep moving forward!',
      'Seize the day!',
      'You can do it!',
      'Rise and grind!',
    ];
    final mutablePhrases = List<String>.from(phrases);
    mutablePhrases.shuffle();
    return mutablePhrases.first;
  }

  List<int> _generateRandomSequence() {
    final rand = Random();
    return List.generate(5, (_) => rand.nextInt(9) + 1);
  }

  List<int> _generateRandomMemory() {
    final rand = Random();
    return List.generate(4, (_) => rand.nextInt(9) + 1);
  }

  // --- State for memory task ---
  // This state variable is now managed within the _taskCache and _showMemoryInput
  // bool _showMemoryInput = false;

  void _checkPassword(String input, int? expected) {
    if (expected == null) {
      setState(() {
        _error = 'Invalid formula!';
      });
      return;
    }
    if (input == expected.toString()) {
      setState(() {
        _error = '';
        _input = '';
        _currentTaskIndex++;
      });
    } else {
      setState(() {
        _error = 'Incorrect answer!';
      });
    }
  }

  int? _evaluateFormula(String formula, int a, int b, int c, int d) {
    try {
      final context = {
        'A': a,
        'B': b,
        'C': c,
        'D': d,
        'abs': (num x) => x.abs(),
      };
      final expression = Expression.parse(formula);
      final evaluator = const ExpressionEvaluator();
      final result = evaluator.eval(expression, context);
      if (result is num) {
        return result.toInt();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
