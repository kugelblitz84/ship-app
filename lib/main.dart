import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/foundation.dart';
import 'core/themes/themes.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/initial_binding/initial_bindings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set system UI overlay style for a polished feel
  // SystemChrome.setSystemUIOverlayStyle(
  //   const SystemUiOverlayStyle(
  //     statusBarColor: Colors.transparent,
  //     statusBarIconBrightness: Brightness.dark,
  //     systemNavigationBarColor: AppColors.surface,
  //     systemNavigationBarIconBrightness: Brightness.dark,
  //   ),
  // );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const double _webMaxContentWidth = 4096;

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: kIsWeb ? const Size(1440, 900) : const Size(393, 854),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          initialBinding: InitialBindings(),
          title: 'Urgent',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          builder: (context, child) {
            final appChild = child ?? const SizedBox.shrink();
            if (!kIsWeb) return appChild;

            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth <= 1024) {
                  return appChild;
                }

                return Container(
                  color: AppColors.background,
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _webMaxContentWidth,
                    ),
                    child: appChild,
                  ),
                );
              },
            );
          },
          defaultTransition: Transition.cupertino,
          transitionDuration: const Duration(milliseconds: 300),
          initialRoute: AppRoutes.bootstrap,
          getPages: AppPages.pages,
        );
      },
    );
  }
}
