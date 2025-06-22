# 🔧 Solución de Problemas - Aurora Assistant

## Problema: "No le fue posible calcular la ruta"

### 🔍 Diagnóstico

Si Aurora dice que "no le fue posible" calcular una ruta, puede ser por varios motivos:

#### 1. **Problema de Detección de Consulta**
- La consulta no está siendo detectada como una consulta de navegación
- Los patrones regex no coinciden con tu forma de hablar

#### 2. **Problema de Geocodificación**
- El lugar no se encuentra en la base de datos de Mapbox
- El token de Mapbox no es válido o ha expirado
- Problemas de conectividad con la API

#### 3. **Problema de Ubicación Actual**
- No se puede obtener tu ubicación GPS
- Permisos de ubicación no habilitados

### 🛠️ Soluciones

#### **Paso 1: Probar la Funcionalidad**
Di exactamente: **"probar navegación"**

Esto ejecutará una prueba automática que te dirá:
- Si la geocodificación funciona
- Si el cálculo de rutas funciona
- Dónde está el problema específico

#### **Paso 2: Verificar Comandos de Voz**

**Comandos que SÍ funcionan:**
- ✅ "Mejor ruta a Choloma"
- ✅ "Ruta a Choloma"
- ✅ "¿Cómo llego a Choloma?"
- ✅ "Ir a Choloma"

**Comandos que pueden NO funcionar:**
- ❌ "Mejor ruta para ir de mi ubicación hacia el centro de choloma" (muy largo)
- ❌ "Dame la mejor ruta para ir a Choloma" (patrón no reconocido)

#### **Paso 3: Verificar Token de Mapbox**

El token actual en el código es de ejemplo. Para que funcione correctamente:

1. Ve a [Mapbox](https://www.mapbox.com/)
2. Crea una cuenta gratuita
3. Obtén tu token de acceso
4. Reemplaza en `lib/config/app_config.dart`:
   ```dart
   static const String mapboxAccessToken = 'TU_TOKEN_AQUI';
   ```

#### **Paso 4: Verificar Permisos**

Asegúrate de que la app tenga permisos de:
- **Ubicación**: Para obtener tu posición actual
- **Internet**: Para conectarse a las APIs

### 🧪 Comandos de Prueba

#### **Prueba Básica:**
```
"probar navegación"
```

#### **Pruebas de Detección:**
```
"Mejor ruta a Madrid"
"Ruta a Barcelona"
"¿Cómo llego al aeropuerto?"
```

#### **Pruebas de Búsqueda:**
```
"Buscar restaurante"
"Encontrar gasolinera"
"¿Dónde está el hospital?"
```

### 📊 Logs de Debugging

El código ahora incluye logs detallados. En la consola verás:

```
🔍 Procesando consulta de navegación: mejor ruta a choloma
🗺️ Detectado cálculo de ruta
🎯 Información de ruta extraída: {destination: choloma, waypoints: null}
📍 Destino: choloma
🛣️ Calculando mejor ruta
🌍 Geocodificando dirección: choloma
📡 Respuesta de geocodificación: 200
✅ Coordenadas encontradas: [15.6144, -87.9530]
```

### 🚨 Errores Comunes

#### **Error: "No se pudo extraer el destino"**
- **Causa**: La consulta no coincide con los patrones regex
- **Solución**: Usa comandos más simples como "Ruta a Choloma"

#### **Error: "No se pudo geocodificar"**
- **Causa**: El lugar no existe o el token es inválido
- **Solución**: Verifica el token de Mapbox y prueba con lugares más conocidos

#### **Error: "No se pudo obtener tu ubicación"**
- **Causa**: Permisos de ubicación no habilitados
- **Solución**: Habilita permisos de ubicación en la app

### 📱 Comandos Recomendados

Para obtener mejores resultados, usa estos formatos:

#### **Rutas Simples:**
- "Ruta a [destino]"
- "Mejor ruta a [destino]"
- "¿Cómo llego a [destino]?"

#### **Búsquedas:**
- "Buscar [lugar]"
- "Encontrar [lugar]"
- "¿Dónde está [lugar]?"

#### **Ejemplos Específicos:**
- "Ruta a Choloma"
- "Mejor ruta a Tegucigalpa"
- "Buscar hospital"
- "Encontrar gasolinera"

### 🔄 Próximos Pasos

Si el problema persiste:

1. **Ejecuta**: "probar navegación"
2. **Revisa los logs** en la consola
3. **Verifica el token** de Mapbox
4. **Prueba con lugares conocidos** como "Madrid" o "Barcelona"
5. **Reporta el error específico** que aparece en los logs

### 📞 Soporte

Si necesitas ayuda adicional:
1. Comparte los logs de debugging
2. Indica el comando exacto que usaste
3. Menciona si el problema es consistente o intermitente 