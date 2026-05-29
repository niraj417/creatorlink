import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/glowy_card.dart';

class CampaignCreateWizard extends ConsumerStatefulWidget {
  const CampaignCreateWizard({super.key});

  @override
  ConsumerState<CampaignCreateWizard> createState() =>
      _CampaignCreateWizardState();
}

class _CampaignCreateWizardState extends ConsumerState<CampaignCreateWizard> {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false;
  late Razorpay _razorpay;

  // Step 1
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  // Step 2
  final _guidelinesController = TextEditingController();
  String? _guidelinePdfUrl;

  // Step 3 — assets
  final _uploadedAssetUrls = <String>[];
  final _uploadProgress = <String, double>{};

  // Step 4 — budget
  final _budgetController = TextEditingController();
  final _payoutRateController = TextEditingController();
  final _minFollowersController = TextEditingController(text: '0');
  final _nicheTags = <String>[];
  final _tagController = TextEditingController();

  // Step 5 — review
  String? _campaignId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _guidelinesController.dispose();
    _budgetController.dispose();
    _payoutRateController.dispose();
    _minFollowersController.dispose();
    _tagController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // Credit walletBalance in Firestore after successful payment
    try {
      final firestore = ref.read(firestoreProvider);
      final budget = int.tryParse(_budgetController.text.replaceAll(',', '')) ?? 0;

      await firestore.collection('campaigns').doc(_campaignId).update({
        'walletBalance': budget,
        'status': 'active',
      });

      // Record transaction
      final user = ref.read(currentUserDataProvider).value;
      await firestore.collection('transactions').add({
        'type': 'topup',
        'uid': user?.uid,
        'amount': budget,
        'relatedId': _campaignId,
        'note': 'Campaign wallet top-up via Razorpay',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Campaign created and funded!')),
      );
      context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message}')),
    );
  }

  Future<void> _uploadFile(PlatformFile file) async {
    final storage = ref.read(firebaseStorageProvider);
    final uid = ref.read(currentUserDataProvider).value?.uid ?? 'unknown';
    final ext = file.extension ?? 'bin';
    final fileName = '${const Uuid().v4()}.$ext';
    final ref_ = storage.ref('campaigns/$uid/assets/$fileName');

    final metadata = SettableMetadata(contentType: _mimeType(ext));
    final task = ref_.putData(file.bytes!, metadata);

    setState(() => _uploadProgress[file.name] = 0.0);

    task.snapshotEvents.listen((snap) {
      final progress = snap.bytesTransferred / snap.totalBytes;
      setState(() => _uploadProgress[file.name] = progress);
    });

    final url = await (await task).ref.getDownloadURL();
    setState(() {
      _uploadedAssetUrls.add(url);
      _uploadProgress.remove(file.name);
    });
  }

  String _mimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'mp4':
        return 'video/mp4';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'svg':
        return 'image/svg+xml';
      case 'pdf':
        return 'application/pdf';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _pickAndUploadFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mp4', 'png', 'jpg', 'jpeg', 'svg', 'pdf', 'mp3'],
      withData: true,
    );
    if (result == null) return;
    for (final file in result.files) {
      await _uploadFile(file);
    }
  }

  Future<void> _createCampaignDraft() async {
    setState(() => _isSaving = true);
    try {
      final firestore = ref.read(firestoreProvider);
      final user = ref.read(currentUserDataProvider).value;
      if (user == null) throw Exception('Not logged in');

      final budget = int.tryParse(_budgetController.text.replaceAll(',', '')) ?? 0;
      final payoutRate = int.tryParse(_payoutRateController.text) ?? 0;
      final minFollowers = int.tryParse(_minFollowersController.text) ?? 0;

      final docRef = await firestore.collection('campaigns').add({
        'brandUid': user.uid,
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'guidelines': _guidelinesController.text.trim(),
        'assetUrls': _uploadedAssetUrls,
        'budget': budget,
        'walletBalance': 0, // funded after payment
        'payoutRatePer1000': payoutRate,
        'minFollowers': minFollowers,
        'status': 'draft',
        'createdAt': FieldValue.serverTimestamp(),
        'nicheTags': _nicheTags,
        'brandName': user.onboarding?.companyName ?? user.displayName,
        'brandLogoUrl': user.photoURL,
        'metrics': {
          'totalViews': 0,
          'totalReach': 0,
          'totalInteractions': 0,
          'flaggedPosts': 0,
        },
      });

      _campaignId = docRef.id;
      setState(() => _isSaving = false);
      _openRazorpay(budget, user.email, user.displayName);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _openRazorpay(int amount, String email, String name) {
    // Note: amount must be in paise
    final options = {
      'key': 'rzp_test_PLACEHOLDER', // Replace with Firebase Remote Config value
      'amount': amount * 100,
      'name': 'CreatorLink',
      'description': 'Campaign Wallet Funding',
      'prefill': {
        'contact': '',
        'email': email,
        'name': name,
      },
      'theme': {'color': '#7B61FF'},
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay error: $e');
    }
  }

  bool _canProceedStep() {
    switch (_currentStep) {
      case 0:
        return _nameController.text.trim().isNotEmpty &&
            _descController.text.trim().isNotEmpty &&
            _descController.text.length <= 500;
      case 1:
        return _guidelinesController.text.trim().isNotEmpty;
      case 2:
        return true; // assets optional
      case 3:
        final budget = int.tryParse(_budgetController.text.replaceAll(',', ''));
        final payout = int.tryParse(_payoutRateController.text);
        return budget != null && budget >= 1000 && payout != null && payout > 0;
      case 4:
        return true;
      default:
        return false;
    }
  }

  void _next() {
    if (_currentStep < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _createCampaignDraft();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Create Campaign'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Step progress
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: List.generate(5, (i) {
                    final active = i <= _currentStep;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < 4 ? 4 : 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 3,
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.accentViolet
                                : AppColors.glassBorder,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _stepTitle(_currentStep),
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentStep = i),
              children: [
                _Step1(nameCtrl: _nameController, descCtrl: _descController),
                _Step2(guidelinesCtrl: _guidelinesController),
                _Step3(
                  assetUrls: _uploadedAssetUrls,
                  uploadProgress: _uploadProgress,
                  onPickFiles: _pickAndUploadFiles,
                ),
                _Step4(
                  budgetCtrl: _budgetController,
                  payoutCtrl: _payoutRateController,
                  minFollowersCtrl: _minFollowersController,
                  nicheTags: _nicheTags,
                  tagCtrl: _tagController,
                  onAddTag: () {
                    final tag = _tagController.text.trim();
                    if (tag.isNotEmpty && !_nicheTags.contains(tag)) {
                      setState(() {
                        _nicheTags.add(tag);
                        _tagController.clear();
                      });
                    }
                  },
                  onRemoveTag: (tag) => setState(() => _nicheTags.remove(tag)),
                ),
                _Step5(
                  name: _nameController.text,
                  budget: _budgetController.text,
                  payoutRate: _payoutRateController.text,
                  assetCount: _uploadedAssetUrls.length,
                ),
              ],
            ),
          ),

          // CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: OutlinedButton(
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canProceedStep() && !_isSaving ? _next : null,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_currentStep < 4
                            ? 'Continue'
                            : 'Pay & Launch Campaign'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _stepTitle(int step) {
    const titles = [
      'Step 1/5 — Basic Info',
      'Step 2/5 — Brand Guidelines',
      'Step 3/5 — Upload Assets',
      'Step 4/5 — Budget Setup',
      'Step 5/5 — Review & Pay',
    ];
    return titles[step];
  }
}

// ─── Wizard Steps ─────────────────────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;

  const _Step1({required this.nameCtrl, required this.descCtrl});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Campaign Info', style: AppTextStyles.titleLarge)
              .animate().fadeIn(),
          const SizedBox(height: 20),
          TextFormField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Campaign Name *',
              prefixIcon: Icon(Icons.campaign_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: descCtrl,
            maxLines: 5,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Description *',
              hintText: 'Describe the campaign objectives...',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Step2 extends StatelessWidget {
  final TextEditingController guidelinesCtrl;

  const _Step2({required this.guidelinesCtrl});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Brand Guidelines', style: AppTextStyles.titleLarge)
              .animate().fadeIn(),
          const SizedBox(height: 8),
          Text(
            'Specify dos & don\'ts, tone of voice, hashtags, and any other requirements.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: guidelinesCtrl,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Brand Guidelines *',
              hintText:
                  'Example:\n• Use hashtag #BrandName\n• Show product clearly\n• Avoid competitor mentions',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Step3 extends StatelessWidget {
  final List<String> assetUrls;
  final Map<String, double> uploadProgress;
  final VoidCallback onPickFiles;

  const _Step3({
    required this.assetUrls,
    required this.uploadProgress,
    required this.onPickFiles,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upload Assets', style: AppTextStyles.titleLarge).animate().fadeIn(),
          const SizedBox(height: 8),
          Text('Upload reference videos, images, logos, or audio.',
              style: AppTextStyles.bodyMedium),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onPickFiles,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accentViolet.withOpacity(0.4),
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_upload_outlined,
                        color: AppColors.accentViolet, size: 36),
                    const SizedBox(height: 8),
                    Text('Tap to upload files', style: AppTextStyles.bodyMedium),
                    Text('MP4, PNG, SVG, PDF, MP3',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Upload progress bars
          ...uploadProgress.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key, style: AppTextStyles.bodySmall),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: entry.value),
                  ],
                ),
              )),
          // Uploaded files
          if (assetUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Uploaded (${assetUrls.length})',
                style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.accentGreen)),
            const SizedBox(height: 8),
            ...assetUrls.map((url) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 16, color: AppColors.accentGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          url.split('/').last.split('?').first,
                          style: AppTextStyles.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _Step4 extends StatelessWidget {
  final TextEditingController budgetCtrl;
  final TextEditingController payoutCtrl;
  final TextEditingController minFollowersCtrl;
  final List<String> nicheTags;
  final TextEditingController tagCtrl;
  final VoidCallback onAddTag;
  final ValueChanged<String> onRemoveTag;

  const _Step4({
    required this.budgetCtrl,
    required this.payoutCtrl,
    required this.minFollowersCtrl,
    required this.nicheTags,
    required this.tagCtrl,
    required this.onAddTag,
    required this.onRemoveTag,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Budget Setup', style: AppTextStyles.titleLarge).animate().fadeIn(),
          const SizedBox(height: 20),
          TextFormField(
            controller: budgetCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Total Budget (₹) *',
              prefixIcon: Icon(Icons.currency_rupee),
              hintText: 'Minimum ₹1,000',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: payoutCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Payout Rate (₹ per 1,000 views) *',
              prefixIcon: Icon(Icons.visibility_outlined),
              hintText: 'e.g. 50',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: minFollowersCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Minimum Followers',
              prefixIcon: Icon(Icons.people_outline),
              hintText: '0 = no minimum',
            ),
          ),
          const SizedBox(height: 20),
          Text('Niche Tags', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: tagCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Add tag (e.g. Fashion)',
                  ),
                  onFieldSubmitted: (_) => onAddTag(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onAddTag,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                child: const Icon(Icons.add_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: nicheTags.map((tag) {
              return Chip(
                label: Text(tag),
                deleteIcon: const Icon(Icons.close_rounded, size: 14),
                onDeleted: () => onRemoveTag(tag),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _Step5 extends StatelessWidget {
  final String name;
  final String budget;
  final String payoutRate;
  final int assetCount;

  const _Step5({
    required this.name,
    required this.budget,
    required this.payoutRate,
    required this.assetCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review & Pay', style: AppTextStyles.titleLarge).animate().fadeIn(),
          const SizedBox(height: 8),
          Text('A Razorpay checkout will open to fund the campaign wallet.',
              style: AppTextStyles.bodyMedium),
          const SizedBox(height: 24),
          GlowyCard(
            glowColor: AppColors.accentViolet.withOpacity(0.15),
            child: Column(
              children: [
                _ReviewRow('Campaign', name),
                const Divider(color: AppColors.glassBorder),
                _ReviewRow('Total Budget', '₹$budget'),
                const Divider(color: AppColors.glassBorder),
                _ReviewRow('Payout Rate', '₹$payoutRate per 1K views'),
                const Divider(color: AppColors.glassBorder),
                _ReviewRow('Assets', '$assetCount file(s) uploaded'),
              ],
            ),
          ).animate(delay: 150.ms).fadeIn(),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accentAmber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accentAmber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.accentAmber, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Funds are held securely in your campaign wallet. You can top up or pause anytime.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.accentAmber),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReviewRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium),
          Text(value, style: AppTextStyles.labelLarge),
        ],
      ),
    );
  }
}
