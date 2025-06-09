import 'package:flutter/material.dart';
import '../widgets/voice_button.dart';
import '../services/whisper_service.dart';
import '../services/chatgpt_service.dart';
import '../services/tts_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WhisperService _whisperService = WhisperService();
  final ChatGPTService _chatGPTService = ChatGPTService();
  final TTSService _ttsService = TTSService();
  
  bool _isProcessing = false;
  String _statusText = 'Toca el micrófono para empezar';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _ttsService.initialize();
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  Future<void> _processVoiceInput(String audioPath) async {
    setState(() {
      _isProcessing = true;
      _statusText = 'Transcribiendo audio...';
    });

    try {
      final transcription = await _whisperService.transcribeAudio(audioPath);
      
      setState(() {
        _statusText = 'Procesando respuesta...';
      });

      final response = await _chatGPTService.sendMessage(transcription);
      
      setState(() {
        _statusText = 'Reproduciendo respuesta...';
      });

      await _ttsService.speak(response);

      setState(() {
        _statusText = 'Toca el micrófono para empezar';
      });
    } catch (e) {
      setState(() {
        _statusText = 'Error: ${e.toString()}';
      });
      
      await Future.delayed(const Duration(seconds: 3));
      
      setState(() {
        _statusText = 'Toca el micrófono para empezar';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Aurora Assistant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Icon(
              Icons.mic_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 32),
            Text(
              _statusText,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            VoiceButton(
              onAudioRecorded: _processVoiceInput,
              isProcessing: _isProcessing,
            ),
            const Spacer(),
            Text(
              'Manténte enfocado en la carretera',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
} 