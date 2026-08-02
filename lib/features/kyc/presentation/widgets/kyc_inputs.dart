import 'package:flutter/services.dart';

/// Input rules for the identity numbers the KYC wizard collects.
///
/// Every field used to be a bare `TextField` whose `keyboardType` was the only
/// guard — and a keyboard type is a hint to the OS, not a constraint. A pasted
/// value, a hardware keyboard, or a keyboard that ignores the hint could all
/// put letters in an account number. These enforce the shape as it is typed,
/// so validation at the end of a step is a formality rather than the first
/// time anyone checks.
class KycInputs {
  const KycInputs._();

  static final digits = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
  ];

  /// 12 digits, shown in the 4-4-4 grouping printed on the card itself.
  static final aadhaar = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(12),
    _GroupDigits(size: 4),
  ];

  /// `ABCDE1234F` — five letters, four digits, a letter.
  static final pan = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
    LengthLimitingTextInputFormatter(10),
    _Upper(),
  ];

  /// `HDFC0001234` — four letters, a zero, six alphanumerics.
  static final ifsc = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
    LengthLimitingTextInputFormatter(11),
    _Upper(),
  ];

  static final account = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(18),
  ];

  static final uan = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(12),
  ];

  /// 15 characters, e.g. `27AAPFU0939F1ZV`.
  static final gst = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
    LengthLimitingTextInputFormatter(15),
    _Upper(),
  ];

  static final panPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
  static final ifscPattern = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
  static final gstPattern = RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z][Z][0-9A-Z]$',
  );

  /// Strips the display grouping before anything is sent or compared.
  static String bare(String value) => value.replaceAll(RegExp(r'\s+'), '');
}

class _Upper extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue next) {
    return next.copyWith(text: next.text.toUpperCase());
  }
}

/// Inserts a space every [size] characters, keeping the caret at the end of
/// what was typed.
class _GroupDigits extends TextInputFormatter {
  _GroupDigits({required this.size});

  final int size;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue next) {
    final raw = next.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && i % size == 0) buffer.write(' ');
      buffer.write(raw[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
