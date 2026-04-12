import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'ui_system/app_theme.dart';
import 'ui_system/colors.dart';
import 'bindings/initial_binding.dart';
import 'routes/app_routes.dart';
import 'routes/app_pages.dart';

/// Main app widget using GetX
class DramaHubApp extends StatelessWidget {
  const DramaHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Drama Hub',
      theme: AppTheme.darkTheme,
      initialBinding: InitialBinding(),
      initialRoute: AppRoutes.main,
      getPages: AppPages.routes,
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      // Wrap entire app with global background effect
      builder: (context, child) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.darkBackground,
            gradient: AppColors.redGlowGradient,
          ),
          child: child,
        );
      },
    );
  }
}
