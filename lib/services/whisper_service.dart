import 'dart:io';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'api_interceptor.dart';

class WhisperService {
  final Dio _dio = Dio();

  WhisperService() {
    _dio.options.headers = {
      'Authorization': 'Bearer ${AppConfig.openAiApiKey}',
    };
    
    // Agregar interceptor para trackear uso de APIs
    _dio.interceptors.add(ApiUsageInterceptor());
  }

  Future<String> transcribeAudio(String audioPath) async {
    try {
      final file = File(audioPath);
      if (!file.existsSync()) {
        throw Exception('Archivo de audio no encontrado');
      }

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          audioPath,
          filename: 'audio.m4a',
        ),
        'model': AppConfig.whisperModel,
        'language': 'es',
        'response_format': 'json',
      });

      final response = await _dio.post(
        '${AppConfig.openAiBaseUrl}/audio/transcriptions',
        data: formData,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        final transcription = response.data['text'] as String?;
        if (transcription == null || transcription.isEmpty) {
          throw Exception('No se pudo transcribir el audio');
        }
        return transcription.trim();
      } else {
        final error = response.data['error']?['message'] ?? 'Error desconocido';
        throw Exception('Error de Whisper API: $error');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Tiempo de conexión agotado');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Tiempo de respuesta agotado');
      } else {
        throw Exception('Error de red: ${e.message}');
      }
    } catch (e) {
      throw Exception('Error al transcribir audio: $e');
    }
  }
} 