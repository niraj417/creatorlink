import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/firebase_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glowy_card.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  // Step 1: How did you hear about us?
  String? _heardAboutUs;
  final _heardOptions = ['Instagram', 'YouTube', 'Friend', 'Other'];

  // Step 2: Why using CreatorLink?
  final _usageReasons = <String>{};
  final _reasonOptions = [
    'Earn from content',
    'Grow my brand',
    'Find creators',
    'Run campaigns',
    'Build portfolio',
    'Collaborate',
  ];

  // Step 3: Role selection
  String? _selectedRole; // 'creator' | 'brand'

  // Step 4 Creator
  final _platforms = <String>{};
  String? _monthlyReach;

  // Step 4 Brand
  final _companyController = TextEditingController();
  String? _industry;
  String? _budgetRange;

  @override
  void dispose() {
    _pageController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _saveAndFinish();
    }
  }

  bool _canProceed() {
    switch (_currentPage) {
      case 0:
        return _heardAboutUs != null;
      case 1:
        return _usageReasons.isNotEmpty;
      case 2:
        return _selectedRole != null;
      case 3:
        if (_selectedRole == 'creator') {
          return _platforms.isNotEmpty && _monthlyReach != null;
        } else {
          return _companyController.text.trim().isNotEmpty && _industry != null;
        }
      default:
        return false;
    }
  }

  Future<void> _saveAndFinish() async {
    setState(() => _isSaving = true);
    try {
      final auth = ref.read(firebaseAuthProvider);
      final firestore = ref.read(firestoreProvider);
      final uid = auth.currentUser!.uid;

      final onboardingData = {
        'heardAboutUs': _heardAboutUs,
        'usageReasons': _usageReasons.toList(),
        'platforms': _selectedRole == 'creator' ? _platforms.join(',') : null,
        'monthlyReach': _monthlyReach,
        'companyName':
            _selectedRole == 'brand' ? _companyController.text.trim() : null,
        'industry': _industry,
        'budgetRange': _budgetRange,
        'completedAt': FieldValue.serverTimestamp(),
      };

      await firestore.collection('users').doc(uid).update({
        'role': _selectedRole,
        'onboarding': onboardingData,
      });

      if (!mounted) return;
      if (_selectedRole == 'brand') {
        context.go(AppRoutes.home);
      } else {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                children: [
                  Row(
                    children: List.generate(4, (i) {
                      final isActive = i <= _currentPage;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i < 3 ? 6 : 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 3,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.accentViolet
                                  : AppColors.glassBorder,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step ${_currentPage + 1} of 4',
                        style: AppTextStyles.bodySmall,
                      ),
                      if (_currentPage > 0)
                        TextButton(
                          onPressed: () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                          child: const Text('Back'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _Step1(
                    selected: _heardAboutUs,
                    options: _heardOptions,
                    onSelected: (v) => setState(() => _heardAboutUs = v),
                  ),
                  _Step2(
                    selected: _usageReasons,
                    options: _reasonOptions,
                    onToggle: (v) => setState(() {
                      if (_usageReasons.contains(v)) {
                        _usageReasons.remove(v);
                      } else {
                        _usageReasons.add(v);
                      }
                    }),
                  ),
                  _Step3(
                    selected: _selectedRole,
                    onSelected: (v) => setState(() => _selectedRole = v),
                  ),
                  _Step4(
                    role: _selectedRole,
                    platforms: _platforms,
                    monthlyReach: _monthlyReach,
                    companyController: _companyController,
                    industry: _industry,
                    budgetRange: _budgetRange,
                    onPlatformToggle: (v) => setState(() {
                      if (_platforms.contains(v)) {
                        _platforms.remove(v);
                      } else {
                        _platforms.add(v);
                      }
                    }),
                    onReachChanged: (v) => setState(() => _monthlyReach = v),
                    onIndustryChanged: (v) => setState(() => _industry = v),
                    onBudgetChanged: (v) => setState(() => _budgetRange = v),
                  ),
                ],
              ),
            ),
            // CTA button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canProceed() && !_isSaving ? _nextPage : null,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _currentPage < 3 ? 'Continue' : 'Get Started',
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 1: How did you hear about us? ──────────────────────────────────────
class _Step1 extends StatelessWidget {
  final String? selected;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const _Step1({
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How did you hear\nabout us? 👋', style: AppTextStyles.displayMedium)
              .animate().fadeIn().slideY(begin: 0.2, end: 0),
          const SizedBox(height: 8),
          Text('This helps us reach more creators like you.',
                  style: AppTextStyles.bodyMedium)
              .animate(delay: 100.ms).fadeIn(),
          const SizedBox(height: 32),
          ...options.map((opt) {
            final isSelected = selected == opt;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => onSelected(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentViolet.withValues(alpha: 0.12)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accentViolet
                          : AppColors.glassBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accentViolet
                                : AppColors.glassBorder,
                            width: 2,
                          ),
                          color: isSelected
                              ? AppColors.accentViolet
                              : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 12, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(opt, style: AppTextStyles.bodyLarge),
                    ],
                  ),
                ),
              ).animate(delay: Duration(milliseconds: 150 + options.indexOf(opt) * 80))
                  .fadeIn()
                  .slideX(begin: -0.1, end: 0),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Step 2: Why are you using CreatorLink? ───────────────────────────────────
class _Step2 extends StatelessWidget {
  final Set<String> selected;
  final List<String> options;
  final ValueChanged<String> onToggle;

  const _Step2({
    required this.selected,
    required this.options,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Why are you using\nCreatorLink? 🚀',
                  style: AppTextStyles.displayMedium)
              .animate().fadeIn().slideY(begin: 0.2, end: 0),
          const SizedBox(height: 8),
          Text('Pick all that apply — no judgment.',
                  style: AppTextStyles.bodyMedium)
              .animate(delay: 100.ms).fadeIn(),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options.map((opt) {
              final isSelected = selected.contains(opt);
              return GestureDetector(
                onTap: () => onToggle(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentViolet.withValues(alpha: 0.15)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accentViolet
                          : AppColors.glassBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(Icons.check_circle_rounded,
                            size: 14, color: AppColors.accentViolet),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        opt,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: isSelected
                              ? AppColors.accentViolet
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ).animate(delay: 200.ms).fadeIn(),
        ],
      ),
    );
  }
}

// ─── Step 3: Role selection ────────────────────────────────────────────────────
class _Step3 extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelected;

  const _Step3({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Who are you? 🎭', style: AppTextStyles.displayMedium)
              .animate().fadeIn().slideY(begin: 0.2, end: 0),
          const SizedBox(height: 8),
          Text('Choose your primary role on CreatorLink.',
                  style: AppTextStyles.bodyMedium)
              .animate(delay: 100.ms).fadeIn(),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _RoleCard(
                  title: 'Creator /\nEditor',
                  subtitle: 'Post content & earn from campaigns',
                  icon: Icons.videocam_rounded,
                  isSelected: selected == 'creator',
                  onTap: () => onSelected('creator'),
                  color: AppColors.accentViolet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RoleCard(
                  title: 'Brand /\nClient',
                  subtitle: 'Launch campaigns & reach creators',
                  icon: Icons.business_rounded,
                  isSelected: selected == 'brand',
                  onTap: () => onSelected('brand'),
                  color: AppColors.accentGreen,
                ),
              ),
            ],
          ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(20),
        height: 200,
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.glassBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 20,
                    spreadRadius: 0,
                  )
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const Spacer(),
            Text(title,
                style: AppTextStyles.titleMedium
                    .copyWith(color: isSelected ? color : AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(subtitle, style: AppTextStyles.bodySmall),
            if (isSelected) ...[
              const SizedBox(height: 8),
              Icon(Icons.check_circle_rounded, color: color, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Step 4: Role-specific questions ─────────────────────────────────────────
class _Step4 extends StatelessWidget {
  final String? role;
  final Set<String> platforms;
  final String? monthlyReach;
  final TextEditingController companyController;
  final String? industry;
  final String? budgetRange;
  final ValueChanged<String> onPlatformToggle;
  final ValueChanged<String?> onReachChanged;
  final ValueChanged<String?> onIndustryChanged;
  final ValueChanged<String?> onBudgetChanged;

  const _Step4({
    required this.role,
    required this.platforms,
    required this.monthlyReach,
    required this.companyController,
    required this.industry,
    required this.budgetRange,
    required this.onPlatformToggle,
    required this.onReachChanged,
    required this.onIndustryChanged,
    required this.onBudgetChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (role == 'creator') return _CreatorStep4(
      platforms: platforms,
      monthlyReach: monthlyReach,
      onPlatformToggle: onPlatformToggle,
      onReachChanged: onReachChanged,
    );
    return _BrandStep4(
      companyController: companyController,
      industry: industry,
      budgetRange: budgetRange,
      onIndustryChanged: onIndustryChanged,
      onBudgetChanged: onBudgetChanged,
    );
  }
}

class _CreatorStep4 extends StatelessWidget {
  final Set<String> platforms;
  final String? monthlyReach;
  final ValueChanged<String> onPlatformToggle;
  final ValueChanged<String?> onReachChanged;

  const _CreatorStep4({
    required this.platforms,
    required this.monthlyReach,
    required this.onPlatformToggle,
    required this.onReachChanged,
  });

  static const _platformOptions = [
    ('Instagram', Icons.camera_alt_outlined),
    ('YouTube', Icons.play_circle_outline),
    ('Twitter', Icons.tag),
    ('LinkedIn', Icons.work_outline),
  ];

  static const _reachOptions = [
    'Under 1K',
    '1K–10K',
    '10K–100K',
    '100K–1M',
    '1M+',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tell us about your\ncontent 📱', style: AppTextStyles.displayMedium)
              .animate().fadeIn().slideY(begin: 0.2, end: 0),
          const SizedBox(height: 24),
          Text('Platforms you post on:', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _platformOptions.map((p) {
              final isSelected = platforms.contains(p.$1);
              return GestureDetector(
                onTap: () => onPlatformToggle(p.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentViolet.withValues(alpha: 0.15)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? AppColors.accentViolet : AppColors.glassBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(p.$2,
                          size: 16,
                          color: isSelected
                              ? AppColors.accentViolet
                              : AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(p.$1,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: isSelected
                                ? AppColors.accentViolet
                                : AppColors.textSecondary,
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text('Average monthly reach:', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: monthlyReach,
            decoration: const InputDecoration(
              hintText: 'Select your reach',
            ),
            dropdownColor: AppColors.surfaceElevated,
            items: _reachOptions
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: onReachChanged,
          ),
        ],
      ),
    );
  }
}

class _BrandStep4 extends StatelessWidget {
  final TextEditingController companyController;
  final String? industry;
  final String? budgetRange;
  final ValueChanged<String?> onIndustryChanged;
  final ValueChanged<String?> onBudgetChanged;

  static const _industries = [
    'Fashion & Beauty',
    'Tech & Gaming',
    'Food & Beverage',
    'Health & Fitness',
    'Finance',
    'Education',
    'Travel',
    'Entertainment',
    'Other',
  ];

  static const _budgetRanges = [
    'Under ₹10,000',
    '₹10K–₹50K',
    '₹50K–₹2L',
    '₹2L–₹10L',
    'Above ₹10L',
  ];

  const _BrandStep4({
    required this.companyController,
    required this.industry,
    required this.budgetRange,
    required this.onIndustryChanged,
    required this.onBudgetChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About your brand 🏢', style: AppTextStyles.displayMedium)
              .animate().fadeIn().slideY(begin: 0.2, end: 0),
          const SizedBox(height: 24),
          TextFormField(
            controller: companyController,
            decoration: const InputDecoration(
              labelText: 'Company / Brand name',
              prefixIcon: Icon(Icons.business_outlined),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: industry,
            decoration: const InputDecoration(
              labelText: 'Industry',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            dropdownColor: AppColors.surfaceElevated,
            items: _industries
                .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                .toList(),
            onChanged: onIndustryChanged,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: budgetRange,
            decoration: const InputDecoration(
              labelText: 'Typical campaign budget',
              prefixIcon: Icon(Icons.currency_rupee),
            ),
            dropdownColor: AppColors.surfaceElevated,
            items: _budgetRanges
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: onBudgetChanged,
          ),
        ],
      ),
    );
  }
}
