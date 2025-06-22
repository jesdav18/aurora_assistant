import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/navigation_service.dart';
import '../services/tts_service.dart';
import '../services/location_service.dart';

class NavigationScreen extends StatefulWidget {
  final String destinationName;
  final NavigationService navigationService;
  
  const NavigationScreen({
    Key? key,
    required this.destinationName,
    required this.navigationService,
  }) : super(key: key);

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  late final NavigationService _navigationService;
  final TTSService _ttsService = TTSService();
  final LocationService _locationService = LocationService();
  
  final MapController _mapController = MapController();
  
  LatLng? _currentLocation;
  List<LatLng> _routePoints = [];
  String _currentInstruction = '';
  double _distanceRemaining = 0.0;
  int _etaMinutes = 0;
  bool _isNavigating = false;
  
  // Estado del mapa
  double _currentZoom = 15.0;
  double _currentBearing = 0.0;
  bool _isFollowingRoute = true;
  bool _isMapRotated = true;
  
  @override
  void initState() {
    super.initState();
    _navigationService = widget.navigationService;
    print('🗺️ NavigationScreen initState para: ${widget.destinationName}');
    _initializeNavigation();
  }

  Future<void> _initializeNavigation() async {
    try {
      print('🗺️ Inicializando pantalla de navegación para: ${widget.destinationName}');
      
      // Verificar si ya hay navegación activa
      if (_navigationService.isNavigating) {
        print('✅ Navegación ya está activa, configurando streams...');
        setState(() {
          _isNavigating = true;
          _routePoints = _navigationService.routePoints;
          _currentZoom = _navigationService.currentZoom;
          _currentBearing = _navigationService.currentBearing;
          _isFollowingRoute = _navigationService.isFollowingRoute;
          _isMapRotated = _navigationService.isMapRotated;
        });
        
        // Configurar streams de navegación
        _setupNavigationStreams();
        
        // Obtener ubicación actual si está disponible
        if (_navigationService.lastKnownLocation != null) {
          setState(() {
            _currentLocation = _navigationService.lastKnownLocation;
          });
        }
        
        print('✅ Pantalla de navegación configurada con navegación existente');
        return;
      }
      
      // Si no hay navegación activa, iniciar una nueva
      // Obtener ubicación inicial primero
      final position = await _locationService.getCurrentPosition();
      LatLng initialLocation;
      
      if (position != null && position.latitude != null && position.longitude != null) {
        initialLocation = LatLng(position.latitude!, position.longitude!);
        print('📍 Ubicación actual obtenida: ${initialLocation.latitude}, ${initialLocation.longitude}');
      } else {
        print('⚠️ No se pudo obtener ubicación actual, usando ubicación por defecto');
        initialLocation = LatLng(14.0723, -87.1921);
      }
      
      setState(() {
        _currentLocation = initialLocation;
      });
      
      // Iniciar navegación con timeout
      final success = await _navigationService.startNavigation(widget.destinationName)
          .timeout(Duration(seconds: 30), onTimeout: () {
        print('⏰ Timeout al iniciar navegación');
        return false;
      });
      
      if (success) {
        print('✅ Navegación iniciada exitosamente');
        setState(() {
          _isNavigating = true;
          _routePoints = _navigationService.routePoints;
        });
        
        // Configurar streams de navegación
        _setupNavigationStreams();
      } else {
        print('❌ No se pudo iniciar la navegación');
        _showErrorDialog('No se pudo iniciar la navegación hacia ${widget.destinationName}');
        return;
      }
      
      print('✅ Pantalla de navegación inicializada completamente');
      
    } catch (e) {
      print('❌ Error al inicializar navegación: $e');
      _showErrorDialog('Error al inicializar navegación: $e');
    }
  }

  /// Configura los streams de navegación
  void _setupNavigationStreams() {
    // Escuchar streams de navegación
    _navigationService.locationStream.listen((location) {
      print('📍 Nueva ubicación recibida: ${location.latitude}, ${location.longitude}');
      setState(() {
        _currentLocation = location;
      });
      
      // Solo centrar si estamos siguiendo la ruta
      if (_isFollowingRoute) {
        _updateMapPosition(location);
      }
    });
    
    _navigationService.instructionStream.listen((instruction) {
      print('🗣️ Nueva instrucción: $instruction');
      setState(() {
        _currentInstruction = instruction;
      });
      
      // Reproducir instrucción por voz
      _ttsService.speak(instruction);
    });
    
    _navigationService.distanceStream.listen((distance) {
      setState(() {
        _distanceRemaining = distance;
      });
    });
    
    _navigationService.etaStream.listen((eta) {
      setState(() {
        _etaMinutes = eta;
      });
    });
    
    // Escuchar estado del mapa
    _navigationService.mapStateStream.listen((mapState) {
      setState(() {
        _currentZoom = mapState['zoom'] ?? 15.0;
        _currentBearing = mapState['bearing'] ?? 0.0;
        _isFollowingRoute = mapState['isFollowingRoute'] ?? true;
        _isMapRotated = mapState['isMapRotated'] ?? true;
      });
      
      // Actualizar mapa si estamos siguiendo la ruta
      if (_isFollowingRoute && _currentLocation != null) {
        _updateMapPosition(_currentLocation!);
      }
    });
  }

  /// Actualiza la posición del mapa de manera inteligente
  void _updateMapPosition(LatLng location) {
    if (_isMapRotated) {
      // Mover con rotación (como Google Maps)
      _mapController.moveAndRotate(
        location,
        _currentZoom,
        _currentBearing,
      );
    } else {
      // Mover sin rotación
      _mapController.move(location, _currentZoom);
    }
  }

  /// Detiene completamente la navegación
  void _stopNavigation() {
    print('🛑 Deteniendo navegación desde la pantalla');
    
    // Detener el servicio de navegación (instancia compartida)
    _navigationService.stopNavigation();
    
    // Limpiar el estado local
    setState(() {
      _isNavigating = false;
      _currentInstruction = '';
      _distanceRemaining = 0.0;
      _etaMinutes = 0;
      _routePoints.clear();
      _isFollowingRoute = false;
      _isMapRotated = false;
    });
    
    // Cerrar la pantalla
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    print('🗺️ NavigationScreen dispose');
    // NO detener la navegación aquí, solo limpiar recursos locales
    super.dispose();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Navegación a ${widget.destinationName}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Botón para alternar seguimiento
          IconButton(
            icon: Icon(_isFollowingRoute ? Icons.gps_fixed : Icons.gps_off),
            onPressed: () {
              _navigationService.toggleMapFollowing();
            },
            tooltip: _isFollowingRoute ? 'Desactivar seguimiento' : 'Activar seguimiento',
          ),
          // Botón para alternar rotación
          IconButton(
            icon: Icon(_isMapRotated ? Icons.rotate_right : Icons.rotate_left),
            onPressed: () {
              _navigationService.toggleMapRotation();
            },
            tooltip: _isMapRotated ? 'Desactivar rotación' : 'Activar rotación',
          ),
          IconButton(
            icon: Icon(Icons.stop),
            onPressed: () {
              _stopNavigation();
            },
            tooltip: 'Detener navegación',
          ),
          IconButton(
            icon: Icon(Icons.open_in_new),
            onPressed: () async {
              await _navigationService.openInGoogleMaps();
            },
            tooltip: 'Abrir en Google Maps',
          ),
        ],
      ),
      body: Column(
        children: [
          // Información de distancia y tiempo
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Distancia restante',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '${_distanceRemaining.toStringAsFixed(1)} km',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tiempo estimado',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '$_etaMinutes min',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Instrucción actual
          if (_currentInstruction.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              color: Colors.orange.shade100,
              child: Row(
                children: [
                  Icon(
                    Icons.directions,
                    color: Colors.orange.shade800,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _currentInstruction,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Mapa
          Expanded(
            child: _currentLocation != null
                ? FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentLocation!,
                      initialZoom: _currentZoom,
                      minZoom: 10.0,
                      maxZoom: 18.0,
                      onMapReady: () {
                        print('🗺️ Mapa cargado correctamente');
                      },
                    ),
                    children: [
                      // Capa de OpenStreetMap
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.aurora.assistant',
                        tileProvider: NetworkTileProvider(),
                        maxZoom: 18,
                        minZoom: 1,
                      ),
                      
                      // Marcador de ubicación actual con orientación
                      MarkerLayer(
                        markers: [
                          if (_currentLocation != null)
                            Marker(
                              point: _currentLocation!,
                              width: 40,
                              height: 40,
                              child: Transform.rotate(
                                angle: _currentBearing * (3.14159 / 180),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.my_location,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          
                          // Marcador de destino
                          if (_navigationService.destination != null)
                            Marker(
                              point: _navigationService.destination!,
                              width: 40,
                              height: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                      
                      // Línea de ruta
                      if (_routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              strokeWidth: 4,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                    ],
                  )
                : Container(
                    color: Colors.grey.shade200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Cargando mapa...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Inicializando navegación',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Botón de zoom in
          FloatingActionButton.small(
            heroTag: "zoom_in",
            onPressed: () {
              final newZoom = (_currentZoom + 1).clamp(10.0, 18.0);
              _navigationService.setMapZoom(newZoom);
            },
            child: Icon(Icons.add),
            tooltip: 'Acercar',
          ),
          SizedBox(height: 8),
          // Botón de zoom out
          FloatingActionButton.small(
            heroTag: "zoom_out",
            onPressed: () {
              final newZoom = (_currentZoom - 1).clamp(10.0, 18.0);
              _navigationService.setMapZoom(newZoom);
            },
            child: Icon(Icons.remove),
            tooltip: 'Alejar',
          ),
          SizedBox(height: 8),
          // Botón de centrar en ubicación
          FloatingActionButton(
            heroTag: "center_location",
            onPressed: () {
              if (_currentLocation != null) {
                _navigationService.toggleMapFollowing();
                _updateMapPosition(_currentLocation!);
              }
            },
            child: Icon(Icons.my_location),
            tooltip: 'Centrar en mi ubicación',
          ),
        ],
      ),
    );
  }
} 