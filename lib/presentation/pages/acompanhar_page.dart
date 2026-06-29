import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../core/utils/result.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../injection.dart';
import 'alerta_recebido_page.dart';
import 'live_location_page.dart';

/// Painel do guardiao: lista as pessoas que voce acompanha e, para cada uma,
/// permite ouvir ao vivo e ver no mapa. Mostra "ao vivo" se a localizacao
/// dela foi atualizada ha pouco (esta em uma rota/SOS ativo).
class AcompanharPage extends StatefulWidget {
  const AcompanharPage({super.key});

  @override
  State<AcompanharPage> createState() => _AcompanharPageState();
}

class _AcompanharPageState extends State<AcompanharPage> {
  final _remote = getIt<SupabaseDatasource>();
  bool _carregando = true;
  List<Profile> _circulo = [];
  final Map<String, bool> _aoVivo = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final r = await getIt<ProfileRepository>().getMyCircle();
    final lista = switch (r) {
      Success(data: final l) => l,
      Error() => <Profile>[],
    };
    // Para cada protegido, ve se a localizacao foi atualizada nos ultimos 3 min.
    for (final p in lista) {
      try {
        final loc = await _remote.getLastLocation(p.id);
        // getLastLocation nao traz o tempo; consideramos "ao vivo" se ha
        // localizacao registrada (refinar depois com atualizado_em).
        _aoVivo[p.id] = loc != null;
      } catch (_) {
        _aoVivo[p.id] = false;
      }
    }
    if (!mounted) return;
    setState(() {
      _circulo = lista;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Acompanhar ao vivo'),
        backgroundColor: AppColors.bg,
        actions: [
          IconButton(onPressed: _carregar, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _circulo.isEmpty
              ? _vazio()
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _circulo.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _card(_circulo[i]),
                  ),
                ),
    );
  }

  Widget _vazio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: AppColors.ink3),
            const SizedBox(height: 16),
            Text(
              'Voce ainda nao acompanha ninguem.\nAdicione o codigo de alguem no Circulo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.ink2, fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Profile p) {
    final aoVivo = _aoVivo[p.id] ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6a5acd).withOpacity(0.07), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  p.nome.isNotEmpty ? p.nome[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nome,
                        style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: aoVivo ? const Color(0xFFf43f5e) : AppColors.ink3,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          aoVivo ? 'Localizacao disponivel' : 'Sem localizacao recente',
                          style: TextStyle(color: AppColors.ink2, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AlertaRecebidoPage(
                      nome: p.nome,
                      tipo: 'escuta',
                      room: 'colow-${p.id}',
                      protegidoId: p.id,
                      monitor: true,
                    ),
                  )),
                  icon: const Icon(Icons.hearing, size: 18),
                  label: const Text('Ouvir'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LiveLocationPage(
                      perfilId: p.id,
                      nome: p.nome,
                    ),
                  )),
                  icon: const Icon(Icons.map, size: 18),
                  label: const Text('Mapa'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
