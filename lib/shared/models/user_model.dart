import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { creator, brand, admin, unknown }

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String photoURL;
  final UserRole role;
  final OnboardingData? onboarding;
  final DateTime createdAt;
  final bool banned;
  final int walletPoints; // 1 point = ₹1

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoURL,
    required this.role,
    this.onboarding,
    required this.createdAt,
    this.banned = false,
    this.walletPoints = 0,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      photoURL: data['photoURL'] ?? '',
      role: _parseRole(data['role']),
      onboarding: data['onboarding'] != null
          ? OnboardingData.fromMap(data['onboarding'] as Map<String, dynamic>)
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      banned: data['banned'] ?? false,
      walletPoints: data['walletPoints'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'role': role.name,
      'onboarding': onboarding?.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'banned': banned,
      'walletPoints': walletPoints,
    };
  }

  UserModel copyWith({
    String? displayName,
    String? photoURL,
    UserRole? role,
    OnboardingData? onboarding,
    bool? banned,
    int? walletPoints,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      role: role ?? this.role,
      onboarding: onboarding ?? this.onboarding,
      createdAt: createdAt,
      banned: banned ?? this.banned,
      walletPoints: walletPoints ?? this.walletPoints,
    );
  }

  static UserRole _parseRole(String? role) {
    switch (role) {
      case 'creator':
        return UserRole.creator;
      case 'brand':
        return UserRole.brand;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.unknown;
    }
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isCreator => role == UserRole.creator;
  bool get isBrand => role == UserRole.brand;
  bool get needsOnboarding => role == UserRole.unknown || onboarding == null;

  String get roleLabel {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.brand:
        return 'Brand';
      case UserRole.creator:
        return 'Creator';
      default:
        return 'User';
    }
  }

  /// Check admin by email (fallback for bootstrap)
  bool get isAdminByEmail => email == 'kingniraj417@gmail.com';
}

class OnboardingData {
  final String? heardAboutUs; // instagram, youtube, friend, other
  final List<String> usageReasons; // multi-select chips
  final String? platforms; // for creator: comma-separated
  final String? monthlyReach; // for creator: dropdown value
  final String? companyName; // for brand
  final String? industry; // for brand
  final String? budgetRange; // for brand
  final int followers; // for creator
  final Map<String, String> socialLinks; // platform -> url
  final DateTime completedAt;

  const OnboardingData({
    this.heardAboutUs,
    this.usageReasons = const [],
    this.platforms,
    this.monthlyReach,
    this.companyName,
    this.industry,
    this.budgetRange,
    this.followers = 0,
    this.socialLinks = const {},
    required this.completedAt,
  });

  factory OnboardingData.fromMap(Map<String, dynamic> map) {
    return OnboardingData(
      heardAboutUs: map['heardAboutUs'],
      usageReasons: List<String>.from(map['usageReasons'] ?? []),
      platforms: map['platforms'],
      monthlyReach: map['monthlyReach'],
      companyName: map['companyName'],
      industry: map['industry'],
      budgetRange: map['budgetRange'],
      followers: (map['followers'] as num?)?.toInt() ?? 0,
      socialLinks: Map<String, String>.from(map['socialLinks'] ?? {}),
      completedAt:
          (map['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'heardAboutUs': heardAboutUs,
      'usageReasons': usageReasons,
      'platforms': platforms,
      'monthlyReach': monthlyReach,
      'companyName': companyName,
      'industry': industry,
      'budgetRange': budgetRange,
      'followers': followers,
      'socialLinks': socialLinks,
      'completedAt': Timestamp.fromDate(completedAt),
    };
  }
}
