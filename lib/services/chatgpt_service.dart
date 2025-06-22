import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'location_service.dart';
import 'navigation_service.dart';

class ChatGPTService {
  final Dio _dio = Dio();
  final LocationService _locationService = LocationService();
  final NavigationService _navigationService = NavigationService();
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
      
      // Comando de prueba para navegación
      if (message.toLowerCase().contains('probar navegación') || 
          message.toLowerCase().contains('test navigation')) {
        try {
          final testResult = await _locationService.testNavigationFunctionality();
          enhancedMessage = '$message\n\nResultado de prueba: $testResult';
        } catch (e) {
          enhancedMessage = '$message\n\nError en prueba: $e';
        }
      } else if (_isStartNavigationQuery(message)) {
        try {
          final navigationInfo = await _handleStartNavigationQuery(message);
          enhancedMessage = '$message\n\nInformación de navegación: $navigationInfo';
        } catch (e) {
          enhancedMessage = '$message\n\nError al iniciar navegación: $e';
        }
      } else if (_isLocationQuery(message)) {
        try {
          // Usar el método más apropiado según el tipo de consulta
          String locationInfo;
          if (_isSimpleLocationQuery(message)) {
            locationInfo = await _locationService.getSimpleLocationInfo();
          } else {
            locationInfo = await _locationService.getDetailedLocationInfo();
          }
          enhancedMessage = '$message\n\nInformación de ubicación actual: $locationInfo';
        } catch (e) {
          enhancedMessage = '$message\n\nNota: No se pudo obtener la ubicación debido a: $e';
        }
      } else if (_isNavigationQuery(message)) {
        try {
          final navigationInfo = await _handleNavigationQuery(message);
          enhancedMessage = '$message\n\nInformación de navegación: $navigationInfo';
        } catch (e) {
          enhancedMessage = '$message\n\nNota: No se pudo procesar la consulta de navegación debido a: $e';
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
      'lugar', 'sitio', 'localización', 'localizacion', 'gps', 'maps',
      'estoy en', 'me encuentro en', 'mi ubicación', 'mi ubicacion'
    ];
    
    final messageLower = message.toLowerCase();
    return locationKeywords.any((keyword) => messageLower.contains(keyword));
  }

  bool _isNavigationQuery(String message) {
    final navigationKeywords = [
      'ruta', 'camino', 'dirección', 'direccion', 'como llegar', 'cómo llegar',
      'navegar', 'conducir', 'ir a', 'llevar', 'mejor ruta', 'ruta más rápida',
      'ruta más corta', 'calcular ruta', 'planificar ruta', 'waypoints',
      'pasando por', 'a través de', 'por donde', 'alternativas'
    ];
    
    final messageLower = message.toLowerCase();
    return navigationKeywords.any((keyword) => messageLower.contains(keyword));
  }

  Future<String> _handleNavigationQuery(String message) async {
    final messageLower = message.toLowerCase();
    
    print('🔍 Procesando consulta de navegación: $message');
    
    // Detectar si es búsqueda de lugar
    if (_isPlaceSearchQuery(message)) {
      print('📍 Detectada búsqueda de lugar');
      final placeQuery = _extractPlaceQuery(message);
      if (placeQuery.isNotEmpty) {
        print('🔎 Buscando lugar: $placeQuery');
        return await _locationService.searchPlace(placeQuery);
      }
    }
    
    // Detectar si es cálculo de ruta
    if (_isRouteCalculationQuery(message)) {
      print('🗺️ Detectado cálculo de ruta');
      final routeInfo = _extractRouteInfo(message);
      print('🎯 Información de ruta extraída: $routeInfo');
      
      if (routeInfo['destination'] != null) {
        final destination = routeInfo['destination'] as String;
        print('📍 Destino: $destination');
        
        if (routeInfo['waypoints'] != null && routeInfo['waypoints'].isNotEmpty) {
          print('🛣️ Calculando ruta con waypoints');
          return await _locationService.calculateRoute(
            destination,
            waypoints: routeInfo['waypoints'],
          );
        } else {
          print('🛣️ Calculando mejor ruta');
          return await _locationService.calculateBestRoute(destination);
        }
      } else {
        print('❌ No se pudo extraer el destino de la consulta');
      }
    }
    
    print('❌ No se pudo procesar la consulta de navegación');
    return 'Por favor, especifica un destino para calcular la ruta. Por ejemplo: "Calcula la ruta a Madrid" o "¿Cómo llego al aeropuerto?" o "Mejor ruta a Choloma"';
  }

  bool _isPlaceSearchQuery(String message) {
    final searchKeywords = [
      'buscar', 'encontrar', 'dónde está', 'donde esta', 'localizar',
      'hay un', 'hay una', 'existe', 'cerca de', 'cerca a'
    ];
    
    final messageLower = message.toLowerCase();
    return searchKeywords.any((keyword) => messageLower.contains(keyword));
  }

  bool _isRouteCalculationQuery(String message) {
    final routeKeywords = [
      'ruta a', 'ruta hacia', 'ruta para', 'camino a', 'camino hacia', 'camino para',
      'dirección a', 'direccion a', 'dirección hacia', 'direccion hacia',
      'como llegar a', 'cómo llegar a', 'como llegar hacia', 'cómo llegar hacia',
      'ir a', 'llevar a', 'conducir a', 'navegar a', 'mejor ruta', 'ruta más rápida',
      'ruta más corta', 'calcular ruta', 'planificar ruta', 'ruta para ir',
      'mejor ruta para', 'ruta más rápida para', 'ruta más corta para'
    ];
    
    final messageLower = message.toLowerCase();
    return routeKeywords.any((keyword) => messageLower.contains(keyword));
  }

  String _extractPlaceQuery(String message) {
    // Extraer el lugar a buscar después de palabras clave
    final searchPatterns = [
      RegExp(r'buscar\s+(.+)', caseSensitive: false),
      RegExp(r'encontrar\s+(.+)', caseSensitive: false),
      RegExp(r'dónde está\s+(.+)', caseSensitive: false),
      RegExp(r'donde esta\s+(.+)', caseSensitive: false),
      RegExp(r'localizar\s+(.+)', caseSensitive: false),
    ];
    
    for (final pattern in searchPatterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        return match.group(1)?.trim() ?? '';
      }
    }
    
