import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ApiUsageTracker {
  static const String _prefsKey = 'api_usage_stats';
  static const String _lastResetKey = 'last_daily_reset';
  
  // Contadores en memoria
  static Map<String, int> _todayUsage = {};
  static Map<String, int> _totalUsage = {};
  static Map<String, double> _estimatedCosts = {};
  static DateTime? _lastReset;
  
  // Costos por API (USD)
  static const Map<String, double> _costPerRequest = {
    'openai_chat': 0.002,      // ~$0.002 por 1K tokens
    'openai_whisper': 0.006,   // ~$0.006 por minuto
    'mapbox_geocoding': 0.0005, // ~$0.5 por 1K requests
    'mapbox_directions': 0.0005,
    'openroute_directions': 0.0, // Gratis hasta 2K/día
    'nominatim': 0.0,          // Gratis
  };
  
  // Límites diarios/mensuales
  static const Map<String, int> _dailyLimits = {
    'openroute_directions': 2000,
  };
  
  static const Map<String, int> _monthlyLimits = {
    'mapbox_geocoding': 100000,
    'mapbox_directions': 100000,
  };
  
  /// Inicializar el tracker
  static Future<void> initialize() async {
    await _loadStats();
    await _checkDailyReset();
  }
  
  /// Trackear una llamada a API
  static Future<void> trackApiCall(String apiType, {int tokens = 1}) async {
    // Verificar reset diario
    await _checkDailyReset();
    
    // Incrementar contadores
    _todayUsage[apiType] = (_todayUsage[apiType] ?? 0) + 1;
    _totalUsage[apiType] = (_totalUsage[apiType] ?? 0) + 1;
    
    // Calcular costo estimado
    double cost = (_costPerRequest[apiType] ?? 0.0);
    if (apiType == 'openai_chat' || apiType == 'openai_whisper') {
      cost = cost * tokens / 1000; // Costo por tokens
    }
    _estimatedCosts[apiType] = (_estimatedCosts[apiType] ?? 0.0) + cost;
    
    // Guardar en preferencias
    await _saveStats();
    
    // Log para debugging
    print('📊 API Call: $apiType | Today: ${_todayUsage[apiType]} | Tokens: $tokens | Cost: \$${cost.toStringAsFixed(6)}');
    
    // Verificar límites
    _checkLimits(apiType);
  }
  
  /// Obtener estadísticas de uso
  static Map<String, dynamic> getUsageStats() {
    return {
      'today': Map<String, int>.from(_todayUsage),
      'total': Map<String, int>.from(_totalUsage),
      'costs': Map<String, double>.from(_estimatedCosts),
      'daily_limits': Map.from(_dailyLimits),
      'monthly_limits': Map.from(_monthlyLimits),
      'last_reset': _lastReset?.toIso8601String()
    };
  }
  
  /// Obtener costo total estimado
  static double getTotalEstimatedCost() {
    return _estimatedCosts.values.fold(0.0, (sum, cost) => sum + cost);
  }
  
  /// Obtener costo del día
  static double getTodayEstimatedCost() {
    double todayCost = 0.0;
    for (String apiType in _todayUsage.keys) {
      int calls = _todayUsage[apiType] ?? 0;
      double costPerCall = _costPerRequest[apiType] ?? 0.0;
      todayCost += calls * costPerCall;
    }
    return todayCost;
  }
  
  /// Verificar si se ha alcanzado algún límite
  static Map<String, dynamic> checkLimitsStatus() {
    Map<String, dynamic> status = {};
    
    // Verificar límites diarios
    for (String apiType in _dailyLimits.keys) {
      int used = _todayUsage[apiType] ?? 0;
      int limit = _dailyLimits[apiType] ?? 0;
      double percentage = (used / limit) * 100;
      
      status[apiType] = {
        'used': used,
        'limit': limit,
        'percentage': percentage,
        'exceeded': used >= limit,
        'warning': percentage >= 80,
      };
    }
    
    return status;
  }
  
  /// Resetear estadísticas diarias
  static Future<void> resetDailyStats() async {
    _todayUsage.clear();
    _lastReset = DateTime.now();
    await _saveStats();
    print('📊 Estadísticas diarias reseteadas');
  }
  
  /// Resetear todas las estadísticas
  static Future<void> resetAllStats() async {
    _todayUsage.clear();
    _totalUsage.clear();
    _estimatedCosts.clear();
    _lastReset = DateTime.now();
    await _saveStats();
    print('📊 Todas las estadísticas reseteadas');
  }
  
  /// Verificar y realizar reset diario automático
  static Future<void> _checkDailyReset() async {
    DateTime now = DateTime.now();
    if (_lastReset == null) {
      _lastReset = now;
      return;
    }
    
    // Si es un nuevo día, resetear estadísticas diarias
    if (!_isSameDay(_lastReset!, now)) {
      await resetDailyStats();
    }
  }
  
  /// Verificar si dos fechas son del mismo día
  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
  
  /// Verificar límites y mostrar advertencias
  static void _checkLimits(String apiType) {
    // Verificar límites diarios
    if (_dailyLimits.containsKey(apiType)) {
      int used = _todayUsage[apiType] ?? 0;
      int limit = _dailyLimits[apiType] ?? 0;
      double percentage = (used / limit) * 100;
      
      if (used >= limit) {
        print('🚨 LÍMITE EXCEDIDO: $apiType ($used/$limit)');
      } else if (percentage >= 80) {
        print('⚠️ ADVERTENCIA: $apiType cerca del límite (${percentage.toStringAsFixed(1)}%)');
      }
    }
  }
  
  /// Cargar estadísticas desde SharedPreferences
  static Future<void> _loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cargar estadísticas
      final statsJson = prefs.getString(_prefsKey);
      if (statsJson != null) {
        final stats = json.decode(statsJson);
        
        // Manejar today usage con conversión ultra segura
        final todayData = stats['today'] ?? {};
        _todayUsage = {};
        if (todayData is Map) {
          todayData.forEach((key, value) {
            if (key is String && value is num) {
              _todayUsage[key] = value.toInt();
            }
          });
        }
        
        // Manejar total usage con conversión ultra segura
        final totalData = stats['total'] ?? {};
        _totalUsage = {};
        if (totalData is Map) {
          totalData.forEach((key, value) {
            if (key is String && value is num) {
              _totalUsage[key] = value.toInt();
            }
          });
        }
        
        // Manejar costs con conversión ultra segura
        final costsData = stats['costs'] ?? {};
        _estimatedCosts = {};
        if (costsData is Map) {
          costsData.forEach((key, value) {
            if (key is String && value is num) {
              _estimatedCosts[key] = value.toDouble();
            }
          });
        }
      }
      
      // Cargar fecha de último reset
      final lastResetString = prefs.getString(_lastResetKey);
      if (lastResetString != null) {
        _lastReset = DateTime.parse(lastResetString);
      }
      
      print('📊 Estadísticas cargadas desde preferencias');
    } catch (e) {
      print('❌ Error cargando estadísticas: $e');
      // En caso de error, inicializar con valores vacíos
      _todayUsage = {};
      _totalUsage = {};
      _estimatedCosts = {};
    }
  }
  
  /// Guardar estadísticas en SharedPreferences
  static Future<void> _saveStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Guardar estadísticas
      final stats = {
        'today': _todayUsage,
        'total': _totalUsage,
        'costs': _estimatedCosts,
      };
      await prefs.setString(_prefsKey, json.encode(stats));
      
      // Guardar fecha de último reset
      if (_lastReset != null) {
        await prefs.setString(_lastResetKey, _lastReset!.toIso8601String());
      }
    } catch (e) {
      print('❌ Error guardando estadísticas: $e');
    }
  }
  
  /// Obtener nombre legible de la API
  static String getApiDisplayName(String apiType) {
    const names = {
      'openai_chat': 'ChatGPT',
      'openai_whisper': 'Whisper (Voz)',
      'mapbox_geocoding': 'Mapbox Geocoding',
      'mapbox_directions': 'Mapbox Direcciones',
      'openroute_directions': 'OpenRoute Direcciones',
      'nominatim': 'Nominatim',
    };
    return names[apiType] ?? apiType;
  }
  
  /// Obtener icono de la API
  static String getApiIcon(String apiType) {
    const icons = {
      'openai_chat': '🤖',
      'openai_whisper': '🎤',
      'mapbox_geocoding': '🗺️',
      'mapbox_directions': '🧭',
      'openroute_directions': '📍',
      'nominatim': '🌍',
    };
    return icons[apiType] ?? '📡';
  }
  
  /// Limpiar completamente las preferencias guardadas (usar en caso de datos corruptos)
  static Future<void> clearAllPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      await prefs.remove(_lastResetKey);
      
      // Reinicializar variables
      _todayUsage = {};
      _totalUsage = {};
      _estimatedCosts = {};
      _lastReset = null;
      
      print('📊 Preferencias limpiadas completamente');
    } catch (e) {
      print('❌ Error limpiando preferencias: $e');
    }
  }
} 