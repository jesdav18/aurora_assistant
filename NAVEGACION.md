# 🗺️ Funcionalidades de Navegación - Aurora Assistant

## Descripción General

Aurora Assistant ahora incluye capacidades avanzadas de navegación y planificación de rutas, permitiendo a los conductores obtener información detallada sobre rutas, distancias, tiempos estimados y búsqueda de lugares.

## 🎯 Funcionalidades Principales

### 1. Búsqueda de Lugares
**Comandos de voz:**
- "Buscar restaurante italiano"
- "Encontrar gasolinera"
- "¿Dónde está el hospital más cercano?"
- "Localizar farmacia"

**Respuesta ejemplo:**
```
Encontré estos lugares:
1. Restaurante El Rincón, Calle Mayor 123, Madrid
2. Pizzería Bella Vista, Plaza España 45, Madrid
3. Trattoria Romana, Gran Vía 67, Madrid
```

### 2. Cálculo de Rutas Simples
**Comandos de voz:**
- "Ruta a Madrid"
- "¿Cómo llego al aeropuerto?"
- "Mejor ruta a Barcelona"
- "Calcular ruta a Valencia"

**Respuesta ejemplo:**
```
Ruta hacia Madrid:
Distancia: 45.2 km
Tiempo estimado: 35 minutos
```

### 3. Rutas con Waypoints (Puntos Intermedios)
**Comandos de voz:**
- "Ruta a Madrid pasando por Toledo"
- "Ir a Barcelona a través de Zaragoza"
- "Ruta a Valencia por donde pase por Alicante"

**Respuesta ejemplo:**
```
Ruta hacia Madrid:
Distancia: 52.8 km
Tiempo estimado: 42 minutos
Pasando por: Toledo
```

### 4. Múltiples Rutas Alternativas
**Comandos de voz:**
- "Mejor ruta a Madrid"
- "Alternativas para ir a Barcelona"
- "Rutas a Valencia"

**Respuesta ejemplo:**
```
Rutas hacia Madrid:

Ruta 1: 45.2 km, 35 minutos
Ruta 2: 48.7 km, 32 minutos
Ruta 3: 52.1 km, 38 minutos

La mejor ruta es: 45.2 km en 35 minutos.
```

## 🔧 Tecnologías Utilizadas

### APIs de Mapbox
- **Geocoding API**: Para convertir direcciones en coordenadas
- **Directions API**: Para calcular rutas y navegación
- **Places API**: Para búsqueda de lugares

### Características Técnicas
- **Tiempo de respuesta**: 5-8 segundos
- **Precisión**: GPS + geocodificación
- **Idioma**: Español
- **Formato**: Distancias en km, tiempos en minutos

## 📱 Integración con Voz

### Detección Inteligente
Aurora detecta automáticamente el tipo de consulta:
- **Búsqueda**: Palabras como "buscar", "encontrar", "dónde está"
- **Navegación**: Palabras como "ruta", "camino", "como llegar"
- **Waypoints**: Frases como "pasando por", "a través de"

### Respuestas Optimizadas
- **Breves**: Ideales para escuchar mientras conduces
- **Claras**: Información esencial (distancia, tiempo)
- **Naturales**: Lenguaje conversacional en español

## 🚗 Casos de Uso para Conductores

### 1. Planificación de Viajes
```
Usuario: "Ruta a Madrid pasando por Toledo"
Aurora: "Ruta hacia Madrid: 52.8 km, 42 minutos. Pasando por: Toledo"
```

### 2. Búsqueda de Servicios
```
Usuario: "Buscar gasolinera"
Aurora: "Encontré estos lugares: 1. Repsol Calle Mayor, 2. Cepsa Plaza España..."
```

### 3. Navegación de Emergencia
```
Usuario: "¿Dónde está el hospital más cercano?"
Aurora: "Encontré estos lugares: 1. Hospital General, 2. Clínica San José..."
```

### 4. Rutas Alternativas
```
Usuario: "Mejor ruta a Barcelona"
Aurora: "Rutas hacia Barcelona: Ruta 1: 620 km, 6h 15min. La mejor ruta es: 620 km en 6h 15min."
```

## ⚙️ Configuración

### Requisitos
- **Token de Mapbox**: Configurado en `lib/config/app_config.dart`
- **Permisos de ubicación**: Habilitados en el dispositivo
- **Conexión a internet**: Para consultas en tiempo real

### Límites de Uso
- **Plan gratuito de Mapbox**: 50,000 consultas/mes
- **Tiempo de respuesta**: Máximo 15 segundos
- **Precisión**: Depende de la señal GPS

## 🔄 Flujo de Funcionamiento

1. **Usuario habla**: "Ruta a Madrid"
2. **Detección**: Aurora identifica consulta de navegación
3. **Geocodificación**: Convierte "Madrid" en coordenadas
4. **Cálculo de ruta**: Obtiene ruta desde ubicación actual
5. **Formateo**: Prepara respuesta en español
6. **Respuesta**: "Ruta hacia Madrid: 45.2 km, 35 minutos"

## 🎯 Beneficios para Conductores

- **Mano libre**: Control total por voz
- **Seguridad**: Sin distracciones visuales
- **Precisión**: Rutas optimizadas en tiempo real
- **Flexibilidad**: Múltiples opciones de navegación
- **Naturalidad**: Comunicación conversacional

## 📈 Próximas Mejoras

- [ ] Navegación paso a paso
- [ ] Alertas de tráfico
- [ ] Información de peajes
- [ ] Puntos de interés en ruta
- [ ] Historial de rutas frecuentes 