import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

class SpotifyAuthService {
  static const String _accessTokenKey = 'spotify_access_token';
  static const String _refreshTokenKey = 'spotify_refresh_token';
  static const String _tokenExpiryKey = 'spotify_token_expiry';
  static const String _codeVerifierKey = 'spotify_code_verifier';
  
  /// Genera un string aleatorio para PKCE
  String _generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
  }
  
  /// Genera code challenge para PKCE
  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
  
  /// Inicia el proceso de autenticación de Spotify
  Future<bool> authenticate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Generar code verifier y challenge para PKCE
      final codeVerifier = _generateRandomString(128);
      final codeChallenge = _generateCodeChallenge(codeVerifier);
      
      // Guardar code verifier para uso posterior
      await prefs.setString(_codeVerifierKey, codeVerifier);
      
      // Construir URL de autorización
      final authParams = {
        'client_id': AppConfig.spotifyClientId,
        'response_type': 'code',
        'redirect_uri': AppConfig.spotifyRedirectUri,
        'code_challenge_method': 'S256',
        'code_challenge': codeChallenge,
        'scope': AppConfig.spotifyScopes.join(' '),
        'show_dialog': 'true', // Forzar mostrar dialog de login
      };
      
      final authUrl = Uri.parse('${AppConfig.spotifyAuthUrl}/authorize').replace(
        queryParameters: authParams,
      );
      
      print('🔐 Abriendo URL de autenticación: $authUrl');
      
      // Verificar si se puede lanzar la URL
      final canLaunch = await canLaunchUrl(authUrl);
      print('🔐 ¿Se puede lanzar URL? $canLaunch');
      
      if (!canLaunch) {
        throw Exception('No se puede abrir la URL de autenticación');
      }
      
      // Intentar abrir navegador con diferentes modos
      bool launched = false;
      Exception? lastError;
      
      try {
        print('🔐 Intentando modo externalApplication...');
        launched = await launchUrl(
          authUrl, 
          mode: LaunchMode.externalApplication,
        );
        print('🔐 Resultado modo externo: $launched');
      } catch (e) {
        print('⚠️ Error con modo externo: $e');
        lastError = Exception(e.toString());
      }
      
      if (!launched) {
        try {
          print('🔐 Intentando modo platformDefault...');
          launched = await launchUrl(
            authUrl,
            mode: LaunchMode.platformDefault,
          );
          print('🔐 Resultado modo platform: $launched');
        } catch (e) {
          print('⚠️ Error con modo platform: $e');
          lastError = Exception(e.toString());
        }
      }
      
      if (!launched) {
        try {
          print('🔐 Intentando modo inAppWebView...');
          launched = await launchUrl(
            authUrl,
            mode: LaunchMode.inAppWebView,
          );
          print('🔐 Resultado modo in-app: $launched');
        } catch (e) {
          print('⚠️ Error con modo in-app: $e');
          lastError = Exception(e.toString());
        }
      }
      
      if (launched) {
        print('✅ Navegador abierto exitosamente para autenticación');
        return true;
      } else {
        final errorMsg = lastError != null 
          ? 'No se pudo abrir el navegador: ${lastError.toString()}'
          : 'No se pudo abrir el navegador para autenticación';
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('❌ Error en autenticación: $e');
      return false;
    }
  }
  
  /// Intercambia el código de autorización por tokens de acceso
  Future<bool> exchangeCodeForTokens(String authCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final codeVerifier = prefs.getString(_codeVerifierKey);
      
      if (codeVerifier == null) {
        throw Exception('Code verifier no encontrado');
      }
      
      final tokenParams = {
        'client_id': AppConfig.spotifyClientId,
        'grant_type': 'authorization_code',
        'code': authCode,
        'redirect_uri': AppConfig.spotifyRedirectUri,
        'code_verifier': codeVerifier,
      };
      
      final response = await http.post(
        Uri.parse('${AppConfig.spotifyAuthUrl}/api/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: tokenParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&'),
      );
      
      if (response.statusCode == 200) {
        final tokenData = json.decode(response.body);
        
        // Guardar tokens
        await prefs.setString(_accessTokenKey, tokenData['access_token']);
        if (tokenData['refresh_token'] != null) {
          await prefs.setString(_refreshTokenKey, tokenData['refresh_token']);
        }
        
        // Calcular tiempo de expiración
        final expiresIn = tokenData['expires_in'] as int;
        final expiryTime = DateTime.now().add(Duration(seconds: expiresIn));
        await prefs.setString(_tokenExpiryKey, expiryTime.toIso8601String());
        
        print('✅ Tokens de Spotify guardados exitosamente');
        return true;
      } else {
        print('❌ Error al intercambiar código: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error en intercambio de tokens: $e');
      return false;
    }
  }
  
  /// Obtiene un token de acceso válido (renovándolo si es necesario)
  Future<String?> getValidAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(_accessTokenKey);
      final expiryString = prefs.getString(_tokenExpiryKey);
      
      if (accessToken == null || expiryString == null) {
        print('🔐 No hay tokens guardados, requiere autenticación');
        return null;
      }
      
      final expiryTime = DateTime.parse(expiryString);
      final now = DateTime.now();
      
      // Si el token no expira en los próximos 5 minutos, usarlo
      if (now.isBefore(expiryTime.subtract(const Duration(minutes: 5)))) {
        return accessToken;
      }
      
      // Intentar renovar token
      print('🔄 Token expirando, intentando renovar...');
      final renewed = await _refreshAccessToken();
      if (renewed) {
        return prefs.getString(_accessTokenKey);
      }
      
      return null;
    } catch (e) {
      print('❌ Error al obtener token válido: $e');
      return null;
    }
  }
  
  /// Renueva el token de acceso usando el refresh token
  Future<bool> _refreshAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_refreshTokenKey);
      
      if (refreshToken == null) {
        print('❌ No hay refresh token disponible');
        return false;
      }
      
      final refreshParams = {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': AppConfig.spotifyClientId,
      };
      
      final response = await http.post(
        Uri.parse('${AppConfig.spotifyAuthUrl}/api/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: refreshParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&'),
      );
      
      if (response.statusCode == 200) {
        final tokenData = json.decode(response.body);
        
        // Guardar nuevo access token
        await prefs.setString(_accessTokenKey, tokenData['access_token']);
        
        // Actualizar refresh token si viene uno nuevo
        if (tokenData['refresh_token'] != null) {
          await prefs.setString(_refreshTokenKey, tokenData['refresh_token']);
        }
        
        // Actualizar tiempo de expiración
        final expiresIn = tokenData['expires_in'] as int;
        final expiryTime = DateTime.now().add(Duration(seconds: expiresIn));
        await prefs.setString(_tokenExpiryKey, expiryTime.toIso8601String());
        
        print('✅ Token renovado exitosamente');
        return true;
      } else {
        print('❌ Error al renovar token: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error en renovación de token: $e');
      return false;
    }
  }
  
  /// Función temporal para intercambiar código manualmente
  Future<bool> exchangeManualCode() async {
    const String authCode = 'AQBAXAb2GMfrJ77xeoUJr8EVPAylECMCWHL91WPnqJdfCEqoMWUX19J25_MwBi-XBVwF39WOZ0YjdNTnAlF5KP_9s27BQ-v_OzAgwOwfcuqa6S73lQaLM-LUpDEs70QMaJPeuoq0epLWMhJ991976MtdS0o9MJQ74TIOSmOpoAPseUXlUO3zabBaX84aWB3J_qamXDTovlNV1B4w8rHI1H5n_yI0oTWFy2MlyYe9oax6fqG189XzFyUSifHfzS2OQJ3c5bbPQ5AXR_lZ1CEv_JRpxhYIV9eGNsW5ILP50udlVIX3-jQwpZqbWsQMA8V9pXWecgTYqVJUYObs3SxfGnQuQa4961op9CpBv9Da-DBLQ6iEPEv8ZovlONsI1R5x5izY_NDOGaTte8UkOFFGC_Xxsi1bVT9eY19dlvHQiZBg6IkD-LdiP4csHDaqukhCNEjSroxwdU_SKL0Z1jLBASiyhRXYhurkEq-IYa4n2jytTr0kChovFh1TDodrXff-Hg';
    
    print('🔄 Intercambiando código manual por tokens...');
    return await exchangeCodeForTokens(authCode);
  }

  /// Verifica si el usuario está autenticado
  Future<bool> isAuthenticated() async {
    final token = await getValidAccessToken();
    return token != null;
  }
  
  /// Cierra sesión eliminando todos los tokens
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_tokenExpiryKey);
    await prefs.remove(_codeVerifierKey);
    print('🔐 Sesión de Spotify cerrada');
  }
} 