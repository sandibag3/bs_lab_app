import 'package:flutter/material.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String output = '0';
  String currentInput = '';
  double firstNumber = 0;
  String operator = '';

  void buttonPressed(String value) {
    setState(() {
      if (value == 'C') {
        output = '0';
        currentInput = '';
        firstNumber = 0;
        operator = '';
      } else if (value == '+' ||
          value == '-' ||
          value == '×' ||
          value == '÷') {
        firstNumber =
            double.tryParse(currentInput.isEmpty ? '0' : currentInput) ?? 0;
        operator = value;
        currentInput = '';
      } else if (value == '=') {
        final secondNumber =
            double.tryParse(currentInput.isEmpty ? '0' : currentInput) ?? 0;
        double result = 0;

        if (operator == '+') {
          result = firstNumber + secondNumber;
        } else if (operator == '-') {
          result = firstNumber - secondNumber;
        } else if (operator == '×') {
          result = firstNumber * secondNumber;
        } else if (operator == '÷') {
          result = secondNumber != 0 ? firstNumber / secondNumber : 0;
        }

        output = result.toString();
        currentInput = output;
        operator = '';
      } else {
        currentInput += value;
        output = currentInput;
      }
    });
  }

  Widget calcButton(String text) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: ElevatedButton(
          onPressed: () => buttonPressed(text),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            foregroundColor: text == 'C' ? Colors.redAccent : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildRow(List<String> buttons) {
    return Row(
      children: buttons.map(calcButton).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.all(24),
              child: Text(
                output,
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          buildRow(['7', '8', '9', '÷']),
          buildRow(['4', '5', '6', '×']),
          buildRow(['1', '2', '3', '-']),
          buildRow(['C', '0', '=', '+']),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}