import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/shadows.dart';
import 'package:drama_hub/ui_system/typography.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _showSteps = false;
  bool _showFAQ = false;

  Future<void> _launch(String link) async {
    final url = Uri.parse(link);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arafta Membership'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),

                // Header
                const Text(
                  '👑 Arafta Membership Hub',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Premium access methods for Membership episodes',
                  style: AppTypography.body.copyWith(color: AppColors.softGrey),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.xl),

                // VIP Card
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    border: Border.all(
                      color: AppColors.goldAccent.withValues(alpha: 0.4),
                    ),
                    boxShadow: AppShadows.cardShadow,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tag
                      Center(
                        child: Text(
                          'EXCLUSIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: AppColors.goldAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Title
                      const Center(
                        child: Text(
                          'VIP Telegram',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Price tag
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.goldAccent.withValues(alpha: 0.15),
                            border: Border.all(color: AppColors.goldAccent),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            '💳 MEMBERSHIP: ₹39 (ONE-TIME)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.goldAccent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Description
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                        child: Text(
                          '📺 Episode abhi release ho raha hai\n\n'
                          '🗓️ Har week episodes aate hain:\n'
                          'Monday – 2 Episodes\n'
                          'Friday – 2 Episodes\n\n'
                          '📺 Free episodes bhi Monday & Friday ko milte rahenge\n'
                          'Membership me bas aap free se 4 episodes aage rahoge\n\n'
                          '💳 Membership sirf 1 baar leni hai\n'
                          'Drama khatam hone tak new episode milega\n\n'
                          '🚫 New episode ke liye dobara payment nahi karni hai',
                          style: AppTypography.body.copyWith(
                            color: AppColors.softGrey,
                            fontSize: 13,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton(
                        onPressed: () =>
                            _launch('https://t.me/+Ro39QwNiZ35lZmFl'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '📲 PAY ₹39 & GET MEMBERSHIP',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      // Send screenshot button
                      OutlinedButton(
                        onPressed: () => _launch('https://t.me/D_Hofficial'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '📩 SEND PAYMENT SCREENSHOT HERE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Divider
                Divider(color: Colors.white.withValues(alpha: 0.1)),

                const SizedBox(height: AppSpacing.lg),

                // How to get membership dropdown
                GestureDetector(
                  onTap: () => setState(() => _showSteps = !_showSteps),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '🪪 How to Get Membership',
                        style: AppTypography.body.copyWith(
                          color: AppColors.softGrey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _showSteps ? '▲' : '▼',
                        style: TextStyle(color: AppColors.softGrey),
                      ),
                    ],
                  ),
                ),

                if (_showSteps) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    child: Text(
                      '🪪 How to Get Membership (Step by Step)\n\n'
                      '1️⃣ "Pay ₹39 & Get Membership" button par click karein\n'
                      '2️⃣ Hamare private Telegram channel par join karein\n'
                      '3️⃣ Channel mein pinned QR code se ₹39 payment karein\n'
                      '4️⃣ Payment ka screenshot lein\n'
                      '5️⃣ "Send Payment Screenshot Here" button se screenshot bhejein\n'
                      '6️⃣ Verify karke aapko membership access de diya jaega',
                      style: AppTypography.body.copyWith(
                        color: AppColors.softGrey,
                        fontSize: 13,
                        height: 1.8,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),

                // FAQ dropdown
                GestureDetector(
                  onTap: () => setState(() => _showFAQ = !_showFAQ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '📅 Important Release Info & FAQ',
                        style: AppTypography.body.copyWith(
                          color: AppColors.softGrey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _showFAQ ? '▲' : '▼',
                        style: TextStyle(color: AppColors.softGrey),
                      ),
                    ],
                  ),
                ),

                if (_showFAQ) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    child: Text(
                      'Free Release Schedule:\n'
                      'Episodes Friday & Monday ko shaam 6:30 PM website par release honge.\n\n'
                      '📅 Episode Release Schedule\n'
                      '• Monday – 2 Episodes\n'
                      '• Friday – 2 Episodes\n\n'
                      '💳 Membership Rule\n'
                      '• Sirf 1 baar ₹39 payment\n'
                      '• Drama khatam hone tak valid\n'
                      '• New episode ke liye dobara payment nahi\n\n'
                      '📲 Payment ke baad\n'
                      '• Telegram par turant access\n'
                      '• Website se pehle episodes\n'
                      '• Future episodes automatically milte rahenge',
                      style: AppTypography.body.copyWith(
                        color: AppColors.softGrey,
                        fontSize: 13,
                        height: 1.8,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),

                // Footer
                Text(
                  'VERIFIED BY DRAMA HUBS SECURITY',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.2),
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
