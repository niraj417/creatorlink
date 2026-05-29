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
import '../../shared/widgets/glowy_card.dart';

class AppealScreen extends ConsumerStatefulWidget {
  final String postId;
  const AppealScreen({super.key, required this.postId});

  @override
  ConsumerState<AppealScreen> createState() => _AppealScreenState();
}

class _AppealScreenState extends ConsumerState<AppealScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  String? _screenshotUrl;
  bool _isUploading = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
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

    setState(() => _isUploading = true);
    try {
      final storage = ref.read(firebaseStorageProvider);
      final uid = ref.read(currentUserDataProvider).value?.uid ?? 'unknown';
      final fileName = '${const Uuid().v4()}.${file.extension ?? 'jpg'}';
      final storageRef = storage.ref('appeals/$uid/$fileName');
      await storageRef.putData(file.bytes!);
      final url = await storageRef.getDownloadURL();
      setState(() {
        _screenshotUrl = url;
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _submitAppeal() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final firestore = ref.read(firestoreProvider);
      final user = ref.read(currentUserDataProvider).value;
      if (user == null) throw Exception('Not logged in');

      await firestore.collection('appeals').add({
        'creatorUid': user.uid,
        'postId': widget.postId,
        'reason': _reasonController.text.trim(),
        'screenshotUrl': _screenshotUrl,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'resolvedAt': null,
        'resolverNote': null,
        'creatorName': user.displayName,
        'postUrl': null, // enriched by Cloud Function
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🙏 Appeal submitted! We\'ll review it shortly.'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Appeal Flag')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card
              GlowyCard(
                glowColor: AppColors.accentAmber.withOpacity(0.1),
                child: Row(
                  children: [
                    const Icon(Icons.gavel_rounded,
                        color: AppColors.accentAmber, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Explain why you believe this flag was made in error. Our team will review within 48 hours.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(),

              const SizedBox(height: 24),

              Text('Reason for Appeal *', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                maxLines: 5,
                maxLength: 500,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Reason is required';
                  if (v.trim().length < 20) {
                    return 'Please provide at least 20 characters';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  hintText:
                      'Explain in detail why you believe the flag is incorrect...',
                  alignLabelWithHint: true,
                ),
              ).animate(delay: 100.ms).fadeIn(),

              const SizedBox(height: 16),

              Text('Evidence Screenshot (Optional)', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _isUploading ? null : _pickScreenshot,
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Center(
                    child: _isUploading
                        ? const CircularProgressIndicator()
                        : _screenshotUrl != null
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      color: AppColors.accentGreen, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Screenshot uploaded',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                          color: AppColors.accentGreen)),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.upload_rounded,
                                      color: AppColors.accentViolet, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Upload evidence screenshot',
                                      style: AppTextStyles.bodyMedium),
                                ],
                              ),
                  ),
                ),
              ).animate(delay: 150.ms).fadeIn(),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitAppeal,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit Appeal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
