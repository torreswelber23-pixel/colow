import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../config/app_colors.dart';
import '../bloc/config/config_cubit.dart';
import '../bloc/contacts/contacts_cubit.dart';
import '../bloc/home/home_cubit.dart';
import '../bloc/profile/profile_cubit.dart';
import '../widgets/gradient_button.dart';
import 'circle_page.dart';
import 'config_page.dart';
import 'route_page.dart';
import '../../injection.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    context.read<HomeCubit>().loadHome();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            if (state.status == HomeStatus.loading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 18),
                  _buildTrustStrip(),
                  const SizedBox(height: 18),
                  GradientButton(
                    text: 'Iniciar rota protegida',
                    icon: Icons.shield,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RoutePage()),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildQuickActions(),
                  const SizedBox(height: 18),
                  _buildStatusCard(state),
                  const SizedBox(height: 14),
                  _buildLocationCard(state),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Container(
        color: AppColors.dark,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home, label: 'Inicio', isActive: true),
              _NavItem(
                icon: Icons.shield,
                label: 'Rota',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RoutePage()),
                ),
              ),
              _NavItem(
                icon: Icons.people,
                label: 'Circulo',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MultiBlocProvider(
                      providers: [
                        BlocProvider(create: (_) => getIt<ContactsCubit>()),
                        BlocProvider(create: (_) => getIt<ProfileCubit>()),
                      ],
                      child: const CirclePage(),
                    ),
                  ),
                ),
              ),
              _NavItem(
                icon: Icons.settings,
                label: 'Config',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) => getIt<ConfigCubit>()..loadConfig(),
                      child: const ConfigPage(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bem-vinda de volta',
              style: TextStyle(
                color: AppColors.ink2,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Voce esta protegida',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 25,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.shield, color: AppColors.primary, size: 26),
        ),
      ],
    );
  }

  Widget _buildTrustStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6a5acd).withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _TrustItem(icon: Icons.lock, txt: 'Privacidade'),
          _TrustItem(icon: Icons.check_circle, txt: 'Dados seguros'),
          _TrustItem(icon: Icons.refresh, txt: 'Cancele quando quiser'),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.people,
            label: 'Contatos',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CirclePage()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAction(
            icon: Icons.key,
            label: 'Palavra-codigo',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BlocProvider(
                  create: (_) => getIt<ConfigCubit>()..loadConfig(),
                  child: const ConfigPage(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAction(
            icon: Icons.phone,
            label: 'Emergencia',
            onTap: () async {
              final uri = Uri.parse('tel:190');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(HomeState state) {
    final hasContacts = state.contacts.isNotEmpty;
    final hasCodeWord = false; // TODO: carregar do storage

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6a5acd).withOpacity(0.07),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sua protecao',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          _StatusLine(
            icon: Icons.people,
            label: 'Contatos de confianca',
            ok: hasContacts,
            txt: hasContacts ? '${state.contacts.length} ativos' : 'Nenhum',
          ),
          _StatusLine(
            icon: Icons.key,
            label: 'Palavra-codigo',
            ok: hasCodeWord,
            txt: hasCodeWord ? 'Configurada' : 'Definir',
            amber: !hasCodeWord,
            ultimo: true,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(HomeState state) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6a5acd).withOpacity(0.07),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_pin, color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Sua localizacao',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            state.location != null
                ? '${state.location!.lat.toStringAsFixed(5)}, ${state.location!.lng.toStringAsFixed(5)}'
                : 'Aguardando permissao...',
            style: TextStyle(
              color: AppColors.ink2,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final String txt;

  const _TrustItem({required this.icon, required this.txt});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.green),
        const SizedBox(width: 5),
        Text(
          txt,
          style: const TextStyle(
            color: AppColors.ink2,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6a5acd).withOpacity(0.07),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(height: 9),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ok;
  final String txt;
  final bool amber;
  final bool ultimo;

  const _StatusLine({
    required this.icon,
    required this.label,
    required this.ok,
    required this.txt,
    this.amber = false,
    this.ultimo = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = amber
        ? AppColors.amberSoft
        : ok
            ? AppColors.greenSoft
            : const Color(0xFFFBE0E4);
    final cor = amber
        ? AppColors.amber
        : ok
            ? AppColors.green
            : const Color(0xFFD43C53);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: ultimo
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.line),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.ink2, size: 15),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              txt,
              style: TextStyle(
                color: cor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : const Color(0xFF8C88A8),
          size: 24,
        ),
      ),
    );
  }
}
