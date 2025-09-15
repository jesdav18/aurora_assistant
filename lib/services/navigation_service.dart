import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:math' as math;
import 'location_service.dart';
import '../config/app_config.dart';
import 'api_interceptor.dart';

class NavigationService {
  final LocationService _locationService = LocationService();
  
  // Controladores para la navegación
  StreamController<LatLng>? _locationController;
  StreamController<String>? _instructionController;
  StreamController<double>? _distanceController;
  StreamController<int>? _etaController;
  StreamController<Map<String, dynamic>>? _mapStateController;
  
  // Estado de navegación
  bool _isNavigating = false;
  List<LatLng> _routePoints = [];
  int _currentStepIndex = 0;
  LatLng? _destination;
  String? _destinationName;
  LatLng? _lastKnownLocation;
  Timer? _locationTimer;
  
  // Estado del mapa
  double _currentZoom = 15.0;
  double _currentBearing = 0.0;
  bool _isFollowingRoute = true;
  bool _isMapRotated = false;
  
  // Streams públicos
  Stream<LatLng> get locationStream => _locationController?.stream ?? Stream.empty();
  Stream<String> get instructionStream => _instructionController?.stream ?? Stream.empty();
  Stream<double> get distanceStream => _distanceController?.stream ?? Stream.empty();
  Stream<int> get etaStream => _etaController?.stream ?? Stream.empty();
  Stream<Map<String, dynamic>> get mapStateStream => _mapStateController?.stream ?? Stream.empty();
  
  // Getters
  bool get isNavigating => _isNavigating;
  List<LatLng> get routePoints => _routePoints;
  LatLng? get destination => _destination;
  String? get destinationName => _destinationName;
  int get currentStepIndex => _currentStepIndex;
  LatLng? get lastKnownLocation => _lastKnownLocation;
  double get currentZoom => _currentZoom;
  double get currentBearing => _currentBearing;
  bool get isFollowingRoute => _isFollowingRoute;
  bool get isMapRotated => _isMapRotated;

  /// Inicia la navegación hacia un destino
  Future<bool> startNavigation(String destinationName) async {
    try {
      print('🗺️ Iniciando navegación hacia: $destinationName');
      
      // Obtener coordenadas del destino
      print('🌍 Obteniendo coordenadas...');
      final destinationCoords = await _locationService.getCoordinatesFromAddress(destinationName);
      if (destinationCoords == null) {
        print('❌ No se pudo obtener coordenadas del destino');
        return false;
      }
      print('✅ Coordenadas obtenidas: $destinationCoords');
      
      _destination = LatLng(destinationCoords[0], destinationCoords[1]);
      _destinationName = destinationName;
      print('📍 Destino configurado: $_destinationName en $_destination');
      
      // Obtener ruta completa
      print('🛣️ Obteniendo ruta completa...');
      final routeInfo = await _getFullRoute();
      if (routeInfo == null) {
        print('❌ No se pudo obtener la ruta');
        return false;
      }
      print('✅ Ruta obtenida: ${routeInfo['routePoints']?.length ?? 0} puntos');
      
      // Inicializar controladores
      print('🎛️ Inicializando controladores...');
      _locationController = StreamController<LatLng>.broadcast();
      _instructionController = StreamController<String>.broadcast();
      _distanceController = StreamController<double>.broadcast();
      _etaController = StreamController<int>.broadcast();
      _mapStateController = StreamController<Map<String, dynamic>>.broadcast();
      
      // Configurar ruta
      _routePoints = routeInfo['routePoints'] ?? [];
      _currentStepIndex = 0;
      _isNavigating = true;
      _isFollowingRoute = true;
      _isMapRotated = true;
      print('✅ Estado de navegación configurado: $_isNavigating');
      
      // Guardar en preferencias
      print('💾 Guardando estado...');
      await _saveNavigationState();
      
      // Iniciar monitoreo de ubicación
      print('📍 Iniciando monitoreo de ubicación...');
      _startLocationMonitoring();
      
      print('✅ Navegación iniciada exitosamente');
      print('📍 DestinationName final: $_destinationName');
      return true;
      
    } catch (e) {
      print('❌ Error al iniciar navegación: $e');
      return false;
    }
  }

