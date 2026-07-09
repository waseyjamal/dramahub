import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:drama_hub/controllers/home_controller.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/typography.dart';

/// Search bar for filtering the drama grid by title.
///
/// TextEditingController and FocusNode are passed from HomeScreen
/// so the parent can clear/unfocus the search when tapping outside.
/// Zero logic changes from original — pure file move.
class HomeSearchBar extends StatelessWidget {
  final HomeController controller;
  final TextEditingController textController;
  final FocusNode focusNode;

  const HomeSearchBar({
    super.key,
    required this.controller,
    required this.textController,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.secondaryDark,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: TextField(
        controller: textController,
        focusNode: focusNode,
        onChanged: controller.filterDramas,
        style: AppTypography.body,
        decoration: InputDecoration(
          hintText: 'Search drama name...',
          hintStyle: AppTypography.body.copyWith(color: AppColors.softGrey),
          prefixIcon: const Icon(Icons.search, color: AppColors.softGrey),
          suffixIcon: Obx(
            () =>
                controller.filteredDramas.length != controller.allDramas.length
                    ? InkWell(
                        onTap: () {
                          textController.clear();
                          controller.filterDramas('');
                          focusNode.unfocus();
                        },
                        borderRadius: BorderRadius.circular(32),
                        child: const Icon(Icons.close, color: AppColors.softGrey),
                      )
                    : const SizedBox.shrink(),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}