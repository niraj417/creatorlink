import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../shared/models/user_model.dart';
import 'firebase_providers.dart';

/// Stream of current user's Firestore document
final currentUserDataProvider = StreamProvider<UserModel?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);

  return auth.authStateChanges().asyncExpand((user) {
    if (user == null) return Stream.value(null);
    return firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  });
});

/// Current user's role
final userRoleProvider = Provider<UserRole>((ref) {
  return ref.watch(currentUserDataProvider).value?.role ?? UserRole.unknown;
});

/// Whether current user is admin
final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserDataProvider).value;
  return user?.isAdmin ?? false;
});

/// Fetch a user by UID (for admin panel)
final userByIdProvider =
    FutureProvider.family<UserModel?, String>((ref, uid) async {
  final firestore = ref.watch(firestoreProvider);
  final doc = await firestore.collection('users').doc(uid).get();
  if (!doc.exists) return null;
  return UserModel.fromFirestore(doc);
});

// ─── Auth Notifier ────────────────────────────────────────────────────────────
class AuthNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<UserCredential?> signInWithGoogle() async {
    final auth = ref.read(firebaseAuthProvider);
    final googleSignIn = GoogleSignIn();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await auth.signInWithCredential(credential);

    // Create or update user doc
    final firestore = ref.read(firestoreProvider);
    final user = userCred.user!;
    final userRef = firestore.collection('users').doc(user.uid);
    final doc = await userRef.get();

    if (!doc.exists) {
      // Determine if admin
      final role = user.email == 'kingniraj417@gmail.com'
          ? UserRole.admin
          : UserRole.unknown;

      await userRef.set({
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'photoURL': user.photoURL ?? '',
        'role': role.name,
        'onboarding': null,
        'createdAt': FieldValue.serverTimestamp(),
        'banned': false,
        'walletPoints': 0,
      });
    } else {
      // Update display info
      await userRef.update({
        'displayName': user.displayName ?? '',
        'photoURL': user.photoURL ?? '',
      });
    }

    return userCred;
  }

  Future<void> signOut() async {
    final auth = ref.read(firebaseAuthProvider);
    await GoogleSignIn().signOut();
    await auth.signOut();
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, void>(AuthNotifier.new);

