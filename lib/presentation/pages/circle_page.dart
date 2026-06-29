import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/app_colors.dart';
import '../bloc/contacts/contacts_cubit.dart';
import '../bloc/profile/profile_cubit.dart';
import '../widgets/gradient_button.dart';
import 'tracking_page.dart';
import '../../injection.dart';

class CirclePage extends StatelessWidget {
  const CirclePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<ContactsCubit>()),
        BlocProvider(create: (_) => getIt<ProfileCubit>()),
      ],
      child: const _CircleView(),
    );
  }
}

class _CircleView extends StatefulWidget {
  const _CircleView();

  @override
  State<_CircleView> createState() => _CircleViewState();
}

class _CircleViewState extends State<_CircleView> {
  final _nomeController = TextEditingController();
  final _telController = TextEditingController();
  final _codigoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ContactsCubit>().loadContacts();
    context.read<ProfileCubit>().loadProfile();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Meu circulo'),
        backgroundColor: AppColors.bg,
      ),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, profileState) {
          if (profileState.profile == null) {
            return _buildCreateProfile();
          }
          return _buildCircleContent(context, profileState);
        },
      ),
    );
  }

  Widget _buildCreateProfile() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Crie seu circulo',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Seu circulo sao as pessoas que cuidam de voce. Comece com seu nome.',
            style: TextStyle(
              color: AppColors.ink2,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nomeController,
            decoration: const InputDecoration(hintText: 'Seu nome'),
          ),
          const SizedBox(height: 12),
          GradientButton(
            text: 'Criar meu perfil',
            icon: Icons.check,
            onPressed: () {
              context.read<ProfileCubit>().createProfile(_nomeController.text);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCircleContent(BuildContext context, ProfileState profileState) {
    final profile = profileState.profile!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                const Text(
                  'Seu codigo',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  profile.codigo,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sua familia digita esse codigo pra te acompanhar ao vivo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.ink2,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildTrackingSection(context, profileState),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contatos de emergencia',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recebem seu alerta e localizacao numa emergencia.',
                  style: TextStyle(
                    color: AppColors.ink2,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nomeController,
                  decoration: const InputDecoration(hintText: 'Nome'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _telController,
                  decoration: const InputDecoration(hintText: 'WhatsApp com DDD'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                GradientButton(
                  text: 'Adicionar contato',
                  icon: Icons.person_add,
                  onPressed: () {
                    context.read<ContactsCubit>().addContact(
                          _nomeController.text,
                          _telController.text,
                        );
                    _nomeController.clear();
                    _telController.clear();
                  },
                ),
                BlocBuilder<ContactsCubit, ContactsState>(
                  builder: (context, state) {
                    return Column(
                      children: state.contacts.asMap().entries.map((entry) {
                        final c = entry.value;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primarySoft,
                            child: Text(
                              c.nome[0].toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.primaryDeep,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          title: Text(
                            c.nome,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(c.telefone),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: AppColors.danger),
                            onPressed: () => context
                                .read<ContactsCubit>()
                                .removeContact(entry.key),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildTrackingSection(BuildContext context, ProfileState state) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acompanhar alguem',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Digite o codigo de um familiar para acompanha-lo ao vivo.',
            style: TextStyle(
              color: AppColors.ink2,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codigoController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    hintText: 'Codigo de 6 letras',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: state.isLinking
                    ? null
                    : () {
                        context.read<ProfileCubit>().linkByCode(_codigoController.text);
                        FocusScope.of(context).unfocus();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                child: state.isLinking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Vincular'),
              ),
            ],
          ),
          BlocListener<ProfileCubit, ProfileState>(
            listenWhen: (prev, curr) => 
                prev.linkSuccess != curr.linkSuccess || prev.errorMessage != curr.errorMessage,
            listener: (context, state) {
              if (state.linkSuccess) {
                _codigoController.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vinculado com sucesso!'),
                    backgroundColor: AppColors.green,
                  ),
                );
              } else if (state.errorMessage != null && !state.isLinking) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.errorMessage!),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            },
            child: const SizedBox.shrink(),
          ),
          if (state.circle.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Voce acompanha:',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: state.circle.map((p) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primarySoft,
                    child: Text(
                      p.nome[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primaryDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(
                    p.nome,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TrackingPage(alvo: p),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primarySoft,
                      foregroundColor: AppColors.primaryDeep,
                      elevation: 0,
                    ),
                    child: const Text('Acompanhar'),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
