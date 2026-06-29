import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/env.dart';
import '../../domain/repositories/alert_repository.dart';
import '../../core/utils/result.dart';
import '../../injection.dart';
import '../../services/livekit_service.dart';
import 'live_location_page.dart';

/// Tela cheia de alerta de SOS recebido (estilo "chamada"), exibida dentro do
/// app quando um alerta chega via Realtime e o app esta aberto.
class AlertaRecebidoPage extends StatefulWidget {
  final String nome;
  final String tipo;
  final double? lat;
  final double? lng;
  final String? room;
  final String? protegidoId;
  // Modo "monitor": acompanhamento proativo (calmo/azul), nao alerta vermelho.
  final bool monitor;

  const AlertaRecebidoPage({
    super.key,
    required this.nome,
    required this.tipo,
    this.lat,
    this.lng,
    this.room,
    this.protegidoId,
    this.monitor = false,
  });

  @override
  State<AlertaRecebidoPage> createState() => _AlertaRecebidoPageState();
}

enum _Escuta { idle, conectando, ouvindo, erro }

class _AlertaRecebidoPageState extends State<AlertaRecebidoPage> {
  final _liveKit = getIt<LiveKitService>();
  _Escuta _estado = _Escuta.idle;
  String? _erro;

  @override
  void dispose() {
    _liveKit.disconnect();
    super.dispose();
  }

  Future<void> _ouvir() async {
    final room = widget.room;
    if (room == null || room.isEmpty) {
      setState(() {
        _estado = _Escuta.erro;
        _erro = 'Sala de audio indisponivel';
      });
      return;
    }

    setState(() {
      _estado = _Escuta.conectando;
      _erro = null;
    });

    final tokenResult = await getIt<AlertRepository>().getLiveKitToken(
      roomName: room,
      participantName: 'Familiar',
    );

    switch (tokenResult) {
      case Success(data: final token):
        try {
          await _liveKit.connect(
            url: Env.livekitUrl,
            token: token,
            listenOnly: true,
          );
          if (mounted) setState(() => _estado = _Escuta.ouvindo);
        } catch (e) {
          if (mounted) {
            setState(() {
              _estado = _Escuta.erro;
              _erro = 'Falha ao conectar no audio';
            });
          }
        }
      case Error(failure: final f):
        if (mounted) {
          setState(() {
            _estado = _Escuta.erro;
            _erro = f.message;
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEscuta = widget.tipo == 'escuta' || widget.tipo == 'escuta_ativa';
    final monitor = widget.monitor;
    final fundo =
        monitor ? const Color(0xFF1E3A8A) : const Color(0xFFB91C1C);
    return Scaffold(
      backgroundColor: fundo,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(monitor ? Icons.shield_moon : Icons.sos,
                  color: Colors.white, size: 88),
              const SizedBox(height: 24),
              Text(
                monitor
                    ? 'Acompanhando ${widget.nome}'
                    : isEscuta
                        ? '${widget.nome} quer que voce ouca'
                        : '${widget.nome} precisa de ajuda',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _legendaEstado(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const Spacer(),
              _botaoOuvir(),
              if (widget.protegidoId != null) ...[
                const SizedBox(height: 12),
                _BotaoSecundario(
                  icon: Icons.map,
                  texto: 'Acompanhar no mapa ao vivo',
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => LiveLocationPage(
                        perfilId: widget.protegidoId!,
                        nome: widget.nome,
                        latInicial: widget.lat,
                        lngInicial: widget.lng,
                      ),
                    ));
                  },
                ),
              ] else if (widget.lat != null && widget.lng != null) ...[
                const SizedBox(height: 12),
                _BotaoSecundario(
                  icon: Icons.location_on,
                  texto: 'Ver localizacao no mapa',
                  onTap: () {
                    final uri = Uri.parse(
                        'https://maps.google.com/?q=${widget.lat},${widget.lng}');
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Fechar',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _legendaEstado() {
    switch (_estado) {
      case _Escuta.idle:
        return widget.monitor
            ? 'Toque para ouvir o ambiente ao vivo'
            : 'Tocou o SOS no COLOW agora';
      case _Escuta.conectando:
        return 'Conectando ao audio ao vivo...';
      case _Escuta.ouvindo:
        return '🔴 Ouvindo o ambiente ao vivo';
      case _Escuta.erro:
        return _erro ?? 'Erro ao ouvir';
    }
  }

  Widget _botaoOuvir() {
    final ouvindo = _estado == _Escuta.ouvindo;
    final conectando = _estado == _Escuta.conectando;
    final cor = widget.monitor ? const Color(0xFF1E3A8A) : const Color(0xFFB91C1C);
    return SizedBox(
      height: 60,
      child: ElevatedButton.icon(
        onPressed: conectando
            ? null
            : ouvindo
                ? () async {
                    await _liveKit.disconnect();
                    if (mounted) setState(() => _estado = _Escuta.idle);
                  }
                : _ouvir,
        icon: conectando
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Color(0xFFB91C1C)),
              )
            : Icon(ouvindo ? Icons.stop : Icons.hearing, size: 26),
        label: Text(
          ouvindo
              ? 'Parar de ouvir'
              : conectando
                  ? 'Conectando...'
                  : 'Ouvir ao vivo',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: cor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _BotaoSecundario extends StatelessWidget {
  final IconData icon;
  final String texto;
  final VoidCallback onTap;

  const _BotaoSecundario({
    required this.icon,
    required this.texto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          texto,
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
