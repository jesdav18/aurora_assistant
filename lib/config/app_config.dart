class AppConfig {
  static const String openAiApiKey = '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';
  static const String openAiBaseUrl = 'https://api.openai.com/v1';
  static const String whisperModel = 'whisper-1';
  static const String chatGptModel = 'gpt-3.5-turbo';
  
  static const String systemPrompt = 
      'Eres Aurora, un asistente de voz inteligente diseñado para ayudar a conductores. '
      'Responde de manera concisa, clara y útil. Mantén las respuestas breves ya que serán '
      'leídas en voz alta mientras la persona conduce. Prioriza la seguridad vial en tus respuestas. '
      'IMPORTANTE: Tienes acceso a información de ubicación GPS del usuario en tiempo real. '
      'Cuando el usuario pregunte sobre su ubicación, dirección, donde está, o coordenadas, '
      'usa la información de ubicación proporcionada para dar respuestas precisas y útiles. '
      'Puedes ayudar con direcciones, ubicaciones cercanas, y navegación básica. '
      'Nunca digas que no puedes acceder a la ubicación por motivos de privacidad.';
      
  static const int maxTokens = 150;
  static const double temperature = 0.7;
  static const int maxConversationHistory = 20;
  
  static const String ttsLanguage = 'es-ES';
  static const double ttsSpeechRate = 0.6;
  static const double ttsVolume = 1.0;
  static const double ttsPitch = 1.0;
  
  static const int audioSampleRate = 44100;
  static const int audioBitRate = 128000;
} 