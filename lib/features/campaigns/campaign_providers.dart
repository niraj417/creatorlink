import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/firebase_providers.dart';
import '../../core/providers/user_provider.dart';
import '../../shared/models/campaign_model.dart';

/// All active campaigns (for creator home/list) — paginated
final activeCampaignsProvider = FutureProvider<List<CampaignModel>>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  final snap = await firestore
      .collection('campaigns')
      .where('status', isEqualTo: 'active')
      .orderBy('createdAt', descending: true)
      .limit(20)
      .get();
  return snap.docs.map((d) => CampaignModel.fromFirestore(d)).toList();
});

/// Brand's own campaigns
final brandCampaignsProvider = FutureProvider<List<CampaignModel>>((ref) async {
  final user = ref.watch(currentUserDataProvider).value;
  if (user == null) return [];
  final firestore = ref.watch(firestoreProvider);
  final snap = await firestore
      .collection('campaigns')
      .where('brandUid', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .get();
  return snap.docs.map((d) => CampaignModel.fromFirestore(d)).toList();
});

/// Single campaign by ID
final campaignByIdProvider =
    FutureProvider.family<CampaignModel?, String>((ref, id) async {
  final firestore = ref.watch(firestoreProvider);
  final doc = await firestore.collection('campaigns').doc(id).get();
  if (!doc.exists) return null;
  return CampaignModel.fromFirestore(doc);
});

/// Stream of single campaign (for real-time dashboard)
final campaignStreamProvider =
    StreamProvider.family<CampaignModel?, String>((ref, id) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('campaigns')
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? CampaignModel.fromFirestore(doc) : null);
});

/// All campaigns — admin view
final allCampaignsAdminProvider =
    FutureProvider<List<CampaignModel>>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  final snap = await firestore
      .collection('campaigns')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .get();
  return snap.docs.map((d) => CampaignModel.fromFirestore(d)).toList();
});

/// Posts for a campaign — for brand dashboard
final campaignPostsProvider =
    FutureProvider.family<List<QueryDocumentSnapshot>, String>((ref, cid) async {
  final firestore = ref.watch(firestoreProvider);
  final snap = await firestore
      .collection('posts')
      .where('campaignId', isEqualTo: cid)
      .orderBy('submittedAt', descending: true)
      .get();
  return snap.docs;
});
