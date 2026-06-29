import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vosk_flutter_2/vosk_flutter_2.dart';

/// Reconhecimento de voz OFFLINE com Vosk — escuta contínua e silenciosa
/// (sem o "bip" de liga/desliga do reconhecedor nativo). Detecta a
/// palavra-código mesmo no meio de uma frase e tolerando erros (fuzzy).
class VoiceService {
  static const String _modelAsset =
      'assets/models/vosk-model-small-pt-0.3.zip';
  static const int _sampleRate = 16000;

  final VoskFlutterPlugin _vosk = VoskFlutterPlugin.instance();
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;
  StreamSubscription<String>? _partialSub;
  StreamSubscription<String>? _resultSub;

  bool _isInitialized = false;
  String? _targetWord;
  VoidCallback? _onTargetDetected;

  Future<bool> init() async {
    if (_isInitialized) return true;
    try {
      final modelPath = await ModelLoader().loadFromAssets(_modelAsset);
      _model = await _vosk.createModel(modelPath);
      _recognizer = await _vosk.createRecognizer(
        model: _model!,
        sampleRate: _sampleRate,
      );
      _speechService = await _vosk.initSpeechService(_recognizer!);
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('VoiceService(Vosk) init error: $e');
      return false;
    }
  }

  Future<void> startContinuousListening({
    required String targetWord,
    required VoidCallback onWordDetected,
  }) async {
    _targetWord = targetWord.trim();
    _onTargetDetected = onWordDetected;

    final ready = await init();
    if (!ready || _speechService == null) return;

    await _partialSub?.cancel();
    await _resultSub?.cancel();
    // Resultados parciais = detecção quase em tempo real (não espera a frase
    // terminar). Resultados finais = confirmação.
    _partialSub = _speechService!
        .onPartial()
        .listen((j) => _check(_extrairTexto(j, 'partial')));
    _resultSub =
        _speechService!.onResult().listen((j) => _check(_extrairTexto(j, 'text')));

    await _speechService!.start();
    debugPrint('VoiceService(Vosk) escutando "$targetWord"');
  }

  String _extrairTexto(String json, String chave) {
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      return (m[chave] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  void _check(String reconhecido) {
    if (_targetWord == null || _targetWord!.isEmpty || reconhecido.isEmpty) {
      return;
    }
    if (_combina(reconhecido, _targetWord!)) {
      debugPrint('Palavra-alvo detectada (Vosk+fuzzy)!');
      final cb = _onTargetDetected;
      _onTargetDetected = null; // evita disparo duplicado
      cb?.call();
    }
  }

  Future<void> stopListening() async {
    _targetWord = null;
    _onTargetDetected = null;
    await _partialSub?.cancel();
    await _resultSub?.cancel();
    _partialSub = null;
    _resultSub = null;
    try {
      await _speechService?.stop();
    } catch (_) {}
  }

  // ===== Detecção INTELIGENTE (fuzzy) — tolera erros de reconhecimento =====

  static bool _combina(String reconhecido, String alvo) {
    final r = _normalizar(reconhecido);
    final t = _normalizar(alvo);
    if (t.isEmpty) return false;

    if (r.contains(t)) return true; // match exato da frase/palavra inteira

    final palavrasR = r.split(' ').where((w) => w.isNotEmpty).toList();
    final palavrasT = t.split(' ').where((w) => w.isNotEmpty).toList();
    if (palavrasR.isEmpty || palavrasT.isEmpty) return false;

    final chave = palavrasT.reduce((a, b) => a.length >= b.length ? a : b);
    if (chave.length < 4) {
      return palavrasR.contains(chave); // curta: exige match exato
    }

    for (final w in palavrasR) {
      final dist = _levenshtein(w, chave);
      final maxLen = w.length > chave.length ? w.length : chave.length;
      final sim = 1 - dist / maxLen;
      if (sim >= 0.75) return true;
    }
    return false;
  }

  static String _normalizar(String s) {
    s = s.toLowerCase().trim();
    const acent = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const limpo = 'aaaaaeeeeiiiiooooouuuucn';
    for (var i = 0; i < acent.length; i++) {
      s = s.replaceAll(acent[i], limpo[i]);
    }
    return s
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        curr[j + 1] = [
          curr[j] + 1,
          prev[j + 1] + 1,
          prev[j] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      for (var j = 0; j <= b.length; j++) {
        prev[j] = curr[j];
      }
    }
    return prev[b.length];
  }
}
