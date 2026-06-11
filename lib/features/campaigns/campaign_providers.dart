import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/firebase_providers.dart';
import '../../core/providers/user_provider.dart';
import '../../shared/models/campaign_model.dart';
import '../../shared/models/post_model.dart';

/// Current creator's own posts (all statuses) — real-time stream
final creatorPostsProvider = StreamProvider<List<PostModel>>((ref) {
  final user = ref.watch(currentUserDataProvider).value;
  if (user == null) return const Stream.empty();
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('posts')
      .where('creatorUid', isEqualTo: user.uid)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => PostModel.fromFirestore(d)).toList());
});


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

/// Posts for a campaign — for brand dashboard (real-time stream so analytics
/// update the moment a creator submits or updates their post)
final campaignPostsProvider =
    StreamProvider.family<List<QueryDocumentSnapshot>, String>((ref, cid) {
  final firestore = ref.watch(firestoreProvider);
  // Do NOT orderBy 'submittedAt' — pendingPost docs have submittedAt: null
  // and Firestore drops them from ordered queries. Sort client-side instead.
  return firestore
      .collection('posts')
      .where('campaignId', isEqualTo: cid)
      .snapshots()
      .map((snap) {
        final docs = snap.docs.toList();
        // Sort: most recent submittedAt first (nulls at end)
        docs.sort((a, b) {
          final aTs = a.data()['submittedAt'];
          final bTs = b.data()['submittedAt'];
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return (bTs as dynamic).compareTo(aTs as dynamic);
        });
        return docs;
      });
});

