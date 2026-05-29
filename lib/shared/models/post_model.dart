import 'package:cloud_firestore/cloud_firestore.dart';

enum PostStatus {
  pendingPost,    // creator joined, not yet submitted
  pendingReview,  // submitted, waiting for URL verification
  approved,       // verified and approved
  rejected,       // rejected by admin
  mayRemove,      // past 10 days + budget = 0
  removed,        // removed by creator or admin
}

enum SocialPlatform { instagram, youtube, twitter, linkedin, other }

class PostModel {
  final String id;
  final String creatorUid;
  final String campaignId;
  final String postUrl;
  final String? screenshotUrl;
  final SocialPlatform platform;
  final PostStatus status;
  final int views;
  final int reach;
  final int interactions;
  final bool flagged;
  final String? flagReason;
  final DateTime submittedAt;
  final DateTime? lastViewUpdate;
  final DateTime mustStayUntil;
  final String? creatorName;
  final String? creatorPhotoUrl;
  final String? campaignName;
  // Daily view snapshots for spike detection: {date: count}
  final Map<String, int> dailyViewHistory;

  const PostModel({
    required this.id,
    required this.creatorUid,
    required this.campaignId,
    required this.postUrl,
    this.screenshotUrl,
    required this.platform,
    required this.status,
    this.views = 0,
    this.reach = 0,
    this.interactions = 0,
    this.flagged = false,
    this.flagReason,
    required this.submittedAt,
    this.lastViewUpdate,
    required this.mustStayUntil,
    this.creatorName,
    this.creatorPhotoUrl,
    this.campaignName,
    this.dailyViewHistory = const {},
  });

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PostModel(
      id: doc.id,
      creatorUid: data['creatorUid'] ?? '',
      campaignId: data['campaignId'] ?? '',
      postUrl: data['postUrl'] ?? '',
      screenshotUrl: data['screenshotUrl'],
      platform: _parsePlatform(data['platform']),
      status: _parseStatus(data['status']),
      views: (data['views'] ?? 0) as int,
      reach: (data['reach'] ?? 0) as int,
      interactions: (data['interactions'] ?? 0) as int,
      flagged: data['flagged'] ?? false,
      flagReason: data['flagReason'],
      submittedAt:
          (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastViewUpdate: (data['lastViewUpdate'] as Timestamp?)?.toDate(),
      mustStayUntil:
          (data['mustStayUntil'] as Timestamp?)?.toDate() ?? DateTime.now(),
      creatorName: data['creatorName'],
      creatorPhotoUrl: data['creatorPhotoUrl'],
      campaignName: data['campaignName'],
      dailyViewHistory: Map<String, int>.from(data['dailyViewHistory'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'creatorUid': creatorUid,
      'campaignId': campaignId,
      'postUrl': postUrl,
      'screenshotUrl': screenshotUrl,
      'platform': platform.name,
      'status': status.name,
      'views': views,
      'reach': reach,
      'interactions': interactions,
      'flagged': flagged,
      'flagReason': flagReason,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'lastViewUpdate':
          lastViewUpdate != null ? Timestamp.fromDate(lastViewUpdate!) : null,
      'mustStayUntil': Timestamp.fromDate(mustStayUntil),
      'creatorName': creatorName,
      'creatorPhotoUrl': creatorPhotoUrl,
      'campaignName': campaignName,
      'dailyViewHistory': dailyViewHistory,
    };
  }

  PostModel copyWith({
    String? postUrl,
    String? screenshotUrl,
    PostStatus? status,
    int? views,
    int? reach,
    int? interactions,
    bool? flagged,
    String? flagReason,
    DateTime? lastViewUpdate,
    Map<String, int>? dailyViewHistory,
  }) {
    return PostModel(
      id: id,
      creatorUid: creatorUid,
      campaignId: campaignId,
      postUrl: postUrl ?? this.postUrl,
      screenshotUrl: screenshotUrl ?? this.screenshotUrl,
      platform: platform,
      status: status ?? this.status,
      views: views ?? this.views,
      reach: reach ?? this.reach,
      interactions: interactions ?? this.interactions,
      flagged: flagged ?? this.flagged,
      flagReason: flagReason ?? this.flagReason,
      submittedAt: submittedAt,
      lastViewUpdate: lastViewUpdate ?? this.lastViewUpdate,
      mustStayUntil: mustStayUntil,
      creatorName: creatorName,
      creatorPhotoUrl: creatorPhotoUrl,
      campaignName: campaignName,
      dailyViewHistory: dailyViewHistory ?? this.dailyViewHistory,
    );
  }

  static PostStatus _parseStatus(String? s) {
    switch (s) {
      case 'pendingPost':
        return PostStatus.pendingPost;
      case 'pendingReview':
        return PostStatus.pendingReview;
      case 'approved':
        return PostStatus.approved;
      case 'rejected':
        return PostStatus.rejected;
      case 'mayRemove':
        return PostStatus.mayRemove;
      case 'removed':
        return PostStatus.removed;
      default:
        return PostStatus.pendingPost;
    }
  }

  static SocialPlatform _parsePlatform(String? s) {
    switch (s) {
      case 'instagram':
        return SocialPlatform.instagram;
      case 'youtube':
        return SocialPlatform.youtube;
      case 'twitter':
        return SocialPlatform.twitter;
      case 'linkedin':
        return SocialPlatform.linkedin;
      default:
        return SocialPlatform.other;
    }
  }

  bool get isPastMandatoryStay =>
      DateTime.now().isAfter(mustStayUntil);

  /// Earnings for this post based on views
  /// (payoutRatePer1000 is injected from campaign)
  int earningsFor(int payoutRatePer1000) {
    return (views / 1000 * payoutRatePer1000).floor();
  }

  String get statusLabel {
    switch (status) {
      case PostStatus.pendingPost:
        return 'Pending Post';
      case PostStatus.pendingReview:
        return 'Under Review';
      case PostStatus.approved:
        return 'Approved';
      case PostStatus.rejected:
        return 'Rejected';
      case PostStatus.mayRemove:
        return 'May Remove';
      case PostStatus.removed:
        return 'Removed';
    }
  }
}
