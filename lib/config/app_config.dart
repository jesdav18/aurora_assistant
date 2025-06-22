class AppConfig {
  static const String openAiApiKey = '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';
  static const String openAiBaseUrl = 'https://api.openai.com/v1';
  static const String whisperModel = 'whisper-1';
  static const String chatGptModel = 'gpt-3.5-turbo';
  
  static const String systemPrompt = 
      'Eres Aurora, un asistente de voz inteligente diseñado para ayudar a conductores. '
      'Responde de manera concisa, clara y útil. Mantén las respuestas breves ya que serán '
      'leídas en voz alta mientras la persona conduce. Prioriza la seguridad vial en tus respuestas. '
      'IMPORTANTE: Tienes acceso a información de ubicación GPS del usuario en tiempo real y '
      'funcionalidades avanzadas de navegación. '
      'Cuando el usuario pregunte sobre su ubicación, dirección, donde está, o coordenadas, '
      'usa la información de ubicación proporcionada para dar respuestas precisas y útiles. '
      'Para consultas simples como "¿dónde estoy?" o "mi ubicación", responde de manera natural '
      'con el nombre del lugar, no con coordenadas técnicas. Solo menciona coordenadas si el usuario '
      'las solicita específicamente. '
      'FUNCIONALIDADES DE NAVEGACIÓN: Puedes calcular rutas, buscar lugares, y planificar viajes. '
      'Cuando el usuario pida rutas, waypoints, o navegación, usa la información de navegación proporcionada '
      'para dar respuestas detalladas sobre distancias, tiempos estimados, y direcciones. '
      'NAVEGACIÓN EN TIEMPO REAL: Si el usuario dice "iniciar navegación a [destino]", "navegar a [destino]", '
      'o comandos similares, responde con "Navegación iniciada hacia [destino]. Abriendo mapa de navegación..." '
      'Esto activará la navegación en tiempo real con mapa y instrucciones de voz. '
      'Puedes ayudar con: búsqueda de lugares, cálculo de rutas, rutas con waypoints, navegación en tiempo real, '
      'y alternativas de navegación. '
      'Nunca digas que no puedes acceder a la ubicación o navegación por motivos de privacidad. '
      'Siempre responde en español de manera natural y conversacional.';
      
  static const int maxTokens = 150;
  static const double temperature = 0.7;
  static const int maxConversationHistory = 20;
  
  static const String ttsLanguage = 'es-ES';
  static const double ttsSpeechRate = 0.6;
  static const double ttsVolume = 1.0;
  static const double ttsPitch = 1.0;
  
  static const int audioSampleRate = 44100;
  static const int audioBitRate = 128000;
  
  // Configuración para APIs de geocodificación
  static const String mapboxAccessToken = 'pk.eyJ1IjoiamVzZGF2MTgiLCJhIjoiY2pibGM5OGo1NGlsOTJ3bno1NWMwNG5oYiJ9.Pezxxwt6L4aNmcdCrWK8PA';
  static const String mapboxGeocodingUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places';
  static const String nominatimUrl = 'https://nominatim.openstreetmap.org/reverse';
  
  // Configuración para APIs de navegación
  static const String mapboxDirectionsUrl = 'https://api.mapbox.com/directions/v5/mapbox/driving';
  
  // Token para OpenRouteService
  static const String openRouteServiceToken = '5b3ce3597851110001cf6248053ad46b911c488a845a318db04a9070';
  
  // Configuración de timeouts para geocodificación
  static const int geocodingTimeout = 5; // segundos
  static const int geocodingReceiveTimeout = 10; // segundos
  
  // Configuración de timeouts para navegación
  static const int navigationTimeout = 8; // segundos
  static const int navigationReceiveTimeout = 15; // segundos
} 