import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'spotify_auth_service.dart';

/// Información de una canción de Spotify
class SpotifyTrack {
  final String id;
  final String name;
  final String uri;
  final List<String> artists;
  final String? albumName;
  final String? imageUrl;
  final int durationMs;
  
  SpotifyTrack({
    required this.id,
    required this.name, 
    required this.uri,
    required this.artists,
    this.albumName,
    this.imageUrl,
    required this.durationMs,
  });
  
  factory SpotifyTrack.fromJson(Map<String, dynamic> json) {
    final artists = (json['artists'] as List)
        .map((artist) => artist['name'] as String)
        .toList();
        
    String? imageUrl;
    if (json['album']?['images'] != null && (json['album']['images'] as List).isNotEmpty) {
      imageUrl = json['album']['images'][0]['url'];
    }
    
    return SpotifyTrack(
      id: json['id'],
      name: json['name'],
      uri: json['uri'],
      artists: artists,
      albumName: json['album']?['name'],
      imageUrl: imageUrl,
      durationMs: json['duration_ms'] ?? 0,
    );
  }
}

/// Información del dispositivo de reproducción de Spotify
class SpotifyDevice {
  final String id;
  final String name;
  final String type;
  final bool isActive;
  
  SpotifyDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.isActive,
  });
  
  factory SpotifyDevice.fromJson(Map<String, dynamic> json) {
    return SpotifyDevice(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      isActive: json['is_active'] ?? false,
    );
  }
}

class SpotifyPlayerService {
  final SpotifyAuthService _authService = SpotifyAuthService();
  
