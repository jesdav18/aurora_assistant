import 'package:location/location.dart';
import 'package:dio/dio.dart';
import 'dart:math' as math;
import '../config/app_config.dart';
import 'api_interceptor.dart';

class LocationService {
  final Location _location = Location();

  Future<bool> _requestLocationPermissions() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return false;
      }
    }

    return true;
  }

  Future<LocationData?> getCurrentPosition() async {
    try {
      final hasPermission = await _requestLocationPermissions();
      if (!hasPermission) {
        throw Exception('Permisos de ubicación denegados');
      }

      final locationData = await _location.getLocation();
      return locationData;
    } catch (e) {
      throw Exception('Error al obtener ubicación: $e');
    }
  }

  Future<String> getLocationDescription() async {
    try {
      final locationData = await getCurrentPosition();
      if (locationData == null || locationData.latitude == null || locationData.longitude == null) {
        throw Exception('No se pudo obtener la ubicación');
      }

      final address = await _getAddressFromCoordinates(
        locationData.latitude!,
        locationData.longitude!,
      );

      return address;
    } catch (e) {
      throw Exception('Error al obtener descripción de ubicación: $e');
    }
  }

  Future<String> _getAddressFromCoordinates(double lat, double lon) async {
    // Intentar primero con Mapbox
    try {
      final address = await _getAddressFromMapbox(lat, lon);
      if (address != null && address != 'Ubicación no disponible') {
        return address;
      }
    } catch (e) {
      print('Error con Mapbox: $e');
    }

    // Si Mapbox falla, intentar con OpenStreetMap Nominatim
    try {
      final address = await _getAddressFromNominatim(lat, lon);
      if (address != null && address != 'Ubicación no disponible') {
        return address;
      }
    } catch (e) {
      print('Error con Nominatim: $e');
    }

    // Si ambos fallan, devolver coordenadas formateadas
    return _formatCoordinates(lat, lon);
  }

  Future<String?> _getAddressFromMapbox(double lat, double lon) async {
    try {
      final dio = Dio();
      // Agregar interceptor para trackear uso de APIs
      dio.interceptors.add(ApiUsageInterceptor());
      
      final response = await dio.get(
        '${AppConfig.mapboxGeocodingUrl}/$lon,$lat.json',
        queryParameters: {
          'access_token': AppConfig.mapboxAccessToken,
          'limit': 1,
          'language': 'es',
          'types': 'poi,address,place,neighborhood,locality',
        },
        options: Options(
          sendTimeout: Duration(seconds: AppConfig.geocodingTimeout),
          receiveTimeout: Duration(seconds: AppConfig.geocodingReceiveTimeout),
        ),
      );

      if (response.statusCode == 200 && response.data['features'] != null && response.data['features'].isNotEmpty) {
        final feature = response.data['features'][0];
        final placeName = feature['place_name'] as String?;
        
        if (placeName != null && placeName.isNotEmpty) {
          // Limpiar y formatear la respuesta
          return _cleanAddress(placeName);
        }
      }
      return null;
    } catch (e) {
      throw Exception('Error en Mapbox: $e');
    }
  }

  Future<String?> _getAddressFromNominatim(double lat, double lon) async {
    try {
      final dio = Dio();
      // Agregar interceptor para trackear uso de APIs
      dio.interceptors.add(ApiUsageInterceptor());
      
      final response = await dio.get(
        AppConfig.nominatimUrl,
        queryParameters: {
          'lat': lat.toString(),
          'lon': lon.toString(),
          'format': 'json',
          'accept-language': 'es',
          'addressdetails': '1',
          'zoom': '18',
        },
        options: Options(
          headers: {
            'User-Agent': 'AuroraAssistant/1.0',
          },
          sendTimeout: Duration(seconds: AppConfig.geocodingTimeout),
          receiveTimeout: Duration(seconds: AppConfig.geocodingReceiveTimeout),
        ),
      );

      if (response.statusCode == 200 && response.data['display_name'] != null) {
        final displayName = response.data['display_name'] as String;
        return _cleanAddress(displayName);
      }
      return null;
    } catch (e) {
      throw Exception('Error en Nominatim: $e');
    }
  }

  String _cleanAddress(String address) {
    // Limpiar y formatear la dirección para que sea más legible
    String cleaned = address.trim();
    
    // Remover información redundante
    cleaned = cleaned.replaceAll(RegExp(r',\s*,+'), ',');
    cleaned = cleaned.replaceAll(RegExp(r'^\s*,\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*,\s*$'), '');
    
    // Si la dirección es muy larga, tomar solo las partes más importantes
    final parts = cleaned.split(',');
    if (parts.length > 4) {
      // Tomar el primer elemento (dirección específica) y los últimos 3 (ciudad, estado, país)
      final importantParts = [parts.first, ...parts.sublist(parts.length - 3)];
      cleaned = importantParts.join(', ');
    }
    
    return cleaned;
  }

  String _formatCoordinates(double lat, double lon) {
    // Formatear coordenadas de manera más amigable
    final latStr = lat >= 0 ? '${lat.toStringAsFixed(6)}°N' : '${lat.abs().toStringAsFixed(6)}°S';
    final lonStr = lon >= 0 ? '${lon.toStringAsFixed(6)}°E' : '${lon.abs().toStringAsFixed(6)}°W';
    return 'Coordenadas: $latStr, $lonStr';
  }

  Future<String> getDetailedLocationInfo() async {
    try {
      final locationData = await getCurrentPosition();
      if (locationData == null || locationData.latitude == null || locationData.longitude == null) {
        throw Exception('No se pudo obtener la ubicación');
      }

      final description = await getLocationDescription();
      
      // Si tenemos una descripción de dirección, usarla; si no, solo coordenadas
      if (description.startsWith('Coordenadas:')) {
        return 'Tu ubicación actual es: $description. '
            'Precisión: ${locationData.accuracy?.toStringAsFixed(1) ?? 'N/A'} metros.';
      } else {
      return 'Tu ubicación actual es: $description. '
          'Coordenadas exactas: ${locationData.latitude!.toStringAsFixed(6)}, ${locationData.longitude!.toStringAsFixed(6)}. '
          'Precisión: ${locationData.accuracy?.toStringAsFixed(1) ?? 'N/A'} metros.';
      }
    } catch (e) {
      throw Exception('Error al obtener información detallada: $e');
    }
  }

  Future<String> getSimpleLocationInfo() async {
    try {
      final locationData = await getCurrentPosition();
      if (locationData == null || locationData.latitude == null || locationData.longitude == null) {
        throw Exception('No se pudo obtener la ubicación');
      }

      final description = await getLocationDescription();
      
      // Para consultas simples de ubicación, devolver solo la descripción
      if (description.startsWith('Coordenadas:')) {
        return 'Estás en: $description';
      } else {
        return 'Estás en: $description';
      }
    } catch (e) {
      throw Exception('Error al obtener información de ubicación: $e');
    }
  }

  Future<double> getDistanceTo(double targetLat, double targetLon) async {
    try {
      final locationData = await getCurrentPosition();
      if (locationData == null || locationData.latitude == null || locationData.longitude == null) {
        throw Exception('No se pudo obtener la ubicación actual');
      }

      final distance = _calculateDistance(
        locationData.latitude!,
        locationData.longitude!,
        targetLat,
        targetLon,
      );

      return distance;
    } catch (e) {
      throw Exception('Error al calcular distancia: $e');
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    
    final double lat1Rad = lat1 * (math.pi / 180);
    final double lat2Rad = lat2 * (math.pi / 180);
    final double deltaLatRad = (lat2 - lat1) * (math.pi / 180);
    final double deltaLonRad = (lon2 - lon1) * (math.pi / 180);

    final double a = math.pow(math.sin(deltaLatRad / 2), 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.pow(math.sin(deltaLonRad / 2), 2);
    final double c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c;
  }

  // ===== NUEVAS FUNCIONALIDADES DE NAVEGACIÓN =====

  Future<String> searchPlace(String query) async {
    try {
      final dio = Dio();
      // Agregar interceptor para trackear uso de APIs
      dio.interceptors.add(ApiUsageInterceptor());
      
      final response = await dio.get(
        '${AppConfig.mapboxGeocodingUrl}/$query.json',
        queryParameters: {
          'access_token': AppConfig.mapboxAccessToken,
          'limit': 5,
          'language': 'es',
          'types': 'poi,address,place',
          'country': 'es', // Priorizar España, puedes cambiar esto
        },
        options: Options(
          sendTimeout: Duration(seconds: AppConfig.geocodingTimeout),
          receiveTimeout: Duration(seconds: AppConfig.geocodingReceiveTimeout),
        ),
      );

      if (response.statusCode == 200 && response.data['features'] != null && response.data['features'].isNotEmpty) {
        final features = response.data['features'] as List;
        final results = features.map((feature) {
          final placeName = feature['place_name'] as String? ?? 'Sin nombre';
          final coordinates = feature['center'] as List?;
          return {
            'name': placeName,
            'coordinates': coordinates != null ? [coordinates[1], coordinates[0]] : null,
          };
        }).toList();

        return _formatSearchResults(results);
      } else {
        return 'No encontré lugares que coincidan con "$query"';
      }
    } catch (e) {
      throw Exception('Error al buscar lugar: $e');
    }
  }

  Future<String> calculateRoute(String destination, {List<String>? waypoints}) async {
    try {
      // Obtener ubicación actual
      final currentLocation = await getCurrentPosition();
      if (currentLocation == null || currentLocation.latitude == null || currentLocation.longitude == null) {
        throw Exception('No se pudo obtener tu ubicación actual');
      }

      // Buscar destino
      final destinationCoords = await getCoordinatesFromAddress(destination);
      if (destinationCoords == null) {
        throw Exception('No se pudo encontrar el destino: $destination');
      }

      // Construir waypoints
      List<List<double>> allWaypoints = [
        [currentLocation.longitude!, currentLocation.latitude!], // Origen
      ];

      // Agregar waypoints intermedios si existen
      if (waypoints != null && waypoints.isNotEmpty) {
        for (String waypoint in waypoints) {
          final waypointCoords = await getCoordinatesFromAddress(waypoint);
          if (waypointCoords != null) {
            allWaypoints.add(waypointCoords);
          }
        }
      }

      allWaypoints.add(destinationCoords); // Destino final

      // Calcular ruta
      final routeInfo = await _getRouteFromMapbox(allWaypoints);
      
      // Formatear la respuesta
      final distance = routeInfo['distance'].toStringAsFixed(1);
      final duration = routeInfo['duration'].toStringAsFixed(0);
      
      String response = 'Ruta hacia $destination:\n';
      response += 'Distancia: ${distance} km\n';
      response += 'Tiempo estimado: ${duration} minutos';
      
      if (waypoints != null && waypoints.isNotEmpty) {
        response += '\nPasando por: ${waypoints.join(', ')}';
      }
      
      return response;
    } catch (e) {
      throw Exception('Error al calcular ruta: $e');
    }
  }

  Future<String> calculateBestRoute(String destination, {List<String>? alternatives}) async {
    try {
      // Obtener ubicación actual
      final currentLocation = await getCurrentPosition();
      if (currentLocation == null || currentLocation.latitude == null || currentLocation.longitude == null) {
        throw Exception('No se pudo obtener tu ubicación actual');
      }

      // Buscar destino
      final destinationCoords = await getCoordinatesFromAddress(destination);
      if (destinationCoords == null) {
        throw Exception('No se pudo encontrar el destino: $destination');
      }

      // Calcular múltiples rutas
      final routes = await _getMultipleRoutesFromMapbox(
        [currentLocation.longitude!, currentLocation.latitude!],
        destinationCoords,
        alternatives: alternatives,
      );

      return _formatMultipleRoutes(routes, destination);
    } catch (e) {
      throw Exception('Error al calcular mejores rutas: $e');
    }
  }

  Future<List<double>?> getCoordinatesFromAddress(String address) async {
    try {
      print('🌍 Geocodificando dirección: $address');
      
      // Intentar primero con Mapbox
      try {
        final dio = Dio();
        // Agregar interceptor para trackear uso de APIs
        dio.interceptors.add(ApiUsageInterceptor());
        
        // Codificar la dirección para la URL
        final encodedAddress = Uri.encodeComponent(address);
        print('🔗 Dirección codificada: $encodedAddress');
        
        final url = '${AppConfig.mapboxGeocodingUrl}/$encodedAddress.json';
        print('🌐 URL completa: $url');
        
        final response = await dio.get(
          url,
          queryParameters: {
            'access_token': AppConfig.mapboxAccessToken,
            'limit': 1,
            'language': 'es',
            'types': 'poi,address,place,neighborhood,locality',
          },
          options: Options(
            sendTimeout: Duration(seconds: AppConfig.geocodingTimeout),
            receiveTimeout: Duration(seconds: AppConfig.geocodingReceiveTimeout),
          ),
        );

        print('📡 Respuesta de geocodificación Mapbox: ${response.statusCode}');
        print('📄 Datos de respuesta: ${response.data}');
        
        if (response.statusCode == 200 && response.data['features'] != null && response.data['features'].isNotEmpty) {
          final feature = response.data['features'][0];
          final coordinates = feature['center'] as List?;
          if (coordinates != null && coordinates.length >= 2) {
            final result = [coordinates[1] as double, coordinates[0] as double]; // [lat, lon]
            print('✅ Coordenadas encontradas con Mapbox: $result');
            print('📍 Lugar encontrado: ${feature['place_name']}');
            return result;
          }
        }
      } catch (e) {
        print('❌ Error con Mapbox: $e');
        print('🔄 Intentando con Nominatim...');
      }
      
      // Si Mapbox falla, intentar con Nominatim
      try {
        final dio = Dio();
        // Agregar interceptor para trackear uso de APIs
        dio.interceptors.add(ApiUsageInterceptor());
        
        final response = await dio.get(
          'https://nominatim.openstreetmap.org/search',
          queryParameters: {
            'q': address,
            'format': 'json',
            'limit': 1,
            'accept-language': 'es',
          },
          options: Options(
            headers: {
              'User-Agent': 'AuroraAssistant/1.0',
            },
            sendTimeout: Duration(seconds: AppConfig.geocodingTimeout),
            receiveTimeout: Duration(seconds: AppConfig.geocodingReceiveTimeout),
          ),
        );

        print('📡 Respuesta de geocodificación Nominatim: ${response.statusCode}');
        
        if (response.statusCode == 200 && response.data is List && response.data.isNotEmpty) {
          final result = response.data[0];
          final lat = double.tryParse(result['lat']?.toString() ?? '');
          final lon = double.tryParse(result['lon']?.toString() ?? '');
          
          if (lat != null && lon != null) {
            final coordinates = [lat, lon];
            print('✅ Coordenadas encontradas con Nominatim: $coordinates');
            print('📍 Lugar encontrado: ${result['display_name']}');
            return coordinates;
          }
        }
      } catch (e) {
        print('❌ Error con Nominatim: $e');
      }
      
      print('❌ No se pudo geocodificar con ningún servicio');
      return null;
    } catch (e) {
      print('❌ Error general en geocodificación: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _getRouteFromMapbox(List<List<double>> waypoints) async {
    try {
      final dio = Dio();
      // Agregar interceptor para trackear uso de APIs
      dio.interceptors.add(ApiUsageInterceptor());
      
      // Construir string de coordenadas para la API
      final coordinatesString = waypoints.map((coord) => '${coord[0]},${coord[1]}').join(';');
      
      final response = await dio.get(
        '${AppConfig.mapboxDirectionsUrl}/$coordinatesString.json',
        queryParameters: {
          'access_token': AppConfig.mapboxAccessToken,
          'language': 'es',
          'overview': 'full',
          'steps': 'true',
        },
        options: Options(
          sendTimeout: Duration(seconds: AppConfig.navigationTimeout),
          receiveTimeout: Duration(seconds: AppConfig.navigationReceiveTimeout),
        ),
      );

      if (response.statusCode == 200 && response.data['routes'] != null && response.data['routes'].isNotEmpty) {
        final route = response.data['routes'][0];
        return {
          'distance': route['distance'] / 1000, // Convertir a km
          'duration': route['duration'] / 60, // Convertir a minutos
          'steps': route['legs']?[0]?['steps'] ?? [],
        };
      } else {
        throw Exception('No se pudo calcular la ruta');
      }
    } catch (e) {
      throw Exception('Error al obtener ruta de Mapbox: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getMultipleRoutesFromMapbox(
    List<double> origin, 
    List<double> destination, 
    {List<String>? alternatives}
  ) async {
    try {
      final dio = Dio();
      // Agregar interceptor para trackear uso de APIs
      dio.interceptors.add(ApiUsageInterceptor());
      
      final coordinatesString = '${origin[0]},${origin[1]};${destination[0]},${destination[1]}';
      
      final response = await dio.get(
        '${AppConfig.mapboxDirectionsUrl}/$coordinatesString.json',
        queryParameters: {
          'access_token': AppConfig.mapboxAccessToken,
          'language': 'es',
          'overview': 'full',
          'steps': 'true',
          'alternatives': 'true',
        },
        options: Options(
          sendTimeout: Duration(seconds: AppConfig.navigationTimeout),
          receiveTimeout: Duration(seconds: AppConfig.navigationReceiveTimeout),
        ),
      );

      if (response.statusCode == 200 && response.data['routes'] != null) {
        final routes = response.data['routes'] as List;
        return routes.map((route) => {
          'distance': route['distance'] / 1000,
          'duration': route['duration'] / 60,
          'steps': route['legs']?[0]?['steps'] ?? [],
        }).toList();
      } else {
        throw Exception('No se pudieron calcular las rutas');
      }
    } catch (e) {
      throw Exception('Error al obtener múltiples rutas: $e');
    }
  }

  String _formatSearchResults(List<Map<String, dynamic>> results) {
    if (results.isEmpty) {
      return 'No se encontraron resultados';
    }

    String response = 'Encontré estos lugares:\n';
    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      response += '${i + 1}. ${result['name']}\n';
    }
    
    return response.trim();
  }

  String _formatMultipleRoutes(List<Map<String, dynamic>> routes, String destination) {
    if (routes.isEmpty) {
      return 'No se pudieron calcular rutas hacia $destination';
    }

    String response = 'Rutas hacia $destination:\n\n';
    
    for (int i = 0; i < routes.length; i++) {
      final route = routes[i];
      final distance = route['distance'].toStringAsFixed(1);
      final duration = route['duration'].toStringAsFixed(0);
      
      response += 'Ruta ${i + 1}: ${distance} km, ${duration} minutos\n';
    }
    
    // Agregar la mejor ruta (la primera)
    final bestRoute = routes.first;
    final bestDistance = bestRoute['distance'].toStringAsFixed(1);
    final bestDuration = bestRoute['duration'].toStringAsFixed(0);
    
    response += '\nLa mejor ruta es: ${bestDistance} km en ${bestDuration} minutos.';
    
    return response;
  }

  // ===== MÉTODO DE PRUEBA =====
  
  Future<String> testNavigationFunctionality() async {
    try {
      print('🧪 Iniciando prueba de funcionalidad de navegación');
      
      // Probar geocodificación
      final testAddress = 'Choloma, Honduras';
      print('🌍 Probando geocodificación de: $testAddress');
      
      final coordinates = await getCoordinatesFromAddress(testAddress);
      if (coordinates != null) {
        print('✅ Geocodificación exitosa: $coordinates');
        
        // Probar cálculo de ruta
        print('🛣️ Probando cálculo de ruta');
        final routeResult = await calculateBestRoute(testAddress);
        print('✅ Resultado de ruta: $routeResult');
        return 'Prueba exitosa: $routeResult';
      } else {
        print('❌ Fallo en geocodificación');
        return 'Error: No se pudo geocodificar la dirección de prueba';
      }
    } catch (e) {
      print('❌ Error en prueba: $e');
      return 'Error en prueba: $e';
    }
  }
} 