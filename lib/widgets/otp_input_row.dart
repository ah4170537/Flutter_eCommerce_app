import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class OtpInputRow extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  const OtpInputRow({
    super.key,
    this.length = 4,
    this.onChanged,
    this.onCompleted,
  });

  @override
  State<OtpInputRow> createState() => _OtpInputRowState();
}

class _OtpInputRowState extends State<OtpInputRow> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.length,
      (_) => TextEditingController(),
    );
    
    // Initialize FocusNodes with backspace key event handling
    _focusNodes = List.generate(
      widget.length,
      (index) => FocusNode()
        ..onKeyEvent = (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            // If current box is empty and we can go back, clear previous box and move back
            if (_controllers[index].text.isEmpty && index > 0) {
              _controllers[index - 1].clear();
              _focusNodes[index - 1].requestFocus();
              
              final code = _controllers.map((c) => c.text).join();
              widget.onChanged?.call(code);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _handleChange(String value, int index) {
    if (value.isNotEmpty) {
      // Ensure only the latest character is kept if typed/pasted over
      final char = value.characters.last;
      if (_controllers[index].text != char) {
        _controllers[index].text = char;
        _controllers[index].selection = TextSelection.fromPosition(
          const TextPosition(offset: 1),
        );
      }

      // Move to next box if available
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      }
    } else {
      // If cleared via normal deletion
      _controllers[index].clear();
    }

    final code = _controllers.map((c) => c.text).join();
    widget.onChanged?.call(code);
    
    if (code.length == widget.length) {
      widget.onCompleted?.call(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (index) {
        return SizedBox(
          width: 60,
          height: 60,
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: AppTextStyles.heading.copyWith(fontSize: 22),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: AppColors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.hintGrey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.hintGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryLight,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (value) => _handleChange(value, index),
          ),
        );
      }),
    );
  }
}