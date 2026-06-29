import 'package:flutter/widgets.dart';

/// Chave de navegacao global — permite abrir telas (ex: alerta de SOS recebido)
/// de fora da arvore de widgets, como a partir de um evento Realtime.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
