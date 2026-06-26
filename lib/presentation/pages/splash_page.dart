import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth/auth_cubit.dart';
import '../bloc/onboarding/onboarding_cubit.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'onboarding_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await context.read<OnboardingCubit>().checkOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OnboardingCubit, OnboardingState>(
      listener: (context, onboardingState) {
        if (!onboardingState.isOnboarded) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OnboardingPage()),
          );
          return;
        }

        context.read<AuthCubit>().checkAuth();
      },
      child: BlocListener<AuthCubit, AuthState>(
        listener: (context, authState) {
          if (authState.status == AuthStatus.authenticated) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          } else if (authState.status == AuthStatus.unauthenticated) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          }
        },
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logo-colow.png',
                  width: 120,
                  height: 120,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.shield,
                    size: 80,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF2563EB)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
