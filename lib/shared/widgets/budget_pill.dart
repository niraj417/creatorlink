import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Color-coded budget remaining pill
/// Green: > 30% | Amber: < 30% | Red: < 10%
class BudgetPill extends StatelessWidget {
  final double remainingPercent; // 0.0 to 1.0
  final int walletBalance; // in rupees
  final bool compact;

  const BudgetPill({
    super.key,
    required this.remainingPercent,
    required this.walletBalance,
    this.compact = false,
  });

  Color get _color {
    if (remainingPercent > 0.30) return AppColors.accentGreen;
    if (remainingPercent > 0.10) return AppColors.accentAmber;
    return AppColors.accentRed;
  }

  String get _label {
    if (compact) {
      if (walletBalance >= 100000) {
        return '₹${(walletBalance / 100000).toStringAsFixed(1)}L';
      }
      if (walletBalance >= 1000) {
        return '₹${(walletBalance / 1000).toStringAsFixed(1)}K';
      }
      return '₹$walletBalance';
    }
    return '₹$walletBalance left';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            _label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Campaign status pill (Active / Paused / Full)
class StatusPill extends StatelessWidget {
  final String status; // 'active' | 'paused' | 'full' | 'ended'

  const StatusPill({super.key, required this.status});

  Color get _color {
    switch (status) {
      case 'active':
        return AppColors.accentGreen;
      case 'paused':
        return AppColors.accentAmber;
      case 'full':
      case 'ended':
        return AppColors.accentRed;
      default:
        return AppColors.textMuted;
    }
  }

  String get _label => status[0].toUpperCase() + status.substring(1);

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Appeal / post status pill
class AppealStatusPill extends StatelessWidget {
  final String status;
  const AppealStatusPill({super.key, required this.status});

  Color get _color {
    switch (status) {
      case 'pending':
        return AppColors.accentAmber;
      case 'underReview':
        return AppColors.accentViolet;
      case 'resolvedApproved':
        return AppColors.accentGreen;
      case 'resolvedRejected':
        return AppColors.accentRed;
      default:
        return AppColors.textMuted;
    }
  }

  String get _label {
    switch (status) {
      case 'underReview':
        return 'Under Review';
      case 'resolvedApproved':
        return 'Approved';
      case 'resolvedRejected':
        return 'Rejected';
      default:
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
