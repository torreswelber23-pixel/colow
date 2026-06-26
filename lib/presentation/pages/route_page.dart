import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/app_colors.dart';
import '../../injection.dart';
import '../bloc/route/route_cubit.dart';
import '../widgets/route_map.dart';

class RoutePage extends StatelessWidget {
  const RoutePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<RouteCubit>()..startRoute(),
      child: const _RouteView(),
    );
  }
}

class _RouteView extends StatelessWidget {
  const _RouteView();

  void _showCall190Dialog(BuildContext context) {
    final cubit = context.read<RouteCubit>();
    cubit.clearCall190Prompt();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('SOS enviado'),
        content: const Text(
          'Voce ainda nao cadastrou contatos de confianca. Ligue para a policia (190).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              cubit.call190();
            },
            child: const Text('Ligar 190'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: BlocConsumer<RouteCubit, RouteState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
          if (state.audioError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.danger,
                content: Row(
                  children: [
                    const Icon(Icons.mic_off, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.audioError!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state.promptCall190) {
            _showCall190Dialog(context);
          }
          if (state.status == RouteStatus.finished) {
            Navigator.of(context).maybePop();
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: RouteMap(location: state.location),
                ),
                // Badge de monitoramento ativo
                Positioned(
                  top: 18,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: AppColors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Monitoramento ativo',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          // Indicador de áudio ao vivo
                          if (state.audioStatus == AudioStatus.live) ...[
                            const SizedBox(width: 10),
                            const _PulsingDot(),
                            const SizedBox(width: 5),
                            const Text(
                              'AO VIVO',
                              style: TextStyle(
                                color: Color(0xFF1B9C5A),
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // Painel inferior de controles
                Positioned(
                  bottom: 18,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.dark,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.32),
                          blurRadius: 22,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ElevatedButton(
                          onPressed: state.isSendingSos
                              ? null
                              : () => context.read<RouteCubit>().sendSos(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(108, 108),
                            shape: const CircleBorder(),
                            elevation: 9,
                            shadowColor: AppColors.danger.withOpacity(0.6),
                          ),
                          child: state.isSendingSos
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber, size: 28),
                                    Text(
                                      'SOS',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'aciona familia + policia (190)',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Botão de áudio ao vivo — 4 estados visuais
                        _AudioButton(
                          audioStatus: state.audioStatus,
                          onTap: () =>
                              context.read<RouteCubit>().toggleFamilyListening(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withOpacity(0.09),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: const Text('Codigo'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    context.read<RouteCubit>().arrived(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withOpacity(0.09),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: const Text('Cheguei'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withOpacity(0.09),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: const Text('Encerrar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Overlay de SOS enviado
                if (state.sosSent)
                  Container(
                    color: Colors.black.withOpacity(0.7),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.all(30),
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: const BoxDecoration(
                                color: AppColors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check,
                                  color: Colors.white, size: 42),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Alerta enviado',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Sua familia e a rede COLOW foram avisadas com sua localizacao.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.ink2,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widget: botão de áudio ao vivo com 4 estados visuais
// ---------------------------------------------------------------------------

class _AudioButton extends StatelessWidget {
  const _AudioButton({
    required this.audioStatus,
    required this.onTap,
  });

  final AudioStatus audioStatus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final config = _configForStatus(audioStatus);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: config.hasBorder
            ? Border.all(color: config.borderColor, width: 1.5)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIcon(audioStatus, config.iconColor),
                const SizedBox(width: 10),
                Text(
                  config.label,
                  style: TextStyle(
                    color: config.textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(AudioStatus status, Color color) {
    if (status == AudioStatus.connecting) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }
    return Icon(_iconForStatus(status), color: color, size: 18);
  }

  IconData _iconForStatus(AudioStatus status) {
    return switch (status) {
      AudioStatus.idle => Icons.headphones,
      AudioStatus.connecting => Icons.sync,
      AudioStatus.live => Icons.volume_up,
      AudioStatus.error => Icons.mic_off,
    };
  }

  _AudioButtonConfig _configForStatus(AudioStatus status) {
    return switch (status) {
      AudioStatus.idle => _AudioButtonConfig(
          backgroundColor: Colors.white.withOpacity(0.08),
          iconColor: const Color(0xFFcfc9e8),
          textColor: const Color(0xFFcfc9e8),
          label: 'Deixar minha familia ouvir',
          hasBorder: false,
          borderColor: Colors.transparent,
        ),
      AudioStatus.connecting => _AudioButtonConfig(
          backgroundColor: const Color(0xFF2D2000),
          iconColor: const Color(0xFFFFC107),
          textColor: const Color(0xFFFFC107),
          label: 'Conectando…',
          hasBorder: true,
          borderColor: const Color(0xFFFFC107).withOpacity(0.4),
        ),
      AudioStatus.live => _AudioButtonConfig(
          backgroundColor: const Color(0xFF0D2E1A),
          iconColor: const Color(0xFF4ADE80),
          textColor: const Color(0xFF4ADE80),
          label: 'Familia ouvindo ao vivo 🔴',
          hasBorder: true,
          borderColor: const Color(0xFF1B9C5A),
        ),
      AudioStatus.error => _AudioButtonConfig(
          backgroundColor: const Color(0xFF2E0D0D),
          iconColor: AppColors.danger,
          textColor: AppColors.danger,
          label: 'Erro — toque para tentar novamente',
          hasBorder: true,
          borderColor: AppColors.danger.withOpacity(0.4),
        ),
    };
  }
}

class _AudioButtonConfig {
  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;
  final String label;
  final bool hasBorder;
  final Color borderColor;

  const _AudioButtonConfig({
    required this.backgroundColor,
    required this.iconColor,
    required this.textColor,
    required this.label,
    required this.hasBorder,
    required this.borderColor,
  });
}

// ---------------------------------------------------------------------------
// Widget: ponto pulsante "ao vivo"
// ---------------------------------------------------------------------------

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _c) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF4ADE80),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
