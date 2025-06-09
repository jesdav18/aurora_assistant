import 'package:flutter_tts/flutter_tts.dart';
import '../config/app_config.dart';

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  Future<void> initialize() async {
    try {
      await _flutterTts.setLanguage(AppConfig.ttsLanguage);
      await _flutterTts.setSpeechRate(AppConfig.ttsSpeechRate);
      await _flutterTts.setVolume(AppConfig.ttsVolume);
      await _flutterTts.setPitch(AppConfig.ttsPitch);
      
      await _flutterTts.setVoice({
        'name': 'es-es-x-eea-local',
        'locale': AppConfig.ttsLanguage
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });
      
      _flutterTts.setErrorHandler((message) {
        _isSpeaking = false;
      });

      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      throw Exception('Error al inicializar TTS: $e');
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final cleanText = _cleanTextForSpeech(text);
      if (cleanText.isEmpty) return;

      await _flutterTts.stop();
      _isSpeaking = true;
      await _flutterTts.speak(cleanText);
    } catch (e) {
      _isSpeaking = false;
      throw Exception('Error al reproducir texto: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
    } catch (e) {
      throw Exception('Error al detener TTS: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _flutterTts.pause();
    } catch (e) {
      throw Exception('Error al pausar TTS: $e');
    }
  }

  bool get isPlaying => _isSpeaking;

  String _cleanTextForSpeech(String text) {
    String cleanText = text
        .replaceAll(RegExp(r'\*\*([^*]*)\*\*'), r'\1')
        .replaceAll(RegExp(r'\*([^*]*)\*'), r'\1')
        .replaceAll(RegExp(r'[_~`]'), '')
        .replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'\1')
        .replaceAll(RegExp(r'#{1,6}\s*'), '')
        .replaceAll(RegExp(r'\n+'), '. ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return cleanText;
  }

  void dispose() {
    _flutterTts.stop();
  }
} 