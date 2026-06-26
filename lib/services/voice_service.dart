import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class VoiceService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListeningRequested = false;

  String? _targetWord;
  VoidCallback? _onTargetDetected;

  Timer? _restartTimer;

  Future<bool> init() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speechToText.initialize(
        onStatus: _statusListener,
        onError: _errorListener,
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('VoiceService init error: $e');
      return false;
    }
  }

  void _statusListener(String status) {
    debugPrint('VoiceService status: $status');
    if (status == 'done' || status == 'notListening') {
      // O reconhecimento parou (silêncio longo, ou timeout do OS).
      // Se ainda for pra estar ouvindo, reiniciamos após 1 segundo.
      if (_isListeningRequested) {
        _scheduleRestart();
      }
    }
  }

  void _errorListener(dynamic error) {
    debugPrint('VoiceService error: $error');
    if (_isListeningRequested) {
      _scheduleRestart();
    }
  }

  void _scheduleRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(seconds: 1), () {
      if (_isListeningRequested) {
        _startListeningCore();
      }
    });
  }

  Future<void> startContinuousListening({
    required String targetWord,
    required VoidCallback onWordDetected,
  }) async {
    _targetWord = targetWord.trim().toLowerCase();
    _onTargetDetected = onWordDetected;
    _isListeningRequested = true;

    final ready = await init();
    if (!ready) return;

    await _startListeningCore();
  }

  Future<void> _startListeningCore() async {
    if (!_isListeningRequested) return;

    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        cancelOnError: true,
        partialResults: true,
        listenMode: ListenMode.dictation,
      );
    } catch (e) {
      debugPrint('VoiceService listen error: $e');
      _scheduleRestart();
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (_targetWord == null || _targetWord!.isEmpty) return;

    final recognized = result.recognizedWords.toLowerCase();
    debugPrint('Reconhecido: $recognized');

    if (recognized.contains(_targetWord!)) {
      debugPrint('Palavra-alvo detectada!');
      _onTargetDetected?.call();
      
      // Se quisermos parar após detectar:
      // stopListening();
    }
  }

  Future<void> stopListening() async {
    _isListeningRequested = false;
    _restartTimer?.cancel();
    _targetWord = null;
    _onTargetDetected = null;
    await _speechToText.stop();
  }
}
