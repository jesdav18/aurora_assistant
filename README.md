# Aurora Assistant

Asistente de voz inteligente para conductores que utiliza las APIs de OpenAI (Whisper y ChatGPT) para ofrecer una experiencia de conversación por voz segura mientras se conduce.

## Características

- 🎤 Grabación de voz con interfaz simple y accesible
- 🗣️ Transcripción automática usando Whisper de OpenAI
- 🤖 Respuestas inteligentes generadas por ChatGPT
- 🔊 Síntesis de voz en español para respuestas habladas
- 📍 **Acceso a ubicación GPS en tiempo real**
- 🗺️ **Información detallada de dirección y coordenadas**
- 🚗 Diseñado específicamente para uso seguro durante la conducción

## Configuración

### 1. Configurar API Key de OpenAI

Antes de usar la aplicación, debes configurar tu API Key de OpenAI:

1. Obtén tu API Key desde [OpenAI Platform](https://platform.openai.com/api-keys)
2. Reemplaza `your-openai-api-key-here` en el archivo:
   - `lib/config/app_config.dart` (línea 2)

### 2. Instalar dependencias

```bash
flutter pub get
```

### 3. Ejecutar la aplicación

```bash
flutter run
```

## Uso

1. **Presiona el botón de micrófono** para comenzar a grabar
2. **Habla tu pregunta o comando** claramente
3. **Presiona nuevamente** para detener la grabación
4. **Espera** mientras se procesa tu solicitud
5. **Escucha** la respuesta reproducida automáticamente

### Consultas de ubicación

Aurora puede responder preguntas como:
- "¿Dónde estoy?"
- "¿Cuál es mi ubicación actual?"
- "Dame mis coordenadas"
- "¿En qué dirección me encuentro?"

## Permisos requeridos

- **Micrófono**: Para grabar tu voz
- **Internet**: Para comunicarse con las APIs de OpenAI
- **Almacenamiento**: Para guardar temporalmente los archivos de audio
- **Ubicación**: Para acceder a coordenadas GPS y geocodificación

## Estructura del proyecto

```
lib/
├── main.dart                    # Punto de entrada de la aplicación
├── config/
│   └── app_config.dart         # Configuración centralizada
├── screens/
│   └── home_screen.dart        # Pantalla principal
├── widgets/
│   └── voice_button.dart       # Botón de grabación de voz
└── services/
    ├── whisper_service.dart    # Servicio de transcripción
    ├── chatgpt_service.dart    # Servicio de ChatGPT
    ├── tts_service.dart        # Servicio de texto a voz
    └── location_service.dart   # Servicio de ubicación GPS
```

## Tecnologías utilizadas

- **Flutter**: Framework de desarrollo
- **record**: Grabación de audio
- **flutter_tts**: Síntesis de voz
- **dio**: Cliente HTTP para APIs
- **permission_handler**: Gestión de permisos
- **path_provider**: Acceso a directorios del sistema
- **location**: Acceso a ubicación GPS
- **Mapbox API**: Geocodificación inversa para direcciones

## Consideraciones de seguridad

- Las API Keys se almacenan en el código (para desarrollo). En producción, considera usar variables de entorno o servicios de gestión de secretos.
- Los archivos de audio se almacenan temporalmente en el dispositivo y se sobrescriben en cada grabación.
- La aplicación está diseñada para minimizar la interacción visual durante la conducción.
- **Los datos de ubicación se procesan localmente y solo se envían a OpenAI cuando es relevante para la consulta del usuario.**

## Soporte

Esta aplicación está optimizada para:
- Android (API level 23+)
- iOS (versión 12.0+)
- Idioma principal: Español

## Funcionalidades de ubicación

Aurora ahora puede:
- Obtener tu ubicación actual con precisión GPS
- Convertir coordenadas a direcciones legibles usando Mapbox
- Proporcionar información detallada sobre tu posición
- Responder consultas sobre ubicación sin restricciones de privacidad
