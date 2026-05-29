import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Firebase Instances ───────────────────────────────────────────────────────

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  final firestore = FirebaseFirestore.instance;
  // Enable offline persistence
  firestore.settings = const Settings(persistenceEnabled: true);
  return firestore;
});

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

// ─── Auth State ───────────────────────────────────────────────────────────────

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

// ─── Firestore Collection References ─────────────────────────────────────────

final usersCollectionProvider = Provider<CollectionReference>((ref) {
  return ref.watch(firestoreProvider).collection('users');
});

final campaignsCollectionProvider = Provider<CollectionReference>((ref) {
  return ref.watch(firestoreProvider).collection('campaigns');
});

final postsCollectionProvider = Provider<CollectionReference>((ref) {
  return ref.watch(firestoreProvider).collection('posts');
});

final appealsCollectionProvider = Provider<CollectionReference>((ref) {
  return ref.watch(firestoreProvider).collection('appeals');
});

final withdrawalsCollectionProvider = Provider<CollectionReference>((ref) {
  return ref.watch(firestoreProvider).collection('withdrawal_requests');
});

final transactionsCollectionProvider = Provider<CollectionReference>((ref) {
  return ref.watch(firestoreProvider).collection('transactions');
});

final notificationsCollectionProvider = Provider<CollectionReference>((ref) {
  return ref.watch(firestoreProvider).collection('notifications');
});
