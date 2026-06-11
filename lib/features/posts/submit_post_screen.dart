
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/firebase_providers.dart';
import '../../core/providers/user_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../shared/models/post_model.dart';
import '../../shared/widgets/glowy_card.dart';


class SubmitPostScreen extends ConsumerStatefulWidget {
  final String campaignId;
  const SubmitPostScreen({super.key, required this.campaignId});

  @override
  ConsumerState<SubmitPostScreen> createState() => _SubmitPostScreenState();
}

class _SubmitPostScreenState extends ConsumerState<SubmitPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _viewsController = TextEditingController();
  final _reachController = TextEditingController();
  final _interactionsController = TextEditingController();
  String _platform = 'instagram';
  String? _screenshotUrl;
  bool _isUploading = false;
  bool _isSubmitting = false;
  double _uploadProgress = 0.0;

  @override
  void dispose() {
    _urlController.dispose();
    _viewsController.dispose();
    _reachController.dispose();
    _interactionsController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final storage = ref.read(firebaseStorageProvider);
      final uid = ref.read(currentUserDataProvider).value?.uid ?? 'unknown';
      final fileName = '${const Uuid().v4()}.${file.extension ?? 'jpg'}';
      final ref_ = storage.ref('posts/$uid/screenshots/$fileName');

      final task = ref_.putData(
        file.bytes!,
        SettableMetadata(contentType: 'image/${file.extension ?? 'jpeg'}'),
      );
      task.snapshotEvents.listen((s) {
        setState(() => _uploadProgress = s.bytesTransferred / s.totalBytes);
      });

      final snap = await task;
      final url = await snap.ref.getDownloadURL();
      setState(() {
        _screenshotUrl = url;
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final firestore = ref.read(firestoreProvider);
      final user = ref.read(currentUserDataProvider).value;
      if (user == null) throw Exception('Not logged in');

      final now = DateTime.now();
      final views = int.tryParse(_viewsController.text) ?? 0;
      final reach = int.tryParse(_reachController.text) ?? 0;
      final interactions = int.tryParse(_interactionsController.text) ?? 0;

      // Find the pending post for this campaign/creator
      final existingQuery = await firestore
          .collection('posts')
          .where('creatorUid', isEqualTo: user.uid)
          .where('campaignId', isEqualTo: widget.campaignId)
          .where('status', isEqualTo: 'pendingPost')
          .limit(1)
          .get();

      final batch = firestore.batch();
      final campaignRef =
          firestore.collection('campaigns').doc(widget.campaignId);

      if (existingQuery.docs.isNotEmpty) {
        // Re-submission: subtract OLD values from campaign metrics first,
        // then add new values so we never double-count.
        final oldPost = PostModel.fromFirestore(existingQuery.docs.first);
        final postRef = existingQuery.docs.first.reference;

        batch.update(postRef, {
          'postUrl': _urlController.text.trim(),
          'screenshotUrl': _screenshotUrl,
          'platform': _platform,
          'status': 'pendingReview',
          'views': views,
          'reach': reach,
          'interactions': interactions,
          'submittedAt': Timestamp.fromDate(now),
          'mustStayUntil':
              Timestamp.fromDate(now.add(const Duration(days: 10))),
          'dailyViewHistory': {
            _dateKey(now): views,
          },
        });

        // Net delta so metrics don't drift on re-submit
        final viewDelta = views - oldPost.views;
        final reachDelta = reach - oldPost.reach;
        final interactionDelta = interactions - oldPost.interactions;
        batch.update(campaignRef, {
          'metrics.totalViews': FieldValue.increment(viewDelta),
          'metrics.totalReach': FieldValue.increment(reachDelta),
          'metrics.totalInteractions': FieldValue.increment(interactionDelta),
        });
      } else {
        // New post document
        final newPostRef = firestore.collection('posts').doc();
        batch.set(newPostRef, {
          'creatorUid': user.uid,
          'campaignId': widget.campaignId,
          'postUrl': _urlController.text.trim(),
          'screenshotUrl': _screenshotUrl,
          'platform': _platform,
          'status': 'pendingReview',
          'views': views,
          'reach': reach,
          'interactions': interactions,
          'flagged': false,
          'flagReason': null,
          'submittedAt': Timestamp.fromDate(now),
          'mustStayUntil':
              Timestamp.fromDate(now.add(const Duration(days: 10))),
          'creatorName': user.displayName,
          'creatorPhotoUrl': user.photoURL,
          'campaignName': null, // fetched from campaign
          'dailyViewHistory': {
            _dateKey(now): views,
          },
        });

        // Increment campaign metrics
        batch.update(campaignRef, {
          'metrics.totalViews': FieldValue.increment(views),
          'metrics.totalReach': FieldValue.increment(reach),
          'metrics.totalInteractions': FieldValue.increment(interactions),
        });
      }

      await batch.commit();

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Post submitted for review!'),
        ),
      );
      context.pop();
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }


  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Submit Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              GlowyCard(
                glowColor: AppColors.accentViolet.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.accentViolet, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Post your content on your social platform first, then submit the link here.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(),

              const SizedBox(height: 20),

              // Platform selector
              Text('Platform', style: AppTextStyles.titleMedium),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'instagram', 'youtube', 'twitter', 'linkedin',
                  ].map((p) {
                    final isSelected = _platform == p;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _platform = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accentViolet.withValues(alpha: 0.15)
                                : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.accentViolet
                                  : AppColors.glassBorder,
                            ),
                          ),
                          child: Text(
                            p[0].toUpperCase() + p.substring(1),
                            style: AppTextStyles.labelLarge.copyWith(
                              color: isSelected
                                  ? AppColors.accentViolet
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // Post URL
              Text('Post URL *', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _urlController,
                validator: Validators.url,
                decoration: const InputDecoration(
                  hintText: 'https://instagram.com/p/...',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
                keyboardType: TextInputType.url,
              ),

              const SizedBox(height: 20),

              // View stats
              Text('View Statistics', style: AppTextStyles.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Enter the current stats shown on your post.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _viewsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Views *',
                        prefixIcon: Icon(Icons.visibility_outlined, size: 18),
                      ),
                      validator: Validators.positiveInt,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _reachController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Reach',
                        prefixIcon: Icon(Icons.people_outline, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _interactionsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Likes / Comments / Interactions',
                  prefixIcon: Icon(Icons.favorite_outline, size: 18),
                ),
              ),

              const SizedBox(height: 20),

              // Screenshot upload
              Text('Screenshot (Optional)', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _isUploading ? null : _pickScreenshot,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: _isUploading
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            LinearProgressIndicator(value: _uploadProgress),
                            const SizedBox(height: 8),
                            Text('Uploading...', style: AppTextStyles.bodySmall),
                          ],
                        )
                      : _screenshotUrl != null
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: AppColors.accentGreen),
                                const SizedBox(width: 8),
                                Text('Screenshot uploaded',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.accentGreen)),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.image_outlined,
                                    color: AppColors.accentViolet),
                                const SizedBox(width: 8),
                                Text('Tap to upload screenshot',
                                    style: AppTextStyles.bodyMedium),
                              ],
                            ),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitPost,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit Post for Review'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