  /// Busca canciones en Spotify
  Future<List<SpotifyTrack>> searchTracks(String query, {int limit = 10}) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null) {
        throw Exception('No autenticado con Spotify');
      }
      
      final searchParams = {
        'q': query,
        'type': 'track',
        'limit': limit.toString(),
        'market': 'ES', // Mercado español
      };
      
      final searchUrl = Uri.parse('${AppConfig.spotifyBaseUrl}/search').replace(
        queryParameters: searchParams,
      );
      
      print('🔍 Buscando en Spotify: $query');
      
      final response = await http.get(
        searchUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tracks = (data['tracks']['items'] as List)
            .map((track) => SpotifyTrack.fromJson(track))
            .toList();
            
        print('✅ Encontradas ${tracks.length} canciones');
        return tracks;
      } else {
        print('❌ Error en búsqueda: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error al buscar canciones: $e');
      return [];
    }
  }
  
  /// Obtiene dispositivos disponibles
  Future<List<SpotifyDevice>> getDevices() async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null) {
        throw Exception('No autenticado con Spotify');
      }
      
      final response = await http.get(
        Uri.parse('${AppConfig.spotifyBaseUrl}/me/player/devices'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final devices = (data['devices'] as List)
            .map((device) => SpotifyDevice.fromJson(device))
            .toList();
            
        print('📱 Dispositivos encontrados: ${devices.length}');
        return devices;
      } else {
        print('❌ Error al obtener dispositivos: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error al obtener dispositivos: $e');
      return [];
    }
  }
  
  /// Reproduce una canción específica
  Future<bool> playTrack(SpotifyTrack track, {String? deviceId}) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null) {
        throw Exception('No autenticado con Spotify');
      }
      
      // Si no se especifica dispositivo, obtener el activo
      String? targetDeviceId = deviceId;
      if (targetDeviceId == null) {
        final devices = await getDevices();
        final activeDevice = devices.where((d) => d.isActive).firstOrNull;
        if (activeDevice != null) {
          targetDeviceId = activeDevice.id;
        } else if (devices.isNotEmpty) {
          // Si no hay dispositivo activo, usar el primero disponible
          targetDeviceId = devices.first.id;
        }
      }
      
      final playData = {
        'uris': [track.uri],
        'position_ms': 0,
      };
      
      var playUrl = '${AppConfig.spotifyBaseUrl}/me/player/play';
      if (targetDeviceId != null) {
        playUrl += '?device_id=$targetDeviceId';
      }
      
      print('🎵 Reproduciendo: ${track.name} by ${track.artists.join(', ')}');
      
      final response = await http.put(
        Uri.parse(playUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(playData),
      );
      
      if (response.statusCode == 204 || response.statusCode == 200) {
        print('✅ Canción iniciada exitosamente');
        return true;
      } else if (response.statusCode == 404) {
        // No hay dispositivo activo, intentar transferir reproducción
        print('⚠️ No hay dispositivo activo, intentando activar...');
        if (targetDeviceId != null) {
          await _transferPlayback(targetDeviceId);
          // Reintentar reproducción
          return await playTrack(track, deviceId: targetDeviceId);
        }
        return false;
      } else {
        print('❌ Error al reproducir: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error al reproducir canción: $e');
      return false;
    }
  }
  
  /// Transfiere reproducción a un dispositivo específico
  Future<bool> _transferPlayback(String deviceId) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null) return false;
      
      final transferData = {
        'device_ids': [deviceId],
        'play': false, // No empezar a reproducir inmediatamente
      };
      
      final response = await http.put(
        Uri.parse('${AppConfig.spotifyBaseUrl}/me/player'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(transferData),
      );
      
      return response.statusCode == 204;
    } catch (e) {
      print('❌ Error al transferir reproducción: $e');
      return false;
    }
  }
  
  /// Busca y reproduce automáticamente la mejor coincidencia
  Future<String> searchAndPlay(String query) async {
    try {
      // Buscar canciones
      final tracks = await searchTracks(query, limit: 5);
      
      if (tracks.isEmpty) {
        return 'No encontré canciones que coincidan con "$query" en Spotify.';
      }
      
      // Reproducir la primera canción (mejor coincidencia)
      final firstTrack = tracks.first;
      final success = await playTrack(firstTrack);
      
      if (success) {
        return '🎵 Reproduciendo "${firstTrack.name}" de ${firstTrack.artists.join(', ')} en Spotify.';
      } else {
        return 'Encontré "${firstTrack.name}" pero no pude reproducirla. Asegúrate de tener Spotify abierto en algún dispositivo.';
      }
    } catch (e) {
      print('❌ Error en búsqueda y reproducción: $e');
      return 'Hubo un error al buscar y reproducir "$query". Verifica tu conexión a Spotify.';
    }
  }
  
  /// Controles básicos de reproducción
  
  /// Pausa la reproducción
  Future<bool> pause() async {
    return await _playbackControl('pause');
  }
  
  /// Resume la reproducción
  Future<bool> resume() async {
    return await _playbackControl('play');
  }
  
  /// Siguiente canción
  Future<bool> next() async {
    return await _playbackControl('next');
  }
  
  /// Canción anterior
  Future<bool> previous() async {
    return await _playbackControl('previous');
  }
  
  /// Control genérico de reproducción
  Future<bool> _playbackControl(String action) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null) return false;
      
      late String endpoint;
      late String method;
      
      switch (action) {
        case 'play':
          endpoint = '${AppConfig.spotifyBaseUrl}/me/player/play';
          method = 'PUT';
          break;
        case 'pause':
          endpoint = '${AppConfig.spotifyBaseUrl}/me/player/pause';
          method = 'PUT';
          break;
        case 'next':
          endpoint = '${AppConfig.spotifyBaseUrl}/me/player/next';
          method = 'POST';
          break;
        case 'previous':
          endpoint = '${AppConfig.spotifyBaseUrl}/me/player/previous';
          method = 'POST';
          break;
        default:
          return false;
      }
      
      final request = http.Request(method, Uri.parse(endpoint));
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });
      
      final response = await request.send();
      final success = response.statusCode == 204;
      
      print(success ? '✅ $action ejecutado' : '❌ Error en $action: ${response.statusCode}');
      return success;
    } catch (e) {
      print('❌ Error en $action: $e');
      return false;
    }
  }
  
  /// Verifica si el usuario está autenticado
  Future<bool> isAuthenticated() async {
    return await _authService.isAuthenticated();
  }
  
  /// Inicia proceso de autenticación
  Future<bool> authenticate() async {
    return await _authService.authenticate();
  }
} 