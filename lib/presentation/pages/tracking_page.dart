import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../config/app_colors.dart';
import '../../../domain/entities/profile.dart';
import '../bloc/tracking/tracking_cubit.dart';
import '../../injection.dart';

class TrackingPage extends StatelessWidget {
  final Profile alvo;

  const TrackingPage({super.key, required this.alvo});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TrackingCubit>(param1: alvo)..startTracking(),
      child: const _TrackingView(),
    );
  }
}

class _TrackingView extends StatelessWidget {
  const _TrackingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: BlocBuilder<TrackingCubit, TrackingState>(
          builder: (context, state) {
            return Text('Acompanhando ${state.alvo.nome}');
          },
        ),
        backgroundColor: AppColors.bg,
      ),
      body: BlocBuilder<TrackingCubit, TrackingState>(
        builder: (context, state) {
          if (state.status == TrackingStatus.initial) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state.status == TrackingStatus.finished) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: AppColors.green, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    '${state.alvo.nome} chegou ao destino',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              // TODO: Mapbox Map (Substituir por MapWidget real)
              Container(
                color: const Color(0xFFE5E3F0),
                child: Center(
                  child: state.lastLocation != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_pin, color: AppColors.primary, size: 40),
                            Text(
                              '${state.lastLocation!.lat.toStringAsFixed(4)}, ${state.lastLocation!.lng.toStringAsFixed(4)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                      : const Text('Buscando localização...'),
                ),
              ),

              // Bottom Panel
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBottomPanel(context, state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context, TrackingState state) {
    final diff = state.lastUpdate != null
        ? DateTime.now().difference(state.lastUpdate!).inSeconds
        : 0;
    final atualizadoStr = diff < 60 ? 'Há $diff s' : 'Há ${diff ~/ 60} min';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: state.isAlvoEmRota ? AppColors.green : AppColors.ink3,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state.isAlvoEmRota ? 'Em movimento' : 'Parado',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Text(
                atualizadoStr,
                style: const TextStyle(color: AppColors.ink2, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildAudioButton(context, state),
          if (state.audioError != null) ...[
            const SizedBox(height: 8),
            Text(
              state.audioError!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildAudioButton(BuildContext context, TrackingState state) {
    Color bg;
    Color fg;
    String text;
    IconData icon;
    bool isSpinning = false;

    switch (state.audioStatus) {
      case AudioListenStatus.idle:
      case AudioListenStatus.error:
        bg = AppColors.primarySoft;
        fg = AppColors.primaryDeep;
        text = 'Ouvir áudio ao vivo';
        icon = Icons.headphones;
      case AudioListenStatus.connecting:
        bg = AppColors.amberSoft;
        fg = AppColors.amber;
        text = 'Conectando áudio...';
        icon = Icons.sensors;
        isSpinning = true;
      case AudioListenStatus.playing:
        bg = AppColors.greenSoft;
        fg = AppColors.green;
        text = 'Ouvindo ao vivo';
        icon = Icons.stop_circle;
    }

    return ElevatedButton(
      onPressed: () => context.read<TrackingCubit>().toggleListening(),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isSpinning)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: fg, strokeWidth: 2),
            )
          else
            Icon(icon),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
