import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  static const String _historyStorageKey = 'calculator_history_v1';
  static const int _maxHistoryItems = 100;

  String _expression = '';
  String _result = '0';
  bool _justEvaluated = false;
  bool _hasError = false;
  List<_CalculationHistoryItem> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_historyStorageKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return;

      final items = decoded
          .whereType<Map>()
          .map(
            (entry) => _CalculationHistoryItem.fromJson(
              Map<String, dynamic>.from(entry),
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _history = items;
      });
    } catch (_) {
      // Keep calculator usable even if stored history is malformed.
    }
  }

  Future<void> _persistHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      _history.map((item) => item.toJson()).toList(),
    );
    await prefs.setString(_historyStorageKey, payload);
  }

  Future<void> _appendHistory({
    required String expression,
    required String result,
  }) async {
    final updated = [
      _CalculationHistoryItem(
        expression: expression,
        result: result,
        timestamp: DateTime.now(),
      ),
      ..._history,
    ];

    if (updated.length > _maxHistoryItems) {
      updated.removeRange(_maxHistoryItems, updated.length);
    }

    setState(() {
      _history = updated;
    });
    await _persistHistory();
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = [];
    });
    await prefs.remove(_historyStorageKey);
  }

  bool _isOperator(String value) {
    return value == '+' || value == '-' || value == '*' || value == '/';
  }

  String _normalizeExpression(String expression) {
    return expression
        .replaceAll('\u00D7', '*')
        .replaceAll('\u00F7', '/')
        .replaceAll('\u2212', '-');
  }

  String _prettyExpression(String expression) {
    return expression
        .replaceAll('*', '\u00D7')
        .replaceAll('/', '\u00F7')
        .replaceAll('-', '\u2212');
  }

  String _formatNumber(double value) {
    if (!value.isFinite) return 'Error';

    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    final text = value.toStringAsPrecision(12);
    if (text.contains('e') || text.contains('E')) {
      return text;
    }

    return text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String? _evaluateExpression(String expression) {
    final trimmed = expression.trim();
    if (trimmed.isEmpty) return null;

    try {
      final parser = _ExpressionParser(_normalizeExpression(trimmed));
      final value = parser.parse();
      return _formatNumber(value);
    } catch (_) {
      return null;
    }
  }

  void _refreshPreview() {
    if (_expression.trim().isEmpty) {
      _result = '0';
      return;
    }

    final evaluated = _evaluateExpression(_expression);
    _result = evaluated ?? _expression;
  }

  String _currentNumberSegment() {
    if (_expression.isEmpty) return '';

    int index = _expression.length - 1;
    while (index >= 0) {
      final char = _expression[index];
      if (_isOperator(char) || char == '(' || char == ')' || char == '%') {
        break;
      }
      index--;
    }

    return _expression.substring(index + 1);
  }

  void _appendDigit(String digit) {
    if (_hasError || _justEvaluated) {
      _expression = '';
      _result = '0';
      _hasError = false;
      _justEvaluated = false;
    }

    if (_expression == '0') {
      _expression = digit;
    } else {
      _expression += digit;
    }

    _refreshPreview();
  }

  void _appendDecimal() {
    if (_hasError || _justEvaluated) {
      _expression = '';
      _result = '0';
      _hasError = false;
      _justEvaluated = false;
    }

    final segment = _currentNumberSegment();
    if (segment.contains('.')) {
      return;
    }

    if (_expression.isEmpty ||
        _isOperator(_expression[_expression.length - 1]) ||
        _expression.endsWith('(')) {
      _expression += '0.';
    } else {
      _expression += '.';
    }

    _refreshPreview();
  }

  void _appendPercent() {
    if (_expression.isEmpty || _hasError) return;

    final last = _expression[_expression.length - 1];
    if (_isOperator(last) || last == '.' || last == '(') {
      return;
    }

    if (_justEvaluated) {
      _justEvaluated = false;
    }

    _expression += '%';
    _refreshPreview();
  }

  void _appendOperator(String operator) {
    if (_hasError) return;

    if (_justEvaluated) {
      _expression = _result == 'Error' ? '' : _result;
      _justEvaluated = false;
    }

    if (_expression.isEmpty) {
      if (operator == '-') {
        _expression = operator;
        _result = _expression;
      }
      return;
    }

    final last = _expression[_expression.length - 1];
    if (_isOperator(last)) {
      _expression = _expression.substring(0, _expression.length - 1) + operator;
      _refreshPreview();
      return;
    }

    if (last == '.') {
      return;
    }

    _expression += operator;
    _refreshPreview();
  }

  void _backspace() {
    if (_hasError) {
      _expression = '';
      _result = '0';
      _justEvaluated = false;
      _hasError = false;
      return;
    }

    if (_justEvaluated) {
      _justEvaluated = false;
    }

    if (_expression.isEmpty) {
      _result = '0';
      return;
    }

    _expression = _expression.substring(0, _expression.length - 1);
    _refreshPreview();
  }

  void _clearAll() {
    setState(() {
      _expression = '';
      _result = '0';
      _justEvaluated = false;
      _hasError = false;
    });
  }

  Future<void> _evaluateEquals() async {
    final trimmed = _expression.trim();
    if (trimmed.isEmpty) return;

    final evaluated = _evaluateExpression(trimmed);

    if (evaluated == null || evaluated == 'Error') {
      setState(() {
        _result = 'Error';
        _hasError = true;
        _justEvaluated = false;
      });
      return;
    }

    final expressionToSave = _expression;
    setState(() {
      _result = evaluated;
      _justEvaluated = true;
      _hasError = false;
    });

    await _appendHistory(
      expression: expressionToSave,
      result: evaluated,
    );
  }

  void _restoreHistoryItem(_CalculationHistoryItem item) {
    setState(() {
      _expression = item.expression;
      _result = item.result;
      _justEvaluated = true;
      _hasError = false;
    });
  }

  Future<void> _openHistorySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            final sheetColor = isDark
                ? const Color(0xFF111315)
                : Colors.white;
            final itemColor = isDark
                ? const Color(0xFF1D2125)
                : const Color(0xFFF5F7FA);

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
                ),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                decoration: BoxDecoration(
                  color: sheetColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Calculation History',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (_history.isNotEmpty)
                          TextButton(
                            onPressed: () async {
                              await _clearHistory();
                              if (!mounted) return;
                              setSheetState(() {});
                            },
                            child: const Text('Clear history'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _history.isEmpty
                          ? Center(
                              child: Text(
                                'No calculations yet.',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _history.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = _history[index];
                                return Material(
                                  color: itemColor,
                                  borderRadius: BorderRadius.circular(18),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () {
                                      Navigator.of(sheetContext).pop();
                                      _restoreHistoryItem(item);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _prettyExpression(item.expression),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item.result,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _formatHistoryTimestamp(
                                              item.timestamp,
                                            ),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatHistoryTimestamp(DateTime timestamp) {
    final day = timestamp.day.toString().padLeft(2, '0');
    final month = timestamp.month.toString().padLeft(2, '0');
    final year = timestamp.year.toString();
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$day/$month/$year  $hour:$minute';
  }

  void _handleInput(_CalcButtonData button) {
    final value = button.value;
    if (value == 'AC') {
      _clearAll();
      return;
    }

    if (value == 'backspace') {
      setState(_backspace);
      return;
    }

    if (value == '=') {
      _evaluateEquals();
      return;
    }

    setState(() {
      if (_isOperator(value)) {
        _appendOperator(value);
      } else if (value == '.') {
        _appendDecimal();
      } else if (value == '%') {
        _appendPercent();
      } else {
        _appendDigit(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final displayColor = isDark
        ? const Color(0xFF111315)
        : const Color(0xFFFFFFFF);
    final numberButtonColor = isDark
        ? const Color(0xFF1F2328)
        : const Color(0xFFF1F3F4);
    final functionButtonColor = isDark
        ? const Color(0xFF2A2F36)
        : const Color(0xFFE8F0FE);
    final operatorButtonColor = isDark
        ? const Color(0xFF25384C)
        : const Color(0xFFD2E3FC);
    final equalsButtonColor = isDark
        ? const Color(0xFF8AB4F8)
        : const Color(0xFF1A73E8);

    final expressionText = _expression.isEmpty ? '0' : _expression;
    final resultText = _result == _expression && !_hasError
        ? _prettyExpression(_result)
        : _result;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: displayColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Spacer(),
                        IconButton(
                          tooltip: 'History',
                          onPressed: _openHistorySheet,
                          icon: Icon(
                            Icons.history_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Text(
                        _prettyExpression(expressionText),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          resultText,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: _hasError
                                ? Colors.redAccent
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              flex: 7,
              child: Column(
                children: [
                  _buildButtonRow(
                    context,
                    [
                      _CalcButtonData(
                        value: 'AC',
                        label: 'AC',
                        kind: _CalcButtonKind.function,
                      ),
                      _CalcButtonData(
                        value: 'backspace',
                        icon: Icons.backspace_outlined,
                        kind: _CalcButtonKind.function,
                      ),
                      _CalcButtonData(
                        value: '%',
                        label: '%',
                        kind: _CalcButtonKind.function,
                      ),
                      _CalcButtonData(
                        value: '/',
                        label: '\u00F7',
                        kind: _CalcButtonKind.operator,
                      ),
                    ],
                    numberButtonColor: numberButtonColor,
                    functionButtonColor: functionButtonColor,
                    operatorButtonColor: operatorButtonColor,
                    equalsButtonColor: equalsButtonColor,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildButtonRow(
                    context,
                    [
                      _CalcButtonData(
                        value: '7',
                        label: '7',
                        kind: _CalcButtonKind.number,
                      ),
                      _CalcButtonData(
                        value: '8',
                        label: '8',
                        kind: _CalcButtonKind.number,
                      ),
                      _CalcButtonData(
                        value: '9',
                        label: '9',
                        kind: _CalcButtonKind.number,
                      ),
                      _CalcButtonData(
                        value: '*',
                        label: '\u00D7',
                        kind: _CalcButtonKind.operator,
                      ),
                    ],
                    numberButtonColor: numberButtonColor,
                    functionButtonColor: functionButtonColor,
                    operatorButtonColor: operatorButtonColor,
                    equalsButtonColor: equalsButtonColor,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildButtonRow(
                    context,
                    [
                      _CalcButtonData(
                        value: '4',
                        label: '4',
                        kind: _CalcButtonKind.number,
                      ),
                      _CalcButtonData(
                        value: '5',
                        label: '5',
                        kind: _CalcButtonKind.number,
                      ),
                      _CalcButtonData(
                        value: '6',
                        label: '6',
                        kind: _CalcButtonKind.number,
                      ),
                      _CalcButtonData(
                        value: '-',
                        label: '\u2212',
                        kind: _CalcButtonKind.operator,
                      ),
                    ],
                    numberButtonColor: numberButtonColor,
                    functionButtonColor: functionButtonColor,
                    operatorButtonColor: operatorButtonColor,
                    equalsButtonColor: equalsButtonColor,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildButtonRow(
                    context,
                    [
                      _CalcButtonData(
                        value: '1',
                        label: '1',
                        kind: _CalcButtonKind.number,
                      ),
                      _CalcButtonData(
                        value: '2',
                        label: '2',
                        kind: _CalcButtonKind.number,
                      ),
                      _CalcButtonData(
                        value: '3',
                        label: '3',
                        kind: _CalcButtonKind.number,
                      ),
                      _CalcButtonData(
                        value: '+',
                        label: '+',
                        kind: _CalcButtonKind.operator,
                      ),
                    ],
                    numberButtonColor: numberButtonColor,
                    functionButtonColor: functionButtonColor,
                    operatorButtonColor: operatorButtonColor,
                    equalsButtonColor: equalsButtonColor,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildButtonRow(
                    context,
                    [
                      _CalcButtonData(
                        value: '0',
                        label: '0',
                        kind: _CalcButtonKind.number,
                        flex: 2,
                      ),
                      _CalcButtonData(
                        value: '.',
                        label: '.',
                        kind: _CalcButtonKind.number,
                      ),
                      _CalcButtonData(
                        value: '=',
                        label: '=',
                        kind: _CalcButtonKind.equals,
                      ),
                    ],
                    numberButtonColor: numberButtonColor,
                    functionButtonColor: functionButtonColor,
                    operatorButtonColor: operatorButtonColor,
                    equalsButtonColor: equalsButtonColor,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonRow(
    BuildContext context,
    List<_CalcButtonData> buttons, {
    required Color numberButtonColor,
    required Color functionButtonColor,
    required Color operatorButtonColor,
    required Color equalsButtonColor,
    required bool isDark,
  }) {
    return Row(
      children: buttons.map((button) {
        Color backgroundColor;
        Color foregroundColor;

        switch (button.kind) {
          case _CalcButtonKind.function:
            backgroundColor = functionButtonColor;
            foregroundColor = isDark
                ? const Color(0xFFD2E3FC)
                : const Color(0xFF174EA6);
            break;
          case _CalcButtonKind.operator:
            backgroundColor = operatorButtonColor;
            foregroundColor = isDark
                ? const Color(0xFF8AB4F8)
                : const Color(0xFF174EA6);
            break;
          case _CalcButtonKind.equals:
            backgroundColor = equalsButtonColor;
            foregroundColor = isDark ? const Color(0xFF0F172A) : Colors.white;
            break;
          case _CalcButtonKind.number:
            backgroundColor = numberButtonColor;
            foregroundColor = Theme.of(context).colorScheme.onSurface;
            break;
        }

        return Expanded(
          flex: button.flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(26),
              child: InkWell(
                borderRadius: BorderRadius.circular(26),
                onTap: () => _handleInput(button),
                child: Container(
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: button.icon != null
                      ? Icon(
                          button.icon,
                          color: foregroundColor,
                          size: 24,
                        )
                      : Text(
                          button.label ?? '',
                          style: TextStyle(
                            color: foregroundColor,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

enum _CalcButtonKind { number, function, operator, equals }

class _CalcButtonData {
  final String value;
  final String? label;
  final IconData? icon;
  final _CalcButtonKind kind;
  final int flex;

  const _CalcButtonData({
    required this.value,
    this.label,
    this.icon,
    required this.kind,
    this.flex = 1,
  });
}

class _CalculationHistoryItem {
  final String expression;
  final String result;
  final DateTime timestamp;

  const _CalculationHistoryItem({
    required this.expression,
    required this.result,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'expression': expression,
      'result': result,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory _CalculationHistoryItem.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = (json['timestamp'] ?? '').toString();
    return _CalculationHistoryItem(
      expression: (json['expression'] ?? '').toString(),
      result: (json['result'] ?? '').toString(),
      timestamp: DateTime.tryParse(rawTimestamp) ?? DateTime.now(),
    );
  }
}

class _ExpressionParser {
  final String input;
  int _index = 0;

  _ExpressionParser(this.input);

  double parse() {
    final value = _parseExpression();
    _skipWhitespace();

    if (_index != input.length) {
      throw const FormatException('Unexpected trailing input');
    }

    return value;
  }

  double _parseExpression() {
    double value = _parseTerm();

    while (true) {
      _skipWhitespace();
      if (_match('+')) {
        value += _parseTerm();
      } else if (_match('-')) {
        value -= _parseTerm();
      } else {
        return value;
      }
    }
  }

  double _parseTerm() {
    double value = _parseFactor();

    while (true) {
      _skipWhitespace();
      if (_match('*')) {
        value *= _parseFactor();
      } else if (_match('/')) {
        final divisor = _parseFactor();
        if (divisor == 0) {
          throw const FormatException('Division by zero');
        }
        value /= divisor;
      } else {
        return value;
      }
    }
  }

  double _parseFactor() {
    double value = _parseUnary();

    while (true) {
      _skipWhitespace();
      if (_match('%')) {
        value /= 100;
      } else {
        return value;
      }
    }
  }

  double _parseUnary() {
    _skipWhitespace();

    if (_match('+')) {
      return _parseUnary();
    }
    if (_match('-')) {
      return -_parseUnary();
    }

    return _parsePrimary();
  }

  double _parsePrimary() {
    _skipWhitespace();

    if (_match('(')) {
      final value = _parseExpression();
      _skipWhitespace();
      if (!_match(')')) {
        throw const FormatException('Missing closing parenthesis');
      }
      return value;
    }

    return _parseNumber();
  }

  double _parseNumber() {
    _skipWhitespace();
    final start = _index;
    bool sawDecimal = false;

    while (_index < input.length) {
      final char = input[_index];
      final isDigit = char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;

      if (isDigit) {
        _index++;
        continue;
      }

      if (char == '.') {
        if (sawDecimal) break;
        sawDecimal = true;
        _index++;
        continue;
      }

      break;
    }

    if (start == _index) {
      throw const FormatException('Expected number');
    }

    final raw = input.substring(start, _index);
    final value = double.tryParse(raw);
    if (value == null) {
      throw const FormatException('Invalid number');
    }

    return value;
  }

  bool _match(String expected) {
    if (_index >= input.length) return false;
    if (input[_index] != expected) return false;
    _index++;
    return true;
  }

  void _skipWhitespace() {
    while (_index < input.length && input[_index].trim().isEmpty) {
      _index++;
    }
  }
}
