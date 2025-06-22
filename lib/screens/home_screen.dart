import 'package:flutter/material.dart';
import '../widgets/voice_button.dart';
import '../services/whisper_service.dart';
import '../services/chatgpt_service.dart';
import '../services/tts_service.dart';
import 'navigation_screen.dart';

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
      print('🎤 Transcripción: $transcription');
      
      setState(() {
        _statusText = 'Procesando respuesta...';
      });

      final response = await _chatGPTService.sendMessage(transcription);
      print('🤖 Respuesta de ChatGPT: $response');
      
      // Verificar si se inició navegación
      if (_shouldOpenNavigation(response)) {
        print('🗺️ Detectada navegación, abriendo pantalla...');
        setState(() {
          _statusText = 'Abriendo navegación...';
        });
        
        // Esperar un momento para que el usuario escuche la respuesta
        await Future.delayed(Duration(seconds: 2));
        
        // Verificar que tenemos un destino antes de abrir
        final destinationName = _chatGPTService.navigationService.destinationName;
        print('📍 Destino para navegación: $destinationName');
        
        if (destinationName != null) {
          // Abrir pantalla de navegación
          _openNavigationScreen();
        } else {
          print('❌ No se pudo obtener el destino');
          setState(() {
            _statusText = 'Error: No se pudo obtener el destino';
          });
          
          // Restaurar estado después de 3 segundos
          Future.delayed(Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _statusText = 'Toca el micrófono para empezar';
              });
            }
          });
        }
        return;
      }
      
      setState(() {
        _statusText = 'Reproduciendo respuesta...';
      });

      await _ttsService.speak(response);

      setState(() {
        _statusText = 'Toca el micrófono para empezar';
      });
    } catch (e) {
      print('❌ Error en _processVoiceInput: $e');
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

  bool _shouldOpenNavigation(String response) {
    final navigationKeywords = [
      'navegación iniciada',
      'abriendo mapa de navegación',
      'navegación hacia',
      'iniciando navegación'
    ];
    
    final responseLower = response.toLowerCase();
    return navigationKeywords.any((keyword) => responseLower.contains(keyword));
  }

  void _openNavigationScreen() {
    final destinationName = _chatGPTService.navigationService.destinationName;
    if (destinationName != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => NavigationScreen(
            destinationName: destinationName,
            navigationService: _chatGPTService.navigationService,
          ),
        ),
      ).then((_) {
        // Restaurar estado cuando se cierra la pantalla de navegación
        setState(() {
          _statusText = 'Toca el micrófono para empezar';
        });
      });
    } else {
      // Si no hay destino, mostrar error y restaurar estado
      setState(() {
        _statusText = 'Error: No se pudo obtener el destino';
      });
      
      // Restaurar estado después de 3 segundos
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _statusText = 'Toca el micrófono para empezar';
          });
        }
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
        actions: [
          // Botón para abrir navegación si está activa
          if (_chatGPTService.navigationService.isNavigating)
            IconButton(
              icon: Icon(Icons.navigation),
              onPressed: _openNavigationScreen,
              tooltip: 'Abrir navegación',
            ),
        ],
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
            const SizedBox(height: 24),
            // Botón de prueba temporal
            ElevatedButton(
              onPressed: _isProcessing ? null : () async {
                print('🧪 Iniciando prueba de navegación...');
                setState(() {
                  _isProcessing = true;
                  _statusText = 'Probando navegación...';
                });
                
                try {
                  // Simular directamente la navegación
                  final success = await _chatGPTService.navigationService.startNavigation('Madrid');
                  print('✅ Resultado de navegación: $success');
                  print('📍 DestinationName: ${_chatGPTService.navigationService.destinationName}');
                  
                  if (success) {
                    setState(() {
                      _statusText = 'Navegación iniciada. Abriendo mapa...';
                    });
                    
                    await Future.delayed(Duration(seconds: 2));
                    _openNavigationScreen();
                  } else {
                    setState(() {
                      _statusText = 'Error: No se pudo iniciar navegación';
                    });
                    
                    await Future.delayed(Duration(seconds: 3));
                    setState(() {
                      _statusText = 'Toca el micrófono para empezar';
                    });
                  }
                } catch (e) {
                  print('❌ Error en prueba: $e');
                  setState(() {
                    _statusText = 'Error: $e';
                  });
                  
                  await Future.delayed(Duration(seconds: 3));
                  setState(() {
                    _statusText = 'Toca el micrófono para empezar';
                  });
                } finally {
                  setState(() {
                    _isProcessing = false;
                  });
                }
              },
              child: Text('Probar Navegación (Madrid)'),
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