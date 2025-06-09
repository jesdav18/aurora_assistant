import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'location_service.dart';

class ChatGPTService {
  final Dio _dio = Dio();
  final LocationService _locationService = LocationService();
  final List<Map<String, String>> _conversationHistory = [];

  ChatGPTService() {
    _dio.options.headers = {
      'Authorization': 'Bearer ${AppConfig.openAiApiKey}',
      'Content-Type': 'application/json',
    };
    
    _conversationHistory.add({
      'role': 'system',
      'content': AppConfig.systemPrompt,
    });
  }

  Future<String> sendMessage(String message) async {
    try {
      String enhancedMessage = message;
      
      if (_isLocationQuery(message)) {
        try {
          final locationInfo = await _locationService.getDetailedLocationInfo();
          enhancedMessage = '$message\n\nInformación de ubicación actual: $locationInfo';
        } catch (e) {
          enhancedMessage = '$message\n\nNota: No se pudo obtener la ubicación debido a: $e';
        }
      }

      _conversationHistory.add({
        'role': 'user',
        'content': enhancedMessage,
      });

      final requestData = {
        'model': AppConfig.chatGptModel,
        'messages': _conversationHistory,
        'max_tokens': AppConfig.maxTokens,
        'temperature': AppConfig.temperature,
        'top_p': 1.0,
        'frequency_penalty': 0.0,
        'presence_penalty': 0.0,
      };

      final response = await _dio.post(
        '${AppConfig.openAiBaseUrl}/chat/completions',
        data: requestData,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        final choices = response.data['choices'] as List?;
        if (choices == null || choices.isEmpty) {
          throw Exception('No se recibió respuesta del modelo');
        }

        final assistantMessage = choices[0]['message']['content'] as String?;
        if (assistantMessage == null || assistantMessage.isEmpty) {
          throw Exception('Respuesta vacía del modelo');
        }

        _conversationHistory.add({
          'role': 'assistant',
          'content': assistantMessage,
        });

        if (_conversationHistory.length > AppConfig.maxConversationHistory) {
          _conversationHistory.removeRange(1, _conversationHistory.length - 15);
        }

        return assistantMessage.trim();
      } else {
        final error = response.data['error']?['message'] ?? 'Error desconocido';
        throw Exception('Error de ChatGPT API: $error');
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
      throw Exception('Error al enviar mensaje: $e');
    }
  }

  bool _isLocationQuery(String message) {
    final locationKeywords = [
      'ubicación', 'ubicacion', 'donde estoy', 'dónde estoy', 'donde me encuentro',
      'mi posición', 'mi posicion', 'coordenadas', 'dirección', 'direccion',
      'lugar', 'sitio', 'localización', 'localizacion', 'gps', 'maps'
    ];
    
    final messageLower = message.toLowerCase();
    return locationKeywords.any((keyword) => messageLower.contains(keyword));
  }

  void clearHistory() {
    _conversationHistory.clear();
    _conversationHistory.add({
      'role': 'system',
      'content': AppConfig.systemPrompt,
    });
  }
} 