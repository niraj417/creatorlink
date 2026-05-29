import 'package:cloud_firestore/cloud_firestore.dart';

enum AppealStatus {
  pending,
  underReview,
  resolvedApproved,
  resolvedRejected,
}

class AppealModel {
  final String id;
  final String creatorUid;
  final String postId;
  final String reason;
  final String? screenshotUrl;
  final AppealStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolverNote;
  final String? creatorName;
  final String? postUrl;

  const AppealModel({
    required this.id,
    required this.creatorUid,
    required this.postId,
    required this.reason,
    this.screenshotUrl,
    this.status = AppealStatus.pending,
    required this.createdAt,
    this.resolvedAt,
    this.resolverNote,
    this.creatorName,
    this.postUrl,
  });

  factory AppealModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppealModel(
      id: doc.id,
      creatorUid: data['creatorUid'] ?? '',
      postId: data['postId'] ?? '',
      reason: data['reason'] ?? '',
      screenshotUrl: data['screenshotUrl'],
      status: _parseStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      resolverNote: data['resolverNote'],
      creatorName: data['creatorName'],
      postUrl: data['postUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'creatorUid': creatorUid,
      'postId': postId,
      'reason': reason,
      'screenshotUrl': screenshotUrl,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolverNote': resolverNote,
      'creatorName': creatorName,
      'postUrl': postUrl,
    };
  }

  AppealModel copyWith({
    AppealStatus? status,
    DateTime? resolvedAt,
    String? resolverNote,
  }) {
    return AppealModel(
      id: id,
      creatorUid: creatorUid,
      postId: postId,
      reason: reason,
      screenshotUrl: screenshotUrl,
      status: status ?? this.status,
      createdAt: createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolverNote: resolverNote ?? this.resolverNote,
      creatorName: creatorName,
      postUrl: postUrl,
    );
  }

  static AppealStatus _parseStatus(String? s) {
    switch (s) {
      case 'pending':
        return AppealStatus.pending;
      case 'underReview':
        return AppealStatus.underReview;
      case 'resolvedApproved':
        return AppealStatus.resolvedApproved;
      case 'resolvedRejected':
        return AppealStatus.resolvedRejected;
      default:
        return AppealStatus.pending;
    }
  }

  String get statusLabel {
    switch (status) {
      case AppealStatus.pending:
        return 'Pending';
      case AppealStatus.underReview:
        return 'Under Review';
      case AppealStatus.resolvedApproved:
        return 'Approved';
      case AppealStatus.resolvedRejected:
        return 'Rejected';
    }
  }

  bool get isResolved =>
      status == AppealStatus.resolvedApproved ||
      status == AppealStatus.resolvedRejected;
}
