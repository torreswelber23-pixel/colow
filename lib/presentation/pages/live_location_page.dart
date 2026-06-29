import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/app_colors.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../injection.dart';

/// Mapa ao vivo (estilo Uber): a familia acompanha a localizacao da pessoa
/// se movendo em tempo real, via Supabase Realtime na tabela localizacoes.
/// Usa Leaflet + OpenStreetMap (sem necessidade de token de mapa).
class LiveLocationPage extends StatefulWidget {
  final String perfilId;
  final String nome;
  final double? latInicial;
  final double? lngInicial;

  const LiveLocationPage({
    super.key,
    required this.perfilId,
    required this.nome,
    this.latInicial,
    this.lngInicial,
  });

  @override
  State<LiveLocationPage> createState() => _LiveLocationPageState();
}

class _LiveLocationPageState extends State<LiveLocationPage> {
  final _remote = getIt<SupabaseDatasource>();
  late final WebViewController _map;
  RealtimeChannel? _channel;
  bool _mapReady = false;
  double? _lat;
  double? _lng;
  bool _aoVivo = false;

  @override
  void initState() {
    super.initState();
    _lat = widget.latInicial;
    _lng = widget.lngInicial;

    _map = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFEAEAEA))
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) {
        _mapReady = true;
        _aplicarPino();
      }))
      ..loadHtmlString(_html());

    _carregarUltima();
    _channel = _remote.subscribeLocation(widget.perfilId, (lat, lng) {
      if (!mounted) return;
      setState(() {
        _lat = lat;
        _lng = lng;
        _aoVivo = true;
      });
      _aplicarPino();
    });
  }

  Future<void> _carregarUltima() async {
    final r = await _remote.getLastLocation(widget.perfilId);
    if (!mounted || r == null) return;
    final lat = (r['lat'] as num?)?.toDouble();
    final lng = (r['lng'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      setState(() {
        _lat = lat;
        _lng = lng;
      });
      _aplicarPino();
    }
  }

  void _aplicarPino() {
    if (!_mapReady || _lat == null || _lng == null) return;
    _map.runJavaScript('mover($_lat, $_lng);');
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  String _html() {
    final lat = _lat ?? -14.235;
    final lng = _lng ?? -51.925;
    final zoom = _lat != null ? 16 : 4;
    return '''<!DOCTYPE html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<style>
  html,body,#map{height:100%;margin:0;}
  .pino{width:22px;height:22px;border-radius:50%;background:#f43f5e;border:3px solid #fff;
    box-shadow:0 0 0 6px rgba(244,63,94,.3);animation:pulse 1.6s infinite;}
  @keyframes pulse{0%{box-shadow:0 0 0 0 rgba(244,63,94,.5);}70%{box-shadow:0 0 0 18px rgba(244,63,94,0);}100%{box-shadow:0 0 0 0 rgba(244,63,94,0);}}
</style></head><body>
<div id="map"></div>
<script>
  var map = L.map('map',{zoomControl:false,attributionControl:false}).setView([$lat,$lng],$zoom);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:19}).addTo(map);
  var icon = L.divIcon({className:'',html:'<div class="pino"></div>',iconSize:[22,22],iconAnchor:[11,11]});
  var marker = null;
  function mover(lat,lng){
    if(!marker){ marker = L.marker([lat,lng],{icon:icon}).addTo(map); }
    else { marker.setLatLng([lat,lng]); }
    map.setView([lat,lng], Math.max(map.getZoom(),16), {animate:true});
  }
</script></body></html>''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAEAEA),
      body: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _map)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  _BotaoCircular(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.2), blurRadius: 10),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFFf43f5e),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.nome,
                                  style: const TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  _lat == null
                                      ? 'Aguardando localizacao...'
                                      : _aoVivo
                                          ? '🔴 Ao vivo'
                                          : 'Ultima posicao conhecida',
                                  style: const TextStyle(
                                    color: AppColors.ink2,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotaoCircular extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _BotaoCircular({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
          ],
        ),
        child: Icon(icon, color: AppColors.ink),
      ),
    );
  }
}
