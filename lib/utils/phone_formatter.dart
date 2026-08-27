import 'package:flutter/services.dart';

/// Number of significant digits in a Turkish subscriber number, e.g. the
/// "5551234567" inside "(555) 123 45 67".
const int kPhoneDigitCount = 10;

/// Masks a phone number as `(555) 555 55 55` while the user types.
///
/// Only digits are kept from the input; the brackets and spaces are inserted
/// by this formatter, so the user can paste "+90 555 123 45 67" or
/// "0555 123 45 67" and still end up with a well-formed number.
class TurkishPhoneInputFormatter extends TextInputFormatter {
  const TurkishPhoneInputFormatter();

  /// Digits in each group, in order: (555) 555 55 55.
  static const List<int> _groups = [3, 3, 2, 2];

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = extractDigits(newValue.text);

    // Count how many digits precede the caret so it can be put back in the
    // equivalent spot once the separators have been re-inserted.
    final digitsBeforeCaret = extractDigits(
      newValue.text.substring(0, newValue.selection.end.clamp(0, newValue.text.length)),
    ).length;

    final formatted = format(digits);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: _offsetAfterDigit(formatted, digitsBeforeCaret),
      ),
    );
  }

  /// Strips everything but digits, then drops the country/trunk prefix so
  /// "+90 555…", "0090 555…" and "0555…" all reduce to the same 10 digits.
  static String extractDigits(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('0090')) {
      digits = digits.substring(4);
    } else if (digits.startsWith('90') && digits.length > kPhoneDigitCount) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    return digits.length > kPhoneDigitCount
        ? digits.substring(0, kPhoneDigitCount)
        : digits;
  }

  /// Renders [digits] as `(555) 555 55 55`, stopping wherever the digits run
  /// out so partially-typed numbers stay readable.
  static String format(String digits) {
    if (digits.isEmpty) return '';

    final buffer = StringBuffer();
    var index = 0;

    for (var group = 0; group < _groups.length; group++) {
      if (index >= digits.length) break;

      final end = (index + _groups[group]).clamp(0, digits.length);
      final chunk = digits.substring(index, end);

      if (group == 0) {
        // The area code keeps its opening bracket from the first keystroke,
        // and only gains the closing one once all three digits are in.
        buffer.write('($chunk');
        if (chunk.length == _groups[0]) buffer.write(')');
      } else {
        buffer.write(' $chunk');
      }

      index = end;
    }

    return buffer.toString();
  }

  /// True when [text] holds a complete 10-digit number.
  static bool isComplete(String text) =>
      extractDigits(text).length == kPhoneDigitCount;

  /// Position just after the [digitCount]-th digit of [formatted].
  static int _offsetAfterDigit(String formatted, int digitCount) {
    if (digitCount <= 0) return 0;

    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (_isDigit(formatted[i])) {
        seen++;
        if (seen == digitCount) {
          // Step past any separator that immediately follows, so typing runs
          // straight on instead of stalling before a bracket or space.
          var offset = i + 1;
          while (offset < formatted.length && !_isDigit(formatted[offset])) {
            offset++;
          }
          return offset;
        }
      }
    }
    return formatted.length;
  }

  static bool _isDigit(String character) {
    final code = character.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }
}
