import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drama_hub/services/telegram_service.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/typography.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drama_hub/services/ad_service.dart';

/// Report a Problem screen
///
/// Native Flutter form — dark themed, matches DramaHub app style.
/// Submissions sent to admin's Telegram bot via TelegramService.
/// Bot token + chat ID fetched from AppConfigService (app_config.json).
/// No hardcoded secrets. No WebView.
class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _formKey = GlobalKey<FormState>();

  final _problemTypeController = TextEditingController();
  final _dramaEpisodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactController = TextEditingController();

  bool _isSubmitting = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      AdService.instance.showInterstitialForScreen('report_problem_screen');
    });
  }

  // Submit cooldown — 1 hour between submissions (SharedPreferences)
  static const String _cooldownKey = 'report_problem_last_submit';
  static const int _cooldownMinutes = 60;

  @override
  void dispose() {
    _problemTypeController.dispose();
    _dramaEpisodeController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<bool> _isCoolingDown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSubmit = prefs.getInt(_cooldownKey);
      if (lastSubmit == null) return false;
      final diff = DateTime.now().millisecondsSinceEpoch - lastSubmit;
      return diff < Duration(minutes: _cooldownMinutes).inMilliseconds;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_cooldownKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Check cooldown silently
    if (await _isCoolingDown()) {
      _showSnackbar('Please wait before submitting again.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Get app version
      String appVersion = 'unknown';
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = info.version;
      } catch (_) {}

      // Auto-detect country from device locale — never shown to user
      String country = 'Unknown';
      try {
        final locale = WidgetsBinding.instance.platformDispatcher.locale;
        if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
          country = locale.countryCode!;
        }
      } catch (_) {}

      final success = await TelegramService.instance.sendProblemReport(
        problemType: _problemTypeController.text.trim(),
        dramaEpisodeName: _dramaEpisodeController.text.trim().isEmpty
            ? null
            : _dramaEpisodeController.text.trim(),
        description: _descriptionController.text.trim(),
        contact: _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
        appVersion: appVersion,
        country: country,
      );

      if (success) {
        await _saveCooldown();
        if (mounted) setState(() => _submitted = true);
      } else {
        if (mounted) {
          _showSnackbar(
            'Failed to send. Please check your connection.',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Something went wrong. Try again.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTypography.body.copyWith(color: AppColors.white),
        ),
        backgroundColor: isError
            ? AppColors.primaryRed
            : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: const Text('Report a Problem'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppTypography.title,
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: _submitted ? _buildSuccessState() : _buildForm(),
    );
  }

  // ── Success State ────────────────────────────────────────────────────────

  Widget _buildSuccessState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF4CAF50),
                size: 36,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Report Sent!',
              style: AppTypography.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'We review every report and fix issues as quickly as possible. Thank you for helping us improve.',
              style: AppTypography.body.copyWith(color: AppColors.softGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                ),
                child: Text('Go Back', style: AppTypography.button),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form ────────────────────────────────────────────────────────────────

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            _buildHeaderCard(
              icon: Icons.bug_report_rounded,
              iconColor: Colors.orangeAccent,
              title: 'Tell us what went wrong',
              subtitle: 'We review every report and fix issues quickly.',
            ),

            const SizedBox(height: AppSpacing.xl),

            // Problem Type — required, free text
            _buildLabel('Problem Type', required: true),
            const SizedBox(height: AppSpacing.sm),
            _buildTextField(
              controller: _problemTypeController,
              hint: 'e.g. Video not playing, App crash, Download issue',
              maxLength: 100,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please describe the problem type';
                }
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.lg),

            // Drama / Episode Name — optional
            _buildLabel('Drama / Episode Name', required: false),
            const SizedBox(height: AppSpacing.sm),
            _buildTextField(
              controller: _dramaEpisodeController,
              hint: 'e.g. Arafta Episode 56',
              maxLength: 100,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Description — required
            _buildLabel('Describe the Problem', required: true),
            const SizedBox(height: AppSpacing.sm),
            _buildTextField(
              controller: _descriptionController,
              hint: 'Give us as much detail as you can...',
              maxLength: 500,
              maxLines: 4,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please describe the problem';
                }
                if (v.trim().length < 10) {
                  return 'Please give a bit more detail';
                }
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.lg),

            // Contact — optional
            _buildLabel('Your Telegram or Email', required: false),
            const SizedBox(height: AppSpacing.sm),
            _buildTextField(
              controller: _contactController,
              hint: '@yourusername or email@example.com',
              maxLength: 100,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Optional — only if you want us to follow up with you.',
              style: AppTypography.caption.copyWith(color: AppColors.softGrey),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: AppColors.primaryRed.withValues(
                    alpha: 0.5,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text('Submit Report', style: AppTypography.button),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  // ── Reusable Widgets ─────────────────────────────────────────────────────

  Widget _buildHeaderCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: iconColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.title.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.softGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, {required bool required}) {
    return Row(
      children: [
        Text(
          text,
          style: AppTypography.body.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          Text(
            '*',
            style: AppTypography.body.copyWith(color: AppColors.primaryRed),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int? maxLength,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: maxLength != null
          ? [LengthLimitingTextInputFormatter(maxLength)]
          : null,
      style: AppTypography.body.copyWith(color: AppColors.white),
      cursorColor: AppColors.primaryRed,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.body.copyWith(
          color: AppColors.softGrey.withValues(alpha: 0.5),
        ),
        counterStyle: AppTypography.caption.copyWith(
          color: AppColors.softGrey.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: AppColors.cardBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(
            color: AppColors.softGrey.withValues(alpha: 0.15),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(
            color: AppColors.softGrey.withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: const BorderSide(color: AppColors.primaryRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
        ),
        errorStyle: AppTypography.caption.copyWith(color: AppColors.primaryRed),
      ),
      validator: validator,
    );
  }
}
