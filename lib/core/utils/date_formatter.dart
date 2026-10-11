/// Pure Dart date formatting utilities without external locale dependencies.
class DateFormatter {
  static const List<String> _days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  static const List<String> _months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  /// Example: "Selasa, 01 September 2026"
  static String formatFullDate(DateTime dt) {
    final dayName = _days[(dt.weekday - 1).clamp(0, 6)];
    final monthName = _months[(dt.month - 1).clamp(0, 11)];
    final day = dt.day.toString().padLeft(2, '0');
    return '$dayName, $day $monthName ${dt.year}';
  }

  /// Example: "01/09/2026 14:30"
  static String formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} $hour:$minute';
  }

  /// Example: "01/09/2026"
  static String formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month/${dt.year}';
  }

  /// Example: "14:30"
  static String formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
