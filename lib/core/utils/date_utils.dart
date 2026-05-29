import 'package:intl/intl.dart';

class AppDateUtils {
  static final _dateFormat = DateFormat('dd MMM yyyy');
  static final _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
  static final _timeFormat = DateFormat('hh:mm a');
  static final _shortDate = DateFormat('dd MMM');

  /// Format DateTime to "29 May 2026"
  static String formatDate(DateTime dt) => _dateFormat.format(dt);

  /// Format DateTime to "29 May 2026, 02:30 PM"
  static String formatDateTime(DateTime dt) => _dateTimeFormat.format(dt);

  /// Format DateTime to "02:30 PM"
  static String formatTime(DateTime dt) => _timeFormat.format(dt);

  /// Format DateTime to "29 May"
  static String formatShort(DateTime dt) => _shortDate.format(dt);

  /// Days remaining from now
  static int daysRemaining(DateTime target) {
    final diff = target.difference(DateTime.now());
    return diff.inDays.clamp(0, 999);
  }

  /// Human-readable relative time ("2 hours ago", "3 days ago")
  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  /// Parse Firestore Timestamp safely
  static DateTime fromTimestamp(dynamic ts) {
    if (ts == null) return DateTime.now();
    if (ts is DateTime) return ts;
    // Firestore Timestamp
    try {
      return ts.toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }

  /// mustStayUntil = submittedAt + 10 days
  static DateTime postMustStayUntil(DateTime submittedAt) {
    return submittedAt.add(const Duration(days: 10));
  }

  /// Whether a post is past its mandatory stay period
  static bool isPastMandatoryStay(DateTime submittedAt) {
    return DateTime.now().isAfter(postMustStayUntil(submittedAt));
  }
}
