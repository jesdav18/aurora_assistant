import 'package:dio/dio.dart';
import 'api_usage_tracker.dart';

class ApiUsageInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Identificar tipo de API por URL
    String apiType = _identifyApiType(options.uri.toString());
    
    if (apiType != 'unknown') {
      // Calcular tokens estimados para OpenAI
      int estimatedTokens = _estimateTokens(options.data, apiType);
      
      // Trackear la llamada (async pero no esperamos)
      ApiUsageTracker.trackApiCall(apiType, tokens: estimatedTokens);
    }
    
    super.onRequest(options, handler);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Aquí podríamos trackear respuestas exitosas si necesitáramos
    super.onResponse(response, handler);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Aquí podríamos trackear errores si necesitáramos
    print('🚨 API Error: ${err.requestOptions.uri} - ${err.message}');
    super.onError(err, handler);
  }
  
  /// Identificar el tipo de API basado en la URL
  String _identifyApiType(String url) {
    if (url.contains('openai.com/v1/chat/completions')) {
      return 'openai_chat';
    }
    if (url.contains('openai.com/v1/audio/transcriptions')) {
      return 'openai_whisper';
    }
    if (url.contains('api.mapbox.com/geocoding')) {
      return 'mapbox_geocoding';
    }
    if (url.contains('api.mapbox.com/directions')) {
      return 'mapbox_directions';
    }
    if (url.contains('openrouteservice.org')) {
      return 'openroute_directions';
    }
    if (url.contains('nominatim.openstreetmap.org')) {
      return 'nominatim';
    }
    
    return 'unknown';
  }
  
  /// Estimar tokens para llamadas de OpenAI
  int _estimateTokens(dynamic data, String apiType) {
    if (apiType == 'openai_chat' && data is Map) {
      // Estimar tokens basado en el contenido del mensaje
      String content = '';
      if (data['messages'] is List) {
        for (var msg in data['messages']) {
          if (msg['content'] != null) {
            content += msg['content'].toString();
          }
        }
      }
      
      // Aproximación: ~4 caracteres por token
      int inputTokens = (content.length / 4).ceil();
      
      // Agregar tokens de respuesta estimados (max_tokens del request)
      int maxTokens = data['max_tokens'] ?? 150;
      
      return inputTokens + maxTokens;
    }
    
    if (apiType == 'openai_whisper') {
      // Para Whisper, estimamos por duración de audio
      // Como no tenemos la duración exacta, usamos un promedio de 30 segundos
      return 30; // Representando 30 segundos de audio
    }
    
    // Para otras APIs, un token representa una petición
    return 1;
  }
} 