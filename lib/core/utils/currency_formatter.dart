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
}
