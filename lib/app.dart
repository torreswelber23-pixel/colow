import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'config/app_theme.dart';
import 'core/navigation.dart';
import 'injection.dart';
import 'presentation/bloc/auth/auth_cubit.dart';
import 'presentation/bloc/onboarding/onboarding_cubit.dart';
import 'presentation/pages/splash_page.dart';

class ColowApp extends StatelessWidget {
  const ColowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<OnboardingCubit>()),
        BlocProvider(create: (_) => getIt<AuthCubit>()),
      ],
      child: MaterialApp(
        title: 'COLOW',
        debugShowCheckedModeBanner: false,
        navigatorKey: rootNavigatorKey,
        theme: AppTheme.light,
        home: const SplashPage(),
      ),
    );
  }
}
