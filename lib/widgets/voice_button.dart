import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../config/app_config.dart';

class VoiceButton extends StatefulWidget {
  final Function(String) onAudioRecorded;
  final bool isProcessing;

  const VoiceButton({
    super.key,
    required this.onAudioRecorded,
    required this.isProcessing,
  });

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with TickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<bool> _requestPermissions() async {
    final microphoneStatus = await Permission.microphone.request();
    return microphoneStatus == PermissionStatus.granted;
  }

  Future<String> _getAudioPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/voice_recording.m4a';
  }

  Future<void> _startRecording() async {
    final hasPermission = await _requestPermissions();
    if (!hasPermission) return;

    final audioPath = await _getAudioPath();
    
    if (await _audioRecorder.hasPermission()) {
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: AppConfig.audioBitRate,
          sampleRate: AppConfig.audioSampleRate,
        ),
        path: audioPath,
      );

      setState(() {
        _isRecording = true;
      });
      
      _animationController.repeat(reverse: true);
    }
  }

  Future<void> _stopRecording() async {
    final audioPath = await _audioRecorder.stop();
    
    setState(() {
      _isRecording = false;
    });
    
    _animationController.stop();
    _animationController.reset();

    if (audioPath != null && File(audioPath).existsSync()) {
      widget.onAudioRecorded(audioPath);
    }
  }

  Future<void> _toggleRecording() async {
    if (widget.isProcessing) return;

    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleRecording,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isRecording ? _scaleAnimation.value : 1.0,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _getButtonColors(context),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                _getButtonIcon(),
                size: 48,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }

  List<Color> _getButtonColors(BuildContext context) {
    if (widget.isProcessing) {
      return [
        Colors.grey.shade400,
        Colors.grey.shade600,
      ];
    } else if (_isRecording) {
      return [
        Colors.red.shade400,
        Colors.red.shade600,
      ];
    } else {
      return [
        Theme.of(context).colorScheme.primary,
        Theme.of(context).colorScheme.primary.withOpacity(0.8),
      ];
    }
  }

  IconData _getButtonIcon() {
    if (widget.isProcessing) {
      return Icons.hourglass_empty_rounded;
    } else if (_isRecording) {
      return Icons.stop_rounded;
    } else {
      return Icons.mic_rounded;
    }
  }
} 