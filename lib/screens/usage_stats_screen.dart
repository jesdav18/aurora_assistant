import 'package:flutter/material.dart';
import '../services/api_usage_tracker.dart';

class UsageStatsScreen extends StatefulWidget {
  const UsageStatsScreen({super.key});

  @override
  State<UsageStatsScreen> createState() => _UsageStatsScreenState();
}

class _UsageStatsScreenState extends State<UsageStatsScreen> {
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _limitsStatus = {};
  
  @override
  void initState() {
    super.initState();
    _loadStats();
  }
  
  void _loadStats() {
    setState(() {
      _stats = ApiUsageTracker.getUsageStats();
      _limitsStatus = ApiUsageTracker.checkLimitsStatus();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // Manejar los datos de manera más robusta sin asumir tipos específicos
    final todayUsageRaw = _stats['today'] ?? {};
    final totalUsageRaw = _stats['total'] ?? {};
    final costsRaw = _stats['costs'] ?? {};
    
    // Convertir a los tipos correctos de manera segura
    final Map<String, int> todayUsage = {};
    if (todayUsageRaw is Map) {
      todayUsageRaw.forEach((key, value) {
        if (key is String && value is num) {
          todayUsage[key] = value.toInt();
        }
      });
    }
    
    final Map<String, int> totalUsage = {};
    if (totalUsageRaw is Map) {
      totalUsageRaw.forEach((key, value) {
        if (key is String && value is num) {
          totalUsage[key] = value.toInt();
        }
      });
    }
    
    final Map<String, double> costs = {};
    if (costsRaw is Map) {
      costsRaw.forEach((key, value) {
        if (key is String && value is num) {
          costs[key] = value.toDouble();
        }
      });
    }
    
    final totalCost = ApiUsageTracker.getTotalEstimatedCost();
    final todayCost = ApiUsageTracker.getTodayEstimatedCost();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('📊 Uso de APIs'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Actualizar',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'reset_daily',
                child: Row(
                  children: [
                    Icon(Icons.today, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Resetear día'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reset_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Resetear todo'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_prefs',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('Limpiar preferencias'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadStats(),
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Resumen de costos
            _buildCostSummaryCard(totalCost, todayCost),
            
            SizedBox(height: 16),
            
            // Límites y advertencias
            if (_limitsStatus.isNotEmpty) ...[
              _buildLimitsCard(),
              SizedBox(height: 16),
            ],
            
            // Estadísticas por API
            _buildApiStatsCard(todayUsage, totalUsage, costs),
            
            SizedBox(height: 16),
            
            // Información adicional
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCostSummaryCard(double totalCost, double todayCost) {
    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.green[400]!, Colors.green[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '💰 Total',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '\$${totalCost.toStringAsFixed(4)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'USD',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 60,
                    width: 1,
                    color: Colors.white30,
                  ),
                  Column(
                    children: [
                      Text(
                        '📅 Hoy',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '\$${todayCost.toStringAsFixed(4)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'USD',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLimitsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Límites de Uso',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ..._limitsStatus.entries.map((entry) {
              final apiType = entry.key;
              final status = entry.value as Map<String, dynamic>;
              final used = status['used'] as int;
              final limit = status['limit'] as int;
              final percentage = status['percentage'] as double;
              final exceeded = status['exceeded'] as bool;
              final warning = status['warning'] as bool;
              
              Color progressColor = Colors.green;
              if (exceeded) {
                progressColor = Colors.red;
              } else if (warning) {
                progressColor = Colors.orange;
              }
              
              return Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${ApiUsageTracker.getApiIcon(apiType)} ${ApiUsageTracker.getApiDisplayName(apiType)}',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '$used / $limit',
                          style: TextStyle(
                            color: progressColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${percentage.toStringAsFixed(1)}% utilizado',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildApiStatsCard(Map<String, int> todayUsage, Map<String, int> totalUsage, Map<String, double> costs) {
    // Combinar todas las APIs que han sido usadas
    Set<String> allApis = {...todayUsage.keys, ...totalUsage.keys, ...costs.keys};
    
    if (allApis.isEmpty) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.info_outline, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'No hay datos de uso aún',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Las estadísticas aparecerán cuando uses las funciones de la app',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.api, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Estadísticas por API',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...allApis.map((apiType) {
              final todayCount = todayUsage[apiType] ?? 0;
              final totalCount = totalUsage[apiType] ?? 0;
              final cost = costs[apiType] ?? 0.0;
              
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          ApiUsageTracker.getApiIcon(apiType),
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ApiUsageTracker.getApiDisplayName(apiType),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Hoy: $todayCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Total: $totalCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${cost.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                        Text(
                          'USD',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Información',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildInfoRow('📊', 'Las estadísticas se resetean automáticamente cada día'),
            _buildInfoRow('💰', 'Los costos son estimaciones basadas en tarifas públicas'),
            _buildInfoRow('🔄', 'Desliza hacia abajo para actualizar los datos'),
            _buildInfoRow('⚠️', 'Los límites te ayudan a controlar el uso de APIs gratuitas'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _handleMenuAction(String action) async {
    switch (action) {
      case 'reset_daily':
        final confirm = await _showConfirmDialog(
          'Resetear estadísticas del día',
          '¿Estás seguro de que quieres resetear las estadísticas de hoy?',
        );
        if (confirm) {
          await ApiUsageTracker.resetDailyStats();
          _loadStats();
          _showSnackBar('Estadísticas del día reseteadas');
        }
        break;
      case 'reset_all':
        final confirm = await _showConfirmDialog(
          'Resetear todas las estadísticas',
          '¿Estás seguro de que quieres resetear TODAS las estadísticas? Esta acción no se puede deshacer.',
        );
        if (confirm) {
          await ApiUsageTracker.resetAllStats();
          _loadStats();
          _showSnackBar('Todas las estadísticas reseteadas');
        }
        break;
      case 'clear_prefs':
        final confirm = await _showConfirmDialog(
          'Limpiar preferencias',
          '¿Estás seguro de que quieres limpiar todas las preferencias? Esta acción no se puede deshacer.',
        );
        if (confirm) {
          await ApiUsageTracker.clearAllPreferences();
          _loadStats();
          _showSnackBar('Preferencias limpiadas');
        }
        break;
    }
  }
  
  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Confirmar'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    ) ?? false;
  }
  
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
      ),
    );
  }
} 