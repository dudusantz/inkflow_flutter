import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _period = 'month';
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _periodError;

  // Em um app real, estes dados viriam do backend via GET request
  List<Map<String, dynamic>> _monthlyData = [];
  List<Map<String, dynamic>> _styleData = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  // Simula a requisição ao banco de dados (Ex: Supabase)
  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    
    try {
      await Future.delayed(const Duration(milliseconds: 1200)); // Tempo de rede simulado
      
      if (mounted) {
        setState(() {
          _monthlyData = [
            {'month': 'Jan', 'revenue': 3200.0, 'sessions': 8},
            {'month': 'Fev', 'revenue': 4100.0, 'sessions': 10},
            {'month': 'Mar', 'revenue': 3800.0, 'sessions': 9},
            {'month': 'Abr', 'revenue': 5200.0, 'sessions': 13},
            {'month': 'Mai', 'revenue': 4800.0, 'sessions': 12},
            {'month': 'Jun', 'revenue': 6100.0, 'sessions': 15},
          ];

          _styleData = [
            {'name': 'Black Work', 'percent': 35, 'color': const Color(0xFF374151)},
            {'name': 'Geométrico', 'percent': 28, 'color': InkFlowColors.accent},
            {'name': 'Realismo', 'percent': 20, 'color': const Color(0xFF8B5CF6)},
            {'name': 'Outros', 'percent': 17, 'color': const Color(0xFFF59E0B)},
          ];
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Tratar erro (Ex: Mostrar SnackBar)
      }
    }
  }

  bool get _isPeriodInvalid =>
      _startDate != null &&
      _endDate != null &&
      _startDate!.isAfter(_endDate!);

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
        _periodError =
            range.start.isAfter(range.end) ? 'O período selecionado é inválido.' : null;
      });
      if (!_isPeriodInvalid) _fetchDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Dashboard Financeiro',
            showBack: true,
            backTo: '/home',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(
                      _startDate == null
                          ? 'Período personalizado'
                          : '${_startDate!.day}/${_startDate!.month} – ${_endDate!.day}/${_endDate!.month}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_periodError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: Text(
                  _periodError!,
                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: InkFlowColors.accent),
                  )
                : _isPeriodInvalid
                    ? const Center(
                        child: Text(
                          'Corrija o período para visualizar os gráficos.',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      )
                    : _monthlyData.isEmpty
                        ? _buildEmpty()
                        : _buildDashboard(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(Icons.bar_chart,
                color: Colors.grey.shade400, size: 40),
          ),
          const SizedBox(height: 16),
          Text('Nenhum dado disponível',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text(
            'Realize sessões para visualizar\nsuas métricas aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final totalRevenue = _monthlyData
        .fold<double>(0, (sum, m) => sum + (m['revenue'] as double));
    final totalSessions =
        _monthlyData.fold<int>(0, (sum, m) => sum + (m['sessions'] as int));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Período
          Row(
            children: ['month', 'quarter', 'year'].map((p) {
              final label = {'month': 'Mês', 'quarter': 'Trimestre', 'year': 'Ano'}[p]!;
              final sel = _period == p;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    // Em um app real, alterar o período dispararia um novo _fetchDashboardData() 
                    // passando o novo filtro para o banco.
                    setState(() => _period = p);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          sel ? InkFlowColors.primary : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                          color: sel ? Colors.white : Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Cards de summary
          Row(
            children: [
              _summaryCard('Faturamento Total',
                  'R\$ ${(totalRevenue / 1000).toStringAsFixed(1)}K',
                  Icons.attach_money, InkFlowColors.accent),
              const SizedBox(width: 10),
              _summaryCard('Total de Sessões', '$totalSessions sessões',
                  Icons.calendar_today, const Color(0xFF8B5CF6)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _summaryCard(
                  'Ticket Médio',
                  'R\$ ${(totalRevenue / totalSessions).toStringAsFixed(0)}',
                  Icons.trending_up,
                  const Color(0xFFF59E0B)),
              const SizedBox(width: 10),
              _summaryCard('Melhor Mês', 'Jun — R\$ 6.1K',
                  Icons.star, const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 20),

          // Gráfico de receita
          _sectionTitle('Receita Mensal (R\$)'),
          const SizedBox(height: 8),
          Container(
            height: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 7000,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        'R\$ ${rod.toY.toInt()}',
                        const TextStyle(color: Colors.white, fontSize: 11),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final i = val.toInt();
                        if (i >= 0 && i < _monthlyData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _monthlyData[i]['month'] as String,
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 10),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.grey.shade100, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(_monthlyData.length, (i) {
                  final isLast = i == _monthlyData.length - 1;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: _monthlyData[i]['revenue'] as double,
                        color: isLast
                            ? InkFlowColors.accent
                            : InkFlowColors.primary.withOpacity(0.4),
                        width: 18,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Distribuição de estilos
          _sectionTitle('Estilos Mais Tatuados'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: _styleData.map((s) {
                final pct = s['percent'] as int;
                final color = s['color'] as Color;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(s['name'] as String,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                          Text('$pct%',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          backgroundColor: Colors.grey.shade100,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(color),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Tabela de sessões recentes
          _sectionTitle('Sessões Recentes'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                _tableHeader(),
                ..._monthlyData.reversed.take(4).toList().asMap().entries.map((e) {
                  final i = e.key;
                  final m = e.value;
                  return _tableRow(
                    m['month'] as String,
                    '${m['sessions']} sessões',
                    'R\$ ${(m['revenue'] as double).toStringAsFixed(0)}',
                    i % 2 == 0,
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _summaryCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937)));
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
              child: Text('Período',
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.w600))),
          Expanded(
              child: Text('Sessões',
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.w600))),
          Expanded(
              child: Text('Receita',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _tableRow(
      String period, String sessions, String revenue, bool alt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: alt ? Colors.white : Colors.grey.shade50,
      child: Row(
        children: [
          Expanded(
              child: Text(period,
                  style: const TextStyle(fontSize: 12))),
          Expanded(
              child: Text(sessions,
                  style: const TextStyle(fontSize: 12))),
          Expanded(
              child: Text(revenue,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: InkFlowColors.primary))),
        ],
      ),
    );
  }
}