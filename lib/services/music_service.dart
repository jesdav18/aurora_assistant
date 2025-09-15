import 'package:url_launcher/url_launcher.dart';
import 'spotify_auth_service.dart';
import 'spotify_player_service.dart';

class MusicService {
  final SpotifyAuthService _authService = SpotifyAuthService();
  final SpotifyPlayerService _playerService = SpotifyPlayerService();
  
  /// Procesa consultas musicales con reproducción AUTOMÁTICA
  Future<String> processMusicalQuery(String query) async {
    try {
      print('🎵 Procesando consulta musical: $query');
      
      // Verificar autenticación de Spotify
      final isAuthenticated = await _authService.isAuthenticated();
      
      if (!isAuthenticated) {
        print('🔐 Usuario no autenticado, iniciando configuración...');
        return await _handleFirstTimeSetup();
      }
      
      // Usuario autenticado - REPRODUCCIÓN AUTOMÁTICA
      final searchTerm = _extractSearchTerm(query);
      
      if (searchTerm.isNotEmpty) {
        print('🎵 Reproduciendo automáticamente: $searchTerm');
        final result = await _playerService.searchAndPlay(searchTerm);
        return result;
      } else {
        return 'No pude identificar qué música quieres reproducir. '
               'Prueba con: "reproduce Despacito de Luis Fonsi"';
      }
    } catch (e) {
      print('❌ Error en servicio musical: $e');
      return 'Error al procesar la música. Verifica tu conexión a internet.';
    }
  }
  
  /// Configuración inicial de Spotify (solo primera vez)
  Future<String> _handleFirstTimeSetup() async {
    try {
      print('🔐 Iniciando configuración inicial de Spotify...');
      
      // Intentar intercambiar el código manual primero
      print('🔄 Intentando código manual...');
      final manualSuccess = await _authService.exchangeManualCode();
      
      if (manualSuccess) {
        print('✅ ¡Código manual intercambiado exitosamente!');
        return '🎵 ¡Spotify conectado exitosamente! Ahora puedes reproducir música automáticamente.';
      }
      
      print('🔐 Llamando a _authService.authenticate()...');
      final authStarted = await _authService.authenticate();
      print('🔐 Resultado de authenticate(): $authStarted');
      
      if (authStarted) {
        return '''🎵 ¡Configuración de reproducción automática!

Se abrió tu navegador para conectar Spotify Premium:

📱 Pasos (solo una vez):
1. Inicia sesión en tu cuenta Spotify Premium
2. Autoriza a Aurora el acceso
3. Regresa a la app

✨ Después de esto:
• "Aurora reproduce Despacito" → ¡Suena automáticamente!
• "Aurora pon reggaeton" → ¡Reproduce al instante!
• "Aurora pausa" → ¡Se pausa automáticamente!

🎯 CERO clicks adicionales una vez configurado''';
      } else {
        return '''❌ No se pudo iniciar la configuración

🔧 Requisitos:
• Cuenta Spotify Premium (necesaria para API)
• Conexión a internet
• Navegador disponible

💡 Intenta: "reproduce música" nuevamente''';
      }
    } catch (e) {
      print('❌ Error en configuración: $e');
      return 'Error al configurar Spotify. Intenta más tarde.';
    }
  }
  
  /// Extrae el término de búsqueda de la consulta
  String _extractSearchTerm(String query) {
    final queryLower = query.toLowerCase();
    
    // Patrones para extraer canción y artista
    final patterns = [
      RegExp(r'reproduce?\s+(.+?)\s+de\s+(.+)', caseSensitive: false),
      RegExp(r'pon\s+(.+?)\s+de\s+(.+)', caseSensitive: false),
      RegExp(r'busca\s+(.+?)\s+de\s+(.+)', caseSensitive: false),
      RegExp(r'reproduce?\s+(.+)', caseSensitive: false),
      RegExp(r'pon\s+(.+)', caseSensitive: false),
      RegExp(r'busca\s+(.+)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(query);
      if (match != null) {
        if (match.groupCount >= 2) {
          // Canción y artista
          final song = match.group(1)?.trim() ?? '';
          final artist = match.group(2)?.trim() ?? '';
          return '$song $artist';
        } else if (match.groupCount >= 1) {
          // Solo canción o término general
          String term = match.group(1)?.trim() ?? '';
          // Limpiar "aurora" del inicio si está presente
          term = term.replaceFirst(RegExp(r'^aurora\s+', caseSensitive: false), '');
          return term;
        }
      }
    }
    
    // Si no encuentra patrones específicos, buscar géneros
    final genres = ['reggaeton', 'rock', 'pop', 'salsa', 'bachata', 'merengue', 'rap', 'hip hop'];
    for (final genre in genres) {
      if (queryLower.contains(genre)) {
        return genre;
      }
    }
    
    return '';
  }
  
  /// Controles de reproducción automáticos
  Future<String> pause() async {
    try {
      final success = await _playerService.pause();
      return success ? '⏸️ Música pausada automáticamente.' : 
                      'No se pudo pausar. ¿Hay música reproduciéndose?';
    } catch (e) {
      return 'Error al pausar la música.';
    }
  }
  
  Future<String> resume() async {
    try {
      final success = await _playerService.resume();
      return success ? '▶️ Música reanudada automáticamente.' : 
                      'No se pudo reanudar la música.';
    } catch (e) {
      return 'Error al reanudar la música.';
    }
  }
  
  Future<String> next() async {
    try {
      final success = await _playerService.next();
      return success ? '⏭️ Siguiente canción reproduciendo automáticamente.' : 
                      'No se pudo cambiar de canción.';
    } catch (e) {
      return 'Error al cambiar de canción.';
    }
  }
  
  Future<String> previous() async {
    try {
      final success = await _playerService.previous();
      return success ? '⏮️ Canción anterior reproduciendo automáticamente.' : 
                      'No se pudo regresar a la canción anterior.';
    } catch (e) {
      return 'Error al cambiar de canción.';
    }
  }
  
  /// Verifica si la consulta es sobre música
  bool isMusicQuery(String query) {
    final musicKeywords = [
      'reproduce', 'reproducir', 'reproduc', 'pon', 'poner', 'música', 'musica', 
      'canción', 'cancion', 'spotify', 'suena', 'sonar', 'toca', 'tocar', 
      'busca', 'buscar', 'pausa', 'pausar', 'para', 'parar', 'siguiente', 
      'anterior', 'reggaeton', 'rock', 'pop', 'salsa', 'bachata', 'merengue',
      'rap', 'hip hop', 'jazz', 'blues', 'cumbia', 'vallenato'
    ];
    
    final queryLower = query.toLowerCase();
    
    // Debug: mostrar qué keywords encuentra
    final foundKeywords = musicKeywords.where((keyword) => queryLower.contains(keyword)).toList();
    print('🎵 Keywords encontradas: $foundKeywords en "$query"');
    
    return musicKeywords.any((keyword) => queryLower.contains(keyword));
  }
  
  /// Detecta si es un control de reproducción
  bool isPlaybackControl(String query) {
    final controlKeywords = [
      'pausa', 'pause', 'para', 'detén',
      'continúa', 'resume', 'sigue', 
      'siguiente', 'next', 'skip',
      'anterior', 'previous', 'atrás'
    ];
    
    final queryLower = query.toLowerCase();
    return controlKeywords.any((keyword) => queryLower.contains(keyword));
  }
  
  /// Procesa controles de reproducción
  Future<String> processPlaybackControl(String query) async {
    final queryLower = query.toLowerCase();
    
    if (queryLower.contains('pausa') || queryLower.contains('pause') || queryLower.contains('para')) {
      return await pause();
    } else if (queryLower.contains('continúa') || queryLower.contains('resume') || queryLower.contains('sigue')) {
      return await resume();
    } else if (queryLower.contains('siguiente') || queryLower.contains('next') || queryLower.contains('skip')) {
      return await next();
    } else if (queryLower.contains('anterior') || queryLower.contains('previous') || queryLower.contains('atrás')) {
      return await previous();
    }
    
    return 'No entendí qué control quieres usar.';
  }
} 