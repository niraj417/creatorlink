import 'package:intl/intl.dart';

/// Indian currency formatter — produces ₹1,23,456 format
class CurrencyFormatter {
  static final _indianFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final _indianFormatDecimal = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  /// Format paise (int) to ₹ display string
  /// e.g. 100000 paise → ₹1,000
  static String fromPaise(int paise) {
    final rupees = paise / 100.0;
    return _indianFormat.format(rupees);
  }

  /// Format rupees (double) to ₹ display string
  /// e.g. 123456.0 → ₹1,23,456
  static String fromRupees(double rupees) {
    return _indianFormat.format(rupees);
  }

  /// Format rupees with decimals
  /// e.g. 123.50 → ₹123.50
  static String fromRupeesDecimal(double rupees) {
    return _indianFormatDecimal.format(rupees);
  }

  /// Format points (1 point = ₹1)
  static String fromPoints(int points) {
    return _indianFormat.format(points.toDouble());
  }

  /// Compact format for large numbers
  /// e.g. 1200000 → ₹12L, 150000 → ₹1.5L
  static String compact(double rupees) {
    if (rupees >= 10000000) {
      return '₹${(rupees / 10000000).toStringAsFixed(1)}Cr';
    } else if (rupees >= 100000) {
      return '₹${(rupees / 100000).toStringAsFixed(1)}L';
    } else if (rupees >= 1000) {
      return '₹${(rupees / 1000).toStringAsFixed(1)}K';
    }
    return _indianFormat.format(rupees);
  }

  /// Format view count compactly
  /// e.g. 1200000 → 12L views
  static String compactViews(int views) {
    if (views >= 10000000) {
      return '${(views / 10000000).toStringAsFixed(1)}Cr';
    } else if (views >= 100000) {
      return '${(views / 100000).toStringAsFixed(1)}L';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }

  /// Convert INR rupees to paise
  static int toPaise(double rupees) => (rupees * 100).round();
}
