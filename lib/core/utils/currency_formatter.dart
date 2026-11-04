import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Utility for formatting Indonesian Rupiah currency values.
///
/// Uses the `id_ID` locale via [intl] to produce values like `Rp 2.450.000`.
class CurrencyFormatter {
  CurrencyFormatter._();

  static final _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final _formatterWithDecimal = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 2,
  );

  /// Formats [amount] as Rupiah without decimals.
  ///
  /// Example: `format(2450000)` → `'Rp 2.450.000'`
  static String format(num amount) => _formatter.format(amount);

  /// Formats [amount] as Rupiah with 2 decimal places.
  ///
  /// Example: `formatWithDecimal(2450000.5)` → `'Rp 2.450.000,50'`
  static String formatWithDecimal(num amount) =>
      _formatterWithDecimal.format(amount);

  /// Formats [amount] as a compact number without currency symbol.
  ///
  /// Example: `formatCompact(2450000)` → `'2.450.000'`
  static String formatCompact(num amount) {
    final f = NumberFormat('#,##0', 'id_ID');
    return f.format(amount);
  }

  /// Parses a formatted Indonesian number string like `'150.000'` or `'150000'` to double.
  static double parse(String text) {
    final clean = text.replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(clean) ?? 0.0;
  }
}

/// A [TextInputFormatter] that automatically inserts thousand separator dots (`.`)
/// as the user types Indonesian currency amounts.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat('#,##0', 'id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Only allow digits
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final number = int.tryParse(digitsOnly);
    if (number == null) {
      return oldValue;
    }

    final formatted = _formatter.format(number);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