  /// Detiene la navegación actual
  void stopNavigation() {
    print('🛑 Deteniendo navegación en NavigationService');
    
    // Marcar como no navegando primero
    _isNavigating = false;
    
    // Cancelar timer inmediatamente
    _locationTimer?.cancel();
    _locationTimer = null;
    
    // Limpiar estado
    _currentStepIndex = 0;
    _routePoints.clear();
    _destination = null;
    _destinationName = null;
    _lastKnownLocation = null;
    _isFollowingRoute = false;
    _isMapRotated = false;
    _currentZoom = 15.0;
    _currentBearing = 0.0;
    
    // Cerrar controladores de manera segura
    _safeCloseController(_locationController);
    _safeCloseController(_instructionController);
    _safeCloseController(_distanceController);
    _safeCloseController(_etaController);
    _safeCloseController(_mapStateController);
    
    // Limpiar referencias
    _locationController = null;
    _instructionController = null;
    _distanceController = null;
    _etaController = null;
    _mapStateController = null;
    
    // Limpiar estado persistente
    _clearNavigationState();
    
    print('✅ Navegación detenida completamente');
  }

  /// Cierra un controlador de manera segura
  void _safeCloseController(StreamController? controller) {
    if (controller != null && !controller.isClosed) {
      try {
        controller.close();
      } catch (e) {
        print('⚠️ Error al cerrar controlador: $e');
      }
    }
  }

  /// Cambia el modo de seguimiento del mapa
  void toggleMapFollowing() {
    _isFollowingRoute = !_isFollowingRoute;
    print('🗺️ Modo de seguimiento: ${_isFollowingRoute ? "Activado" : "Desactivado"}');
    _emitMapState();
  }

  /// Cambia la orientación del mapa
  void toggleMapRotation() {
    _isMapRotated = !_isMapRotated;
    if (!_isMapRotated) {
      _currentBearing = 0.0;
    }
    print('🔄 Rotación del mapa: ${_isMapRotated ? "Activada" : "Desactivada"}');
    _emitMapState();
  }

  /// Ajusta el zoom del mapa
  void setMapZoom(double zoom) {
    _currentZoom = zoom.clamp(10.0, 18.0);
    print('🔍 Zoom ajustado a: $_currentZoom');
    _emitMapState();
  }

  /// Ajusta la orientación del mapa
  void setMapBearing(double bearing) {
    _currentBearing = bearing;
    print('🧭 Orientación ajustada a: $_currentBearing°');
    _emitMapState();
  }

  /// Emite el estado actual del mapa
  void _emitMapState() {
    if (_mapStateController != null && !_mapStateController!.isClosed) {
      _mapStateController!.add({
        'zoom': _currentZoom,
        'bearing': _currentBearing,
        'isFollowingRoute': _isFollowingRoute,
        'isMapRotated': _isMapRotated,
        'currentLocation': _lastKnownLocation,
        'destination': _destination,
      });
    }
  }

  /// Obtiene la ruta completa desde la ubicación actual al destino
  Future<Map<String, dynamic>?> _getFullRoute() async {
    try {
      final currentLocation = await _locationService.getCurrentPosition();
      LatLng origin;
      
      if (currentLocation == null || currentLocation.latitude == null || currentLocation.longitude == null) {
        print('⚠️ No se pudo obtener ubicación actual, usando ubicación por defecto');
        origin = LatLng(14.0723, -87.1921);
      } else {
        origin = LatLng(currentLocation.latitude!, currentLocation.longitude!);
        _lastKnownLocation = origin;
      }
      
      if (_destination == null) {
        print('❌ No hay destino configurado');
        return null;
      }
      
      final destination = _destination!;
      print('🗺️ Calculando ruta de ${origin.latitude},${origin.longitude} a ${destination.latitude},${destination.longitude}');
      
      // Intentar obtener ruta de Mapbox primero
      print('🗺️ Intentando obtener ruta de Mapbox...');
      var routeData = await _getRouteFromMapbox(origin, destination);
      
      // Si Mapbox falla, intentar con OpenRouteService
      if (routeData == null) {
        print('🔄 Mapbox falló, intentando con OpenRouteService...');
        routeData = await _getRouteFromOpenRouteService(origin, destination);
      }
      
      // Si ambos servicios fallan, generar ruta mejorada
      if (routeData == null) {
        print('🔄 Ambos servicios fallaron, generando ruta mejorada...');
        routeData = _generateImprovedRoute(origin, destination);
      }
      
      if (routeData == null) {
        print('❌ No se pudo obtener ninguna ruta');
        return null;
      }
      
      print('✅ Ruta obtenida exitosamente con ${routeData['routePoints']?.length ?? 0} puntos');
      return {
        'routePoints': routeData['routePoints'],
        'steps': routeData['steps'],
        'totalDistance': routeData['distance'],
        'totalDuration': routeData['duration'],
      };
      
    } catch (e) {
      print('❌ Error al obtener ruta completa: $e');
      return null;
    }
  }

