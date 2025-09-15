class AppConfig {

  static const String openAiApiKey = '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';
  static const String openAiBaseUrl = 'https://api.openai.com/v1';
  static const String whisperModel = 'whisper-1';
  static const String chatGptModel = 'gpt-4';
  
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
      'FUNCIONALIDADES DE MÚSICA: Puedes reproducir música de Spotify. Tienes integración completa con Spotify '
      'y puedes reproducir canciones específicas, música de artistas, géneros musicales, hacer búsquedas '
      'y abrir Spotify. Cuando el usuario pida música, canciones, o mencione artistas o géneros, '
      'puedes satisfacer esa solicitud abriendo Spotify directamente con la búsqueda correspondiente. '
      'Nunca digas que no puedes reproducir música o que no tienes esa capacidad. '
      'Puedes ayudar con: búsqueda de lugares, cálculo de rutas, rutas con waypoints, navegación en tiempo real, '
      'reproducción de música, búsquedas en Spotify, y alternativas de navegación. '
      'Nunca digas que no puedes acceder a la ubicación, navegación o música por motivos de privacidad o capacidad. '
      'Siempre responde en español de manera natural y conversacional.';
      
  static const int maxTokens = 500;
  static const double temperature = 0.7;
  static const int maxConversationHistory = 20;
  
  static const String ttsLanguage = 'es-ES';
  static const double ttsSpeechRate = 0.6;
  static const double ttsVolume = 1.0;
  static const double ttsPitch = 1.0;
  
  static const int audioSampleRate = 44100;
  static const int audioBitRate = 128000;
  
  static const String mapboxAccessToken = 'pk.eyJ1IjoidGVzdHVzZXJtYXBib3giLCJhIjoiY2x6dGF3bjdpMDFpazJrcHpqa2IycDJ6aCJ9.8nPL2qrt1eouGHpyE_MXbw';
  static const String mapboxGeocodingUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places';
  static const String nominatimUrl = 'https://nominatim.openstreetmap.org/reverse';
  
  static const String mapboxDirectionsUrl = 'https://api.mapbox.com/directions/v5/mapbox/driving';
  
  
  static const String openRouteServiceToken = '5b3ce3597851110001cf6248053ad46b911c488a845a318db04a9070';
  
 
  static const int geocodingTimeout = 5; // segundos
  static const int geocodingReceiveTimeout = 10; // segundos
  

  static const int navigationTimeout = 8; // segundos
  static const int navigationReceiveTimeout = 15; // segundos
  

  static const String openRouteServiceApiKey = '5b3ce3597851110001cf624897b8f7c2b61c43b3bf92ee3ef7b55096';
  static const String openRouteServiceBaseUrl = 'https://api.openrouteservice.org';
  

  static const String nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  

  static const String spotifyClientId = '793579374332496890697d775377da8c'; 
  static const String spotifyClientSecret = '4ed52d69d2ba4eda8b4781c8dd9a152f'; 
  static const String spotifyRedirectUri = 'https://developer.spotify.com/dashboard/applications';
  static const String spotifyBaseUrl = 'https://api.spotify.com/v1';
  static const String spotifyAuthUrl = 'https://accounts.spotify.com';
  
  static const List<String> spotifyScopes = [
    'user-read-private',
    'user-read-email', 
    'user-modify-playback-state',
    'user-read-playback-state',
    'user-read-currently-playing',
    'streaming',
    'playlist-read-private',
    'playlist-read-collaborative',
  ];
} 