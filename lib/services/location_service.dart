import 'package:location/location.dart';
import 'package:dio/dio.dart';
import 'dart:math' as math;

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
    try {
      final dio = Dio();
      
      final response = await dio.get(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$lon,$lat.json',
        queryParameters: {
          'access_token': 'pk.eyJ1IjoibWFwYm94IiwiYSI6ImNpejY4NXVycTA2emYycXBndHRqcmZ3N3gifQ.rJcFIG214AriISLbB6B5aw',
          'limit': 1,
          'language': 'es',
        },
      );

      if (response.statusCode == 200 && response.data['features'].isNotEmpty) {
        final feature = response.data['features'][0];
        return feature['place_name'] ?? 'Ubicación no disponible';
      } else {
        return 'Coordenadas: ${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
      }
    } catch (e) {
      final locationData = await getCurrentPosition();
      return 'Coordenadas: ${locationData?.latitude?.toStringAsFixed(6)}, ${locationData?.longitude?.toStringAsFixed(6)}';
    }
  }

  Future<String> getDetailedLocationInfo() async {
    try {
      final locationData = await getCurrentPosition();
      if (locationData == null || locationData.latitude == null || locationData.longitude == null) {
        throw Exception('No se pudo obtener la ubicación');
      }

      final description = await getLocationDescription();
      
      return 'Tu ubicación actual es: $description. '
          'Coordenadas exactas: ${locationData.latitude!.toStringAsFixed(6)}, ${locationData.longitude!.toStringAsFixed(6)}. '
          'Precisión: ${locationData.accuracy?.toStringAsFixed(1) ?? 'N/A'} metros.';
    } catch (e) {
      throw Exception('Error al obtener información detallada: $e');
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
} 