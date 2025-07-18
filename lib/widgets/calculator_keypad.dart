import 'package:flutter/material.dart';

class CalculatorKeypad extends StatelessWidget {
  final void Function(String) onKey;
  const CalculatorKeypad({super.key, required this.onKey});

  static const _keys = [
    '7',
    '8',
    '9',
    '/',
    '4',
    '5',
    '6',
    '*',
    '1',
    '2',
    '3',
    '-',
    '0',
    '.',
    '%',
    '+',
    'C',
    '<',
    '=',
  ];

  Color _getKeyColor(String key, BuildContext context) {
    if (key == 'C') {
      return Theme.of(context).colorScheme.error;
    } else if (key == '<') {
      return Colors.orange;
    } else if (key == '=') {
      return Theme.of(context).colorScheme.primary;
    } else if ('/*-%+'.contains(key)) {
      return Theme.of(context).colorScheme.secondary;
    } else {
      return Theme.of(context).colorScheme.surfaceVariant;
    }
  }

  Color _getTextColor(String key, BuildContext context) {
    if (key == 'C' || key == '<' || key == '=' || '/*-%+'.contains(key)) {
      return Colors.white;
    } else {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 4 columns, 5 rows (last row has 3 keys, so add a blank at the end)
    final keys = List<String>.from(_keys);
    if (keys.length % 4 != 0) {
      keys.add(''); // Add blank for grid alignment
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final key = keys[index];
              if (key.isEmpty) return const SizedBox.shrink();
              return ElevatedButton(
                onPressed: () => onKey(key),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getKeyColor(key, context),
                  foregroundColor: _getTextColor(key, context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                  ),
                  elevation: 2,
                  minimumSize: const Size(0, 0),
                  padding: EdgeInsets.zero,
                ),
                child: Center(child: Text(key)),
              );
            },
          ),
        );
      },
    );
  }
}
