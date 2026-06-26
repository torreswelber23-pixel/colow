import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/env.dart';
import '../../domain/entities/app_location.dart';

/// Mapa Mapbox via Mapbox GL JS dentro de uma WebView.
/// Porta o lib/MapaWeb.js do app antigo — usa apenas o token publico (pk).
/// Pino vermelho pulsante que se move conforme o GPS atualiza.
class RouteMap extends StatefulWidget {
  final AppLocation? location;

  const RouteMap({super.key, this.location});

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  // centro padrao (Macapa) quando ainda nao ha GPS — igual ao app antigo
  static const double _fallbackLat = 0.0349;
  static const double _fallbackLng = -51.0694;

  late final WebViewController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0d0820))
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: (_) {
          _ready = true;
          _enviarPino();
        }),
      )
      ..loadHtmlString(_html());
  }

  @override
  void didUpdateWidget(covariant RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      _enviarPino();
    }
  }

  /// Atualiza o pino injetando JS — nao recarrega o mapa (igual ao MapaWeb.js).
  void _enviarPino() {
    if (!_ready || widget.location == null) return;
    final data = jsonEncode({
      'filha': {'lat': widget.location!.lat, 'lng': widget.location!.lng},
    });
    _controller.runJavaScript('setPinos($data);');
  }

  String _html() {
    final token = Env.mapboxPublicToken;
    final lat = widget.location?.lat ?? _fallbackLat;
    final lng = widget.location?.lng ?? _fallbackLng;
    return '''<!DOCTYPE html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<link href="https://api.mapbox.com/mapbox-gl-js/v3.0.1/mapbox-gl.css" rel="stylesheet">
<script src="https://api.mapbox.com/mapbox-gl-js/v3.0.1/mapbox-gl.js"></script>
<style>
  html,body,#map{height:100%;margin:0;background:#0d0820;}
  .mc-filha{width:20px;height:20px;border-radius:50%;background:#f43f5e;border:3px solid #fff;
    box-shadow:0 0 0 6px rgba(244,63,94,.3);animation:pulse 1.6s infinite;}
  @keyframes pulse{0%{box-shadow:0 0 0 0 rgba(244,63,94,.5);}70%{box-shadow:0 0 0 16px rgba(244,63,94,0);}100%{box-shadow:0 0 0 0 rgba(244,63,94,0);}}
  .mapboxgl-ctrl-attrib,.mapboxgl-ctrl-logo{opacity:.35;}
</style></head><body>
<div id="map"></div>
<script>
  mapboxgl.accessToken = "$token";
  var map = new mapboxgl.Map({
    container:'map',
    style:'mapbox://styles/mapbox/dark-v11',
    center:[$lng,$lat],
    zoom:14,
    attributionControl:false
  });
  var mFilha=null;
  function elFilha(){var d=document.createElement('div');d.className='mc-filha';return d;}
  function setPinos(d){
    if(d && d.filha){
      if(!mFilha){ mFilha=new mapboxgl.Marker({element:elFilha()}).setLngLat([d.filha.lng,d.filha.lat]).addTo(map); }
      else { mFilha.setLngLat([d.filha.lng,d.filha.lat]); }
      map.easeTo({center:[d.filha.lng,d.filha.lat],duration:600});
    }
  }
</script></body></html>''';
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
