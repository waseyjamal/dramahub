import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/typography.dart';

/// Suggest a Drama screen
///
/// Styled header + Google Form in WebView
/// Responses go directly to your Google Sheet
class SuggestDramaScreen extends StatefulWidget {
  const SuggestDramaScreen({super.key});

  @override
  State<SuggestDramaScreen> createState() => _SuggestDramaScreenState();
}

class _SuggestDramaScreenState extends State<SuggestDramaScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  static const String _formUrl =
      'https://docs.google.com/forms/d/e/1FAIpQLScyUX8nJaXDmJiOwLyD3DBx4QOFrp5Mls-7L_1NycJpmDECYw/viewform?embedded=true';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse(_formUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suggest a Drama'), centerTitle: true),
      body: Column(
        children: [
          // Styled header above the form
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              border: Border(
                bottom: BorderSide(
                  color: Colors.purpleAccent.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  child: const Icon(
                    Icons.movie_rounded,
                    color: Colors.purpleAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Want to see a drama here?',
                        style: AppTypography.title.copyWith(fontSize: 14),
                      ),
                      Text(
                        'We add dramas suggested by our community.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.softGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Form WebView
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  Container(
                    color: Colors.black87,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.primaryRed,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Loading form...',
                            style: AppTypography.body.copyWith(
                              color: AppColors.softGrey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
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