    return '';
  }

  Map<String, dynamic> _extractRouteInfo(String message) {
    final routePatterns = [
      // Patrones más específicos primero
      RegExp(r'mejor ruta\s+(?:para\s+)?(?:ir\s+)?(?:de\s+mi\s+ubicación\s+)?(?:hacia|a|para)\s+(.+)', caseSensitive: false),
      RegExp(r'ruta\s+(?:más\s+)?(?:rápida|corta)\s+(?:para\s+)?(?:ir\s+)?(?:hacia|a|para)\s+(.+)', caseSensitive: false),
      RegExp(r'calcular\s+ruta\s+(?:para\s+)?(?:ir\s+)?(?:hacia|a|para)\s+(.+)', caseSensitive: false),
      RegExp(r'planificar\s+ruta\s+(?:para\s+)?(?:ir\s+)?(?:hacia|a|para)\s+(.+)', caseSensitive: false),
      // Patrones generales
      RegExp(r'ruta\s+(?:a|hacia|para)\s+(.+)', caseSensitive: false),
      RegExp(r'camino\s+(?:a|hacia|para)\s+(.+)', caseSensitive: false),
      RegExp(r'dirección\s+(?:a|hacia|para)\s+(.+)', caseSensitive: false),
      RegExp(r'direccion\s+(?:a|hacia|para)\s+(.+)', caseSensitive: false),
      RegExp(r'como llegar\s+(?:a|hacia|para)\s+(.+)', caseSensitive: false),
      RegExp(r'cómo llegar\s+(?:a|hacia|para)\s+(.+)', caseSensitive: false),
      RegExp(r'ir\s+a\s+(.+)', caseSensitive: false),
      RegExp(r'llevar\s+a\s+(.+)', caseSensitive: false),
      RegExp(r'conducir\s+a\s+(.+)', caseSensitive: false),
      RegExp(r'navegar\s+a\s+(.+)', caseSensitive: false),
      // Patrones adicionales para casos específicos
      RegExp(r'mejor\s+ruta\s+(.+)', caseSensitive: false),
      RegExp(r'ruta\s+para\s+ir\s+(.+)', caseSensitive: false),
    ];
    
    String? destination;
    List<String> waypoints = [];
    
    for (final pattern in routePatterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        destination = match.group(1)?.trim();
        break;
      }
    }
    
    // Extraer waypoints si existen
    final waypointPatterns = [
      RegExp(r'pasando\s+por\s+(.+)', caseSensitive: false),
      RegExp(r'a\s+través\s+de\s+(.+)', caseSensitive: false),
      RegExp(r'por\s+donde\s+(.+)', caseSensitive: false),
    ];
    
    for (final pattern in waypointPatterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final waypointText = match.group(1)?.trim() ?? '';
        if (waypointText.isNotEmpty) {
          waypoints.add(waypointText);
        }
      }
    }
    
    return {
      'destination': destination,
      'waypoints': waypoints.isNotEmpty ? waypoints : null,
    };
  }

  bool _isSimpleLocationQuery(String message) {
    final simpleLocationKeywords = [
      'donde estoy', 'dónde estoy', 'donde me encuentro', 'estoy en', 
      'me encuentro en', 'mi ubicación', 'mi ubicacion', 'lugar', 'sitio'
    ];
    
    final messageLower = message.toLowerCase();
    return simpleLocationKeywords.any((keyword) => messageLower.contains(keyword));
  }

  bool _isStartNavigationQuery(String message) {
    final startNavigationKeywords = [
      'iniciar navegación', 'iniciar ruta', 'empezar navegación', 'empezar ruta',
      'navegar a', 'conducir a', 'llevar a', 'ir a', 'inicia navegación',
      'empieza navegación', 'comenzar navegación', 'comenzar ruta',
      'start navigation', 'begin navigation', 'navigate to'
    ];
    
    final messageLower = message.toLowerCase();
    return startNavigationKeywords.any((keyword) => messageLower.contains(keyword));
  }

  Future<String> _handleStartNavigationQuery(String message) async {
    print('🚀 Procesando inicio de navegación: $message');
    
    // Extraer destino
    final destination = _extractDestinationFromStartNavigation(message);
    if (destination.isEmpty) {
      return 'Por favor, especifica un destino para iniciar la navegación. Por ejemplo: "Iniciar navegación a Madrid"';
    }
    
    print('📍 Destino para navegación: $destination');
    
    // Verificar si ya estamos navegando
    if (_navigationService.isNavigating) {
      return 'Ya estás navegando hacia ${_navigationService.destinationName}. ¿Quieres detener la navegación actual?';
    }
    
    // Iniciar navegación
    final success = await _navigationService.startNavigation(destination);
    print('✅ Resultado de startNavigation: $success');
    print('📍 DestinationName después de startNavigation: ${_navigationService.destinationName}');
    
    if (success) {
      return 'Navegación iniciada hacia $destination. Abriendo mapa de navegación...';
    } else {
      return 'No se pudo iniciar la navegación hacia $destination. Verifica que el destino sea válido.';
    }
  }

  String _extractDestinationFromStartNavigation(String message) {
    print('🔍 Extrayendo destino de: "$message"');
    
    final startNavigationPatterns = [
      // Patrones más específicos para "empieza navegación hacia"
      RegExp(r'empieza\s+navegación\s+(?:a|hacia|para)\s+(.+)', caseSensitive: false),
      RegExp(r'inicia\s+navegación\s+(?:a|hacia|para)\s+(.+)', caseSensitive: false),
      RegExp(r'comenzar\s+navegación\s+(?:a|hacia|para)\s+(.+)', caseSensitive: false),
      RegExp(r'empezar\s+navegación\s+(?:a|hacia|para)\s+(.+)', caseSensitive: false),
      RegExp(r'iniciar\s+navegación\s+(?:a|hacia|para)\s+(.+)', caseSensitive: false),
      // Patrones para rutas
      RegExp(r'empieza\s+ruta\s+(?:a|hacia|para)\s+(.+)', caseSensitive: false),
      RegExp(r'inicia\s+ruta\s+(?:a|hacia|para)\s+(.+)', caseSensitive: false),
      RegExp(r'comenzar\s+ruta\s+(?:a|hacia|para)\s+(.+)', caseSensitive: false),
      RegExp(r'empezar\s+ruta\s+(?:a|hacia|para)\s+(.+)', caseSensitive: false),
      RegExp(r'iniciar\s+ruta\s+(?:a|hacia|para)\s+(.+)', caseSensitive: false),
      // Patrones generales
      RegExp(r'navegar\s+a\s+(.+)', caseSensitive: false),
      RegExp(r'conducir\s+a\s+(.+)', caseSensitive: false),
      RegExp(r'llevar\s+a\s+(.+)', caseSensitive: false),
      RegExp(r'ir\s+a\s+(.+)', caseSensitive: false),
    ];
    
    for (int i = 0; i < startNavigationPatterns.length; i++) {
      final pattern = startNavigationPatterns[i];
      final match = pattern.firstMatch(message);
      if (match != null) {
        String destination = match.group(1)?.trim() ?? '';
        
        // Limpiar el destino: remover puntos, comas y otros caracteres al final
        destination = destination.replaceAll(RegExp(r'[.,;!?]+$'), '').trim();
        
        print('✅ Patrón $i coincidió: "$destination"');
        return destination;
      }
    }
    
    print('❌ Ningún patrón coincidió');
    return '';
  }

  // Getter para acceder al servicio de navegación
  NavigationService get navigationService => _navigationService;

  void clearHistory() {
    _conversationHistory.clear();
    _conversationHistory.add({
      'role': 'system',
      'content': AppConfig.systemPrompt,
    });
  }
} 