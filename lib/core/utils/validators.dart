class Validators {
  /// URL validation (basic)
  static String? url(String? value) {
    if (value == null || value.trim().isEmpty) return 'URL is required';
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return 'Enter a valid URL (e.g. https://instagram.com/p/...)';
    }
    if (!['http', 'https'].contains(uri.scheme)) {
      return 'URL must start with http:// or https://';
    }
    return null;
  }

  /// Non-empty text field
  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    return null;
  }

  /// Text with max length
  static String? maxLength(String? value, int max, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    if (value.length > max) {
      return '${fieldName ?? 'This field'} must be $max characters or less';
    }
    return null;
  }

  /// Positive integer
  static String? positiveInt(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    final n = int.tryParse(value.trim());
    if (n == null || n <= 0) {
      return 'Enter a valid positive number';
    }
    return null;
  }

  /// Minimum rupee amount
  static String? minRupees(String? value, {required double min}) {
    if (value == null || value.trim().isEmpty) return 'Amount is required';
    final n = double.tryParse(value.replaceAll(',', '').trim());
    if (n == null || n < min) {
      return 'Minimum amount is ₹${min.toStringAsFixed(0)}';
    }
    return null;
  }

  /// UPI ID format: name@bank
  static String? upiId(String? value) {
    if (value == null || value.trim().isEmpty) return 'UPI ID is required';
    final regex = RegExp(r'^[\w.\-]+@[\w]+$');
    if (!regex.hasMatch(value.trim())) {
      return 'Invalid UPI ID format (e.g. name@upi)';
    }
    return null;
  }

  /// Indian mobile number
  static String? mobileNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Mobile number is required';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return 'Enter a valid 10-digit mobile number';
    return null;
  }

  /// Campaign description — max 500 chars
  static String? campaignDescription(String? value) {
    return maxLength(value, 500, fieldName: 'Description');
  }

  /// Withdrawal minimum
  static String? withdrawalAmount(String? value) {
    return minRupees(value, min: 100);
  }
}
