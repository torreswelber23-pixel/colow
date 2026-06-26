import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/app_colors.dart';
import '../bloc/auth/auth_cubit.dart';
import '../widgets/gradient_button.dart';
import 'home_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logo-colow.png',
                  width: 120,
                  height: 120,
                  errorBuilder: (_, __, ___) => Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.shield,
                      size: 60,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'COLOW',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sua seguranca deu W',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Entre pra ativar sua protecao e vincular sua familia com seguranca.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.ink2,
                    fontSize: 14.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 34),
                BlocBuilder<AuthCubit, AuthState>(
                  builder: (context, state) {
                    return ElevatedButton.icon(
                      onPressed: state.status == AuthStatus.loading
                          ? null
                          : () => context.read<AuthCubit>().signInWithGoogle(),
                      icon: state.status == AuthStatus.loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.ink,
                              ),
                            )
                          : const Icon(Icons.login, color: AppColors.ink),
                      label: Text(
                        state.status == AuthStatus.loading
                            ? 'Entrando...'
                            : 'Entrar com Google',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.ink,
                        elevation: 3,
                        shadowColor: const Color(0xFF6a5acd).withOpacity(0.1),
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE5E3F0)),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 26),
                Text(
                  'Seus dados ficam protegidos. So quem voce autorizar ve sua localizacao.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.ink3,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
