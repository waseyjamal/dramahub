import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:drama_hub/controllers/home_controller.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/typography.dart';

/// Search bar for filtering the drama grid by title.
///
/// [onFocused] is called when the user taps/focuses the field — used by
/// HomeScreen to flip [HomeController.isSearching] to true and trigger
/// the full-screen search overlay transition.
///
/// TextEditingController and FocusNode are passed from HomeScreen
/// so the parent retains full control over clearing and unfocusing.
class HomeSearchBar extends StatefulWidget {
  final HomeController controller;
  final TextEditingController textController;
  final FocusNode focusNode;
  final VoidCallback? onFocused;

  const HomeSearchBar({
    super.key,
    required this.controller,
    required this.textController,
    required this.focusNode,
    this.onFocused,
  });

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (widget.focusNode.hasFocus) {
      widget.onFocused?.call();
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.secondaryDark,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: TextField(
        controller: widget.textController,
        focusNode: widget.focusNode,
        onChanged: widget.controller.filterDramas,
        style: AppTypography.body,
        decoration: InputDecoration(
          hintText: 'Search drama name...',
          hintStyle: AppTypography.body.copyWith(color: AppColors.softGrey),
          prefixIcon: const Icon(Icons.search, color: AppColors.softGrey),
          suffixIcon: Obx(
            () => !widget.controller.isSearching.value &&
                    widget.controller.filteredDramas.length !=
                        widget.controller.allDramas.length
                ? InkWell(
                    onTap: () {
                      widget.textController.clear();
                      widget.controller.filterDramas('');
                      widget.focusNode.unfocus();
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