  /// Obtiene ruta de Mapbox con puntos detallados
  Future<Map<String, dynamic>?> _getRouteFromMapbox(LatLng origin, LatLng destination) async {
    try {
      final dio = Dio();
      // Agregar interceptor para trackear uso de APIs
      dio.interceptors.add(ApiUsageInterceptor());
      
      final coordinatesString = '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
      
      final response = await dio.get(
        '${AppConfig.mapboxDirectionsUrl}/$coordinatesString.json',
        queryParameters: {
          'access_token': AppConfig.mapboxAccessToken,
          'language': 'es',
          'overview': 'full',
          'steps': 'true',
          'geometries': 'geojson',
        },
        options: Options(
          sendTimeout: Duration(seconds: AppConfig.navigationTimeout),
          receiveTimeout: Duration(seconds: AppConfig.navigationReceiveTimeout),
        ),
      );

      if (response.statusCode == 200 && response.data['routes'] != null && response.data['routes'].isNotEmpty) {
        final route = response.data['routes'][0];
        final geometry = route['geometry'];
        
        // Decodificar geometría GeoJSON
        List<LatLng> routePoints = [];
        if (geometry['type'] == 'LineString') {
          final coordinates = geometry['coordinates'] as List;
          for (final coord in coordinates) {
            routePoints.add(LatLng(coord[1] as double, coord[0] as double));
          }
        }
        
        print('✅ Ruta de Mapbox obtenida: ${routePoints.length} puntos');
        return {
          'routePoints': routePoints,
          'steps': route['legs']?[0]?['steps'] ?? [],
          'distance': route['distance'] / 1000, // km
          'duration': route['duration'] / 60, // minutos
        };
      }
      
      print('❌ Mapbox no devolvió una ruta válida');
      return null;
    } catch (e) {
      print('❌ Error al obtener ruta de Mapbox: $e');
      return null;
    }
  }

  /// Obtiene ruta de OpenRouteService como respaldo
  Future<Map<String, dynamic>?> _getRouteFromOpenRouteService(LatLng origin, LatLng destination) async {
    try {
      final dio = Dio();
      // Agregar interceptor para trackear uso de APIs
      dio.interceptors.add(ApiUsageInterceptor());
      
      final response = await dio.post(
        'https://api.openrouteservice.org/v2/directions/driving-car/geojson',
        data: {
          'coordinates': [
            [origin.longitude, origin.latitude],
            [destination.longitude, destination.latitude]
          ],
          'instructions': true,
          'preference': 'fastest',
          'units': 'kilometers',
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${AppConfig.openRouteServiceToken}',
            'Content-Type': 'application/json',
          },
          sendTimeout: Duration(seconds: 10),
          receiveTimeout: Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data['features'] != null && response.data['features'].isNotEmpty) {
        final feature = response.data['features'][0];
        final geometry = feature['geometry'];
        
        List<LatLng> routePoints = [];
        if (geometry['type'] == 'LineString') {
          final coordinates = geometry['coordinates'] as List;
          for (final coord in coordinates) {
            routePoints.add(LatLng(coord[1] as double, coord[0] as double));
          }
        }
        
        final properties = feature['properties'];
        final summary = properties['summary'];
        
        print('✅ Ruta de OpenRouteService obtenida: ${routePoints.length} puntos');
        return {
          'routePoints': routePoints,
          'steps': properties['segments']?[0]?['steps'] ?? [],
          'distance': summary['distance'] / 1000, // km
          'duration': summary['duration'] / 60, // minutos
        };
      }
      
      print('❌ OpenRouteService no devolvió una ruta válida');
      return null;
    } catch (e) {
      print('❌ Error al obtener ruta de OpenRouteService: $e');
      return null;
    }
  }

