import 'package:cloud_firestore/cloud_firestore.dart';

enum CampaignStatus { active, paused, full, ended }

class CampaignModel {
  final String id;
  final String brandUid;
  final String name;
  final String description;
  final String guidelines;
  final List<String> assetUrls;
  final int budget; // in rupees
  final int walletBalance; // in rupees (held funds)
  final int payoutRatePer1000; // ₹ per 1000 views
  final int minFollowers;
  final CampaignStatus status;
  final DateTime createdAt;
  final CampaignMetrics metrics;
  final String? brandName;
  final String? brandLogoUrl;
  final List<String> nicheTags;

  const CampaignModel({
    required this.id,
    required this.brandUid,
    required this.name,
    required this.description,
    required this.guidelines,
    this.assetUrls = const [],
    required this.budget,
    required this.walletBalance,
    required this.payoutRatePer1000,
    this.minFollowers = 0,
    this.status = CampaignStatus.active,
    required this.createdAt,
    this.metrics = const CampaignMetrics(),
    this.brandName,
    this.brandLogoUrl,
    this.nicheTags = const [],
  });

  factory CampaignModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CampaignModel(
      id: doc.id,
      brandUid: data['brandUid'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      guidelines: data['guidelines'] ?? '',
      assetUrls: List<String>.from(data['assetUrls'] ?? []),
      budget: (data['budget'] ?? 0) as int,
      walletBalance: (data['walletBalance'] ?? 0) as int,
      payoutRatePer1000: (data['payoutRatePer1000'] ?? 0) as int,
      minFollowers: (data['minFollowers'] ?? 0) as int,
      status: _parseStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metrics: data['metrics'] != null
          ? CampaignMetrics.fromMap(data['metrics'] as Map<String, dynamic>)
          : const CampaignMetrics(),
      brandName: data['brandName'],
      brandLogoUrl: data['brandLogoUrl'],
      nicheTags: List<String>.from(data['nicheTags'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'brandUid': brandUid,
      'name': name,
      'description': description,
      'guidelines': guidelines,
      'assetUrls': assetUrls,
      'budget': budget,
      'walletBalance': walletBalance,
      'payoutRatePer1000': payoutRatePer1000,
      'minFollowers': minFollowers,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'metrics': metrics.toMap(),
      'brandName': brandName,
      'brandLogoUrl': brandLogoUrl,
      'nicheTags': nicheTags,
    };
  }

  CampaignModel copyWith({
    String? name,
    String? description,
    String? guidelines,
    List<String>? assetUrls,
    int? budget,
    int? walletBalance,
    int? payoutRatePer1000,
    int? minFollowers,
    CampaignStatus? status,
    CampaignMetrics? metrics,
    String? brandName,
    String? brandLogoUrl,
    List<String>? nicheTags,
  }) {
    return CampaignModel(
      id: id,
      brandUid: brandUid,
      name: name ?? this.name,
      description: description ?? this.description,
      guidelines: guidelines ?? this.guidelines,
      assetUrls: assetUrls ?? this.assetUrls,
      budget: budget ?? this.budget,
      walletBalance: walletBalance ?? this.walletBalance,
      payoutRatePer1000: payoutRatePer1000 ?? this.payoutRatePer1000,
      minFollowers: minFollowers ?? this.minFollowers,
      status: status ?? this.status,
      createdAt: createdAt,
      metrics: metrics ?? this.metrics,
      brandName: brandName ?? this.brandName,
      brandLogoUrl: brandLogoUrl ?? this.brandLogoUrl,
      nicheTags: nicheTags ?? this.nicheTags,
    );
  }

  static CampaignStatus _parseStatus(String? s) {
    switch (s) {
      case 'active':
        return CampaignStatus.active;
      case 'paused':
        return CampaignStatus.paused;
      case 'full':
        return CampaignStatus.full;
      case 'ended':
        return CampaignStatus.ended;
      default:
        return CampaignStatus.active;
    }
  }

  /// Budget remaining as percentage (0.0 – 1.0)
  double get budgetRemainingPercent {
    if (budget <= 0) return 0.0;
    return (walletBalance / budget).clamp(0.0, 1.0);
  }

  /// Days since creation (for display)
  int get daysActive => DateTime.now().difference(createdAt).inDays;

  bool get isActive => status == CampaignStatus.active;
}

class CampaignMetrics {
  final int totalViews;
  final int totalReach;
  final int totalInteractions;
  final int flaggedPosts;

  const CampaignMetrics({
    this.totalViews = 0,
    this.totalReach = 0,
    this.totalInteractions = 0,
    this.flaggedPosts = 0,
  });

  factory CampaignMetrics.fromMap(Map<String, dynamic> map) {
    return CampaignMetrics(
      totalViews: (map['totalViews'] ?? 0) as int,
      totalReach: (map['totalReach'] ?? 0) as int,
      totalInteractions: (map['totalInteractions'] ?? 0) as int,
      flaggedPosts: (map['flaggedPosts'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalViews': totalViews,
      'totalReach': totalReach,
      'totalInteractions': totalInteractions,
      'flaggedPosts': flaggedPosts,
    };
  }

  int get budgetSpent => 0; // computed from transactions
}
