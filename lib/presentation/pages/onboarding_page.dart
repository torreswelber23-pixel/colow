import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/app_colors.dart';
import '../bloc/onboarding/onboarding_cubit.dart';
import '../widgets/gradient_button.dart';
import 'login_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _slide = 0;

  final _slides = const [
    _SlideData(
      icon: Icons.shield,
      titulo: 'Voce nunca anda sozinha',
      sub: 'A rede COLOW acompanha cada trajeto seu — do primeiro passo ate voce chegar em casa.',
    ),
    _SlideData(
      icon: Icons.people,
      titulo: 'Sua familia junto',
      sub: 'Compartilhe sua localizacao ao vivo com quem voce ama. Eles veem voce chegar em seguranca.',
    ),
    _SlideData(
      icon: Icons.bolt,
      titulo: 'Em perigo, um toque',
      sub: 'SOS, palavra-codigo e aviso pra familia — discreto e na hora exata.',
    ),
  ];

  void _avancar() {
    if (_slide == _slides.length - 1) {
      context.read<OnboardingCubit>().completeOnboarding();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } else {
      setState(() => _slide++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _slides[_slide];
    final ultimo = _slide == _slides.length - 1;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryCyan, AppColors.primary, AppColors.primaryDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'COLOW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(36),
                  ),
                  child: Icon(s.icon, color: Colors.white, size: 54),
                ),
                const SizedBox(height: 24),
                Text(
                  s.titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  s.sub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 15.5,
                    height: 1.55,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _slides.asMap().entries.map((e) {
                    final ativo = e.key == _slide;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: ativo ? 22 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: ativo
                            ? Colors.white
                            : Colors.white.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
                GradientButton(
                  text: ultimo ? 'Comecar agora' : 'Proximo',
                  onPressed: _avancar,
                  icon: Icons.arrow_forward,
                ),
                if (!ultimo)
                  TextButton(
                    onPressed: _avancar,
                    child: Text(
                      'Pular',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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

class _SlideData {
  final IconData icon;
  final String titulo;
  final String sub;

  const _SlideData({
    required this.icon,
    required this.titulo,
    required this.sub,
  });
}