  /// Genera una ruta mejorada cuando los servicios fallan
  Map<String, dynamic> _generateImprovedRoute(LatLng origin, LatLng destination) {
    print('🗺️ Generando ruta mejorada de ${origin.latitude},${origin.longitude} a ${destination.latitude},${destination.longitude}');
    
    // Calcular distancia directa
    final distance = _calculateDistance(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    
    // Generar puntos intermedios para simular una ruta más realista
    List<LatLng> routePoints = [];
    final numPoints = math.max(10, (distance / 100).round()); // Al menos 10 puntos, uno cada 100m
    
    for (int i = 0; i <= numPoints; i++) {
      final progress = i / numPoints;
      
      // Interpolación lineal con pequeñas variaciones para simular calles
      double lat = origin.latitude + (destination.latitude - origin.latitude) * progress;
      double lng = origin.longitude + (destination.longitude - origin.longitude) * progress;
      
      // Agregar pequeñas variaciones para simular giros en calles
      if (i > 0 && i < numPoints) {
        final variation = 0.0001 * math.sin(progress * math.pi * 3); // Variación sinusoidal
        lat += variation;
        lng += variation * 0.5;
      }
      
      routePoints.add(LatLng(lat, lng));
    }
    
    // Estimar tiempo basado en velocidad promedio de 50 km/h
    final estimatedDuration = (distance / 1000 / 50 * 60).round(); // minutos
    
    print('✅ Ruta mejorada generada: ${distance / 1000} km, $estimatedDuration minutos, ${routePoints.length} puntos');
    
    return {
      'routePoints': routePoints,
      'steps': [
        {
          'maneuver': {'instruction': 'Dirígete hacia ${_destinationName ?? 'el destino'}'},
          'distance': distance,
          'duration': estimatedDuration * 60,
        }
      ],
      'distance': distance / 1000, // km
      'duration': estimatedDuration, // minutos
    };
  }

  /// Inicia el monitoreo de ubicación en tiempo real
  void _startLocationMonitoring() {
    if (!_isNavigating) return;
    
    // Cancelar timer anterior si existe
    _locationTimer?.cancel();
    
    _locationTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      if (!_isNavigating) {
        timer.cancel();
        return;
      }
      
      try {
        final currentLocation = await _locationService.getCurrentPosition();
        if (currentLocation != null && currentLocation.latitude != null && currentLocation.longitude != null) {
          final currentLatLng = LatLng(currentLocation.latitude!, currentLocation.longitude!);
          
          // Verificar si la ubicación ha cambiado significativamente
          if (_lastKnownLocation == null || _hasLocationChangedSignificantly(_lastKnownLocation!, currentLatLng)) {
            _lastKnownLocation = currentLatLng;
          
          // Emitir ubicación actual
          _locationController?.add(currentLatLng);
          
          // Verificar si estamos cerca del siguiente paso
          _checkNextInstruction(currentLatLng);
          
          // Calcular distancia restante
          _updateDistanceAndETA(currentLatLng);
            
            // Actualizar estado del mapa si estamos siguiendo la ruta
            if (_isFollowingRoute) {
              _updateMapStateForNavigation(currentLatLng);
            }
            
            // Emitir estado del mapa
            _emitMapState();
          }
        }
      } catch (e) {
        print('❌ Error en monitoreo de ubicación: $e');
      }
    });
  }

  /// Verifica si la ubicación ha cambiado significativamente (más de 10 metros)
  bool _hasLocationChangedSignificantly(LatLng oldLocation, LatLng newLocation) {
    final distance = _calculateDistance(
      oldLocation.latitude,
      oldLocation.longitude,
      newLocation.latitude,
      newLocation.longitude,
    );
    return distance > 10; // 10 metros
  }

  /// Actualiza el estado del mapa para navegación
  void _updateMapStateForNavigation(LatLng currentLocation) {
    if (_routePoints.isEmpty || _currentStepIndex >= _routePoints.length - 1) {
      return;
    }
    
    // Calcular dirección hacia el siguiente punto
    final nextPoint = _routePoints[_currentStepIndex + 1];
    final bearing = _calculateBearing(
      currentLocation.latitude,
      currentLocation.longitude,
      nextPoint.latitude,
      nextPoint.longitude,
    );
    
    // Actualizar orientación del mapa solo si está rotado
    if (_isMapRotated) {
      _currentBearing = bearing;
    }
    
    // Ajustar zoom basado en la velocidad y proximidad al destino
    final distanceToDestination = _calculateDistance(
      currentLocation.latitude,
      currentLocation.longitude,
      _destination!.latitude,
      _destination!.longitude,
    );
    
    if (distanceToDestination < 1000) { // Menos de 1 km
      _currentZoom = 17.0; // Zoom alto para calles
    } else if (distanceToDestination < 5000) { // Menos de 5 km
      _currentZoom = 15.0; // Zoom medio
    } else {
      _currentZoom = 13.0; // Zoom bajo para vista general
    }
  }

  /// Verifica si debemos dar la siguiente instrucción
  void _checkNextInstruction(LatLng currentLocation) {
    if (_routePoints.isEmpty || _currentStepIndex >= _routePoints.length - 1) {
      return;
    }
    
    final nextPoint = _routePoints[_currentStepIndex + 1];
    final distance = _calculateDistance(
      currentLocation.latitude,
      currentLocation.longitude,
      nextPoint.latitude,
      nextPoint.longitude,
    );
    
    // Si estamos a menos de 50 metros del siguiente punto
    if (distance < 50) {
      _currentStepIndex++;
      _giveNextInstruction();
    }
  }

  /// Da la siguiente instrucción de navegación
  void _giveNextInstruction() {
    if (_currentStepIndex >= _routePoints.length - 1) {
      _instructionController?.add('Has llegado a tu destino: $_destinationName');
      stopNavigation();
      return;
    }
    
    // Calcular dirección
    final currentPoint = _routePoints[_currentStepIndex];
    final nextPoint = _routePoints[_currentStepIndex + 1];
    
    final bearing = _calculateBearing(
      currentPoint.latitude,
      currentPoint.longitude,
      nextPoint.latitude,
      nextPoint.longitude,
    );
    
    String instruction = _getDirectionInstruction(bearing);
    _instructionController?.add(instruction);
  }

  /// Convierte el bearing en instrucción de voz
  String _getDirectionInstruction(double bearing) {
    if (bearing >= 315 || bearing < 45) {
      return 'Continúa recto';
    } else if (bearing >= 45 && bearing < 135) {
      return 'Gira a la derecha';
    } else if (bearing >= 135 && bearing < 225) {
      return 'Da la vuelta';
    } else {
      return 'Gira a la izquierda';
    }
  }

  /// Actualiza distancia y tiempo restante
  void _updateDistanceAndETA(LatLng currentLocation) {
    if (_destination == null) return;
    
    final distance = _calculateDistance(
      currentLocation.latitude,
      currentLocation.longitude,
      _destination!.latitude,
      _destination!.longitude,
    );
    
    // Asumiendo velocidad promedio de 50 km/h
    final etaMinutes = (distance / 1000 / 50 * 60).round();
    
    _distanceController?.add(distance / 1000); // km
    _etaController?.add(etaMinutes);
  }

  /// Calcula la distancia entre dos puntos usando la fórmula de Haversine
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // metros
    
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

  /// Calcula el bearing entre dos puntos
  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final double lat1Rad = lat1 * (math.pi / 180);
    final double lat2Rad = lat2 * (math.pi / 180);
    final double deltaLonRad = (lon2 - lon1) * (math.pi / 180);

    final double y = math.sin(deltaLonRad) * math.cos(lat2Rad);
    final double x = math.cos(lat1Rad) * math.sin(lat2Rad) - math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(deltaLonRad);
    
    double bearing = math.atan(y / x) * (180 / math.pi);
    
    // Normalizar a 0-360
    bearing = (bearing + 360) % 360;
    
    return bearing;
  }

  /// Abre la navegación en Google Maps
  Future<bool> openInGoogleMaps() async {
    if (_destination == null) return false;
    
    final url = 'https://www.google.com/maps/dir/?api=1&destination=${_destination!.latitude},${_destination!.longitude}&travelmode=driving';
    
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      print('❌ Error al abrir Google Maps: $e');
    }
    
    return false;
  }

  /// Guarda el estado de navegación
  Future<void> _saveNavigationState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isNavigating', _isNavigating);
      await prefs.setString('destinationName', _destinationName ?? '');
      if (_destination != null) {
        await prefs.setDouble('destinationLat', _destination!.latitude);
        await prefs.setDouble('destinationLng', _destination!.longitude);
      }
    } catch (e) {
      print('❌ Error al guardar estado de navegación: $e');
    }
  }

  /// Limpia el estado de navegación
  Future<void> _clearNavigationState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isNavigating');
      await prefs.remove('destinationName');
      await prefs.remove('destinationLat');
      await prefs.remove('destinationLng');
    } catch (e) {
      print('❌ Error al limpiar estado de navegación: $e');
    }
  }

  /// Restaura el estado de navegación
  Future<bool> restoreNavigationState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isNavigating = prefs.getBool('isNavigating') ?? false;
      
      if (isNavigating) {
        final destinationName = prefs.getString('destinationName') ?? '';
        final destinationLat = prefs.getDouble('destinationLat');
        final destinationLng = prefs.getDouble('destinationLng');
        
        if (destinationName.isNotEmpty && destinationLat != null && destinationLng != null) {
          _destination = LatLng(destinationLat, destinationLng);
          _destinationName = destinationName;
          _isNavigating = true;
          
          // Reiniciar navegación
          await _getFullRoute();
          _startLocationMonitoring();
          
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('❌ Error al restaurar estado de navegación: $e');
      return false;
    }
  }
} 