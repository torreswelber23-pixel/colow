import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../injection.dart';
import '../../services/push_service.dart';
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
    try {
      final onboardingCubit = context.read<OnboardingCubit>();
      await onboardingCubit.checkOnboarding();

      if (!mounted) return;

      if (!onboardingCubit.state.isOnboarded) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingPage()),
        );
        return;
      }

      final authCubit = context.read<AuthCubit>();
      
      // Timeout de 5 segundos para evitar ficar preso para sempre
      await authCubit.checkAuth().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[COLOW] checkAuth timeout — indo para Login');
        },
      );

      if (!mounted) return;

      if (authCubit.state.status == AuthStatus.authenticated) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
        // Se o app foi aberto por uma notificacao de SOS (tela bloqueada /
        // app fechado), abre a tela de alerta por cima da Home.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          getIt<PushService>().tratarAberturaPorNotificacao();
        });
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } catch (e) {
      debugPrint('[COLOW] Erro na SplashPage: $e');
      if (!mounted) return;
      // Em caso de qualquer erro, vai para o Login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }
}
