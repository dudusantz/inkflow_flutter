import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/finance/data/finance_repository.dart';
import 'package:inkflow/features/finance/domain/financial_record.dart';
import 'package:inkflow/features/schedule/data/appointment_repository.dart';
import 'package:inkflow/features/schedule/domain/appointment.dart';

/// Painel calculado exclusivamente com os agendamentos reais do tatuador.
/// Combina agenda, recebimentos e despesas reais do tatuador autenticado.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _period = 'month';
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _periodError;

  List<Appointment> _allAppointments = [];
  List<Appointment> _filteredAppointments = [];
  List<FinancialRecord> _allFinancialRecords = [];
  List<FinancialRecord> _filteredFinancialRecords = [];
  List<Map<String, dynamic>> _monthlyData = [];
  List<Map<String, dynamic>> _styleData = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final result = await Future.wait([
        ref.read(appointmentRepositoryProvider).listForUser(asArtist: true),
        ref.read(financeRepositoryProvider).listRecords(),
      ]);
      _allAppointments = result[0] as List<Appointment>;
      _allFinancialRecords = result[1] as List<FinancialRecord>;

      if (mounted) {
        setState(() {
          _recalculateDashboard();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorSnackBar(
          context,
          userFriendlyErrorMessage(e),
        );
      }
    }
  }

  void _recalculateDashboard() {
    final now = DateTime.now();
    final custom = _startDate != null && _endDate != null;
    final months = _period == 'year' ? 12 : (_period == 'quarter' ? 3 : 6);
    final rangeStart = custom
        ? DateTime(_startDate!.year, _startDate!.month, _startDate!.day)
        : DateTime(now.year, now.month - months + 1);
    final rangeEnd = custom
        ? DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59)
        : DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    _filteredAppointments = _allAppointments.where((appointment) {
      final normalizedStatus = appointment.status.toLowerCase();
      final isCancelled = normalizedStatus.contains('cancel');
      return !isCancelled &&
          !appointment.date.isBefore(rangeStart) &&
          !appointment.date.isAfter(rangeEnd);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    _filteredFinancialRecords = _allFinancialRecords
        .where((record) =>
            !record.date.isBefore(rangeStart) && !record.date.isAfter(rangeEnd))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final bucketStart = DateTime(rangeStart.year, rangeStart.month);
    final bucketEnd = DateTime(rangeEnd.year, rangeEnd.month);
    final buckets = <Map<String, dynamic>>[];
    var cursor = bucketStart;
    while (!cursor.isAfter(bucketEnd)) {
      final sessions = _filteredAppointments.where((appointment) =>
          appointment.date.year == cursor.year &&
          appointment.date.month == cursor.month);
      buckets.add({
        'month': DateFormat('MMM', 'pt_BR').format(cursor).replaceAll('.', ''),
        'fullMonth': DateFormat('MMMM yyyy', 'pt_BR').format(cursor),
        'revenue': sessions.fold<double>(0, (sum, item) => sum + item.price),
        'sessions': sessions.length,
      });
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    _monthlyData = buckets;

    final styleCounts = <String, int>{};
    for (final appointment in _filteredAppointments) {
      final style = appointment.style.trim().isEmpty
          ? 'Não informado'
          : appointment.style.trim();
      styleCounts.update(style, (count) => count + 1, ifAbsent: () => 1);
    }
    final sortedStyles = styleCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    const colors = [
      InkFlowColors.accent,
      Color(0xFF8B5CF6),
      Color(0xFFF59E0B),
      Color(0xFF3B82F6),
    ];
    _styleData = sortedStyles.take(4).toList().asMap().entries.map((entry) {
      final item = entry.value;
      final percent = _filteredAppointments.isEmpty
          ? 0
          : ((item.value / _filteredAppointments.length) * 100).round();
      return {
        'name': item.key,
        'percent': percent,
        'count': item.value,
        'color': colors[entry.key % colors.length],
      };
    }).toList();
  }

  bool get _isPeriodInvalid =>
      _startDate != null && _endDate != null && _startDate!.isAfter(_endDate!);

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
        _periodError = range.start.isAfter(range.end)
            ? 'O período selecionado é inválido.'
            : null;
      });
      if (!_isPeriodInvalid) await _fetchDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const AppHeader(
            title: 'Dashboard Financeiro',
            showBack: true,
            backTo: '/home',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: InkFlowColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_outlined,
                          color: Color(0xFF167D7B), size: 19),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Dados reais da agenda e da gestão. Compare valores agendados, recebimentos e despesas.',
                          style: TextStyle(
                            color: Color(0xFF376765),
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(
                      _startDate == null
                          ? 'Período personalizado'
                          : '${_startDate!.day}/${_startDate!.month} – ${_endDate!.day}/${_endDate!.month}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: InkFlowColors.primary,
                      side: const BorderSide(color: Color(0xFFE1E4E8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
                  color: InkFlowColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: Text(
                  _periodError!,
                  style:
                      const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: InkFlowColors.accent),
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
            child: Icon(Icons.bar_chart, color: Colors.grey.shade400, size: 40),
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
    final totalRevenue = _monthlyData.fold<double>(
        0, (sum, m) => sum + (m['revenue'] as double));
    final totalSessions =
        _monthlyData.fold<int>(0, (sum, m) => sum + (m['sessions'] as int));
    final ticketAverage =
        totalSessions == 0 ? 0.0 : totalRevenue / totalSessions;
    final received = _filteredFinancialRecords
        .where((record) =>
            record.type == FinancialRecordType.payment &&
            record.status == 'PAGO')
        .fold<double>(0, (sum, record) => sum + record.amount);
    final pending = _filteredFinancialRecords
        .where((record) =>
            record.type == FinancialRecordType.payment &&
            (record.status == 'PENDENTE' || record.status == 'PARCIAL'))
        .fold<double>(0, (sum, record) => sum + record.amount);
    final expenses = _filteredFinancialRecords
        .where((record) => record.type == FinancialRecordType.expense)
        .fold<double>(0, (sum, record) => sum + record.amount);
    final currency = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 0,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Período
          Row(
            children: ['month', 'quarter', 'year'].map((p) {
              final label =
                  {'month': 'Mês', 'quarter': 'Trimestre', 'year': 'Ano'}[p]!;
              final sel = _period == p;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _period = p;
                      _startDate = null;
                      _endDate = null;
                      _recalculateDashboard();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? InkFlowColors.primary : Colors.grey.shade100,
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
              _summaryCard('Valor agendado', currency.format(totalRevenue),
                  Icons.attach_money, InkFlowColors.accent),
              const SizedBox(width: 10),
              _summaryCard('Total de Sessões', '$totalSessions sessões',
                  Icons.calendar_today, const Color(0xFF8B5CF6)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _summaryCard('Recebido', currency.format(received),
                  Icons.south_west, const Color(0xFF10B981)),
              const SizedBox(width: 10),
              _summaryCard('Pendente', currency.format(pending), Icons.schedule,
                  const Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _summaryCard('Despesas', currency.format(expenses),
                  Icons.north_east, const Color(0xFFEF4444)),
              const SizedBox(width: 10),
              _summaryCard('Ticket médio', currency.format(ticketAverage),
                  Icons.trending_up, const Color(0xFF8B5CF6)),
            ],
          ),
          const SizedBox(height: 20),

          // Gráfico de receita
          _sectionTitle('Valor agendado por mês'),
          const SizedBox(height: 8),
          Container(
            height: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _chartMaxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        currency.format(rod.toY),
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
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.grey.shade100, strokeWidth: 1),
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
                            : InkFlowColors.primary.withValues(alpha: 0.4),
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
          _sectionTitle('Estilos mais agendados'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: _styleData.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: Text('Nenhum estilo registrado neste período.',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280))),
                    ),
                  )
                : Column(
                    children: _styleData.map((s) {
                      final pct = s['percent'] as int;
                      final color = s['color'] as Color;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

          // Sessões reais mais recentes no período.
          _sectionTitle('Sessões Recentes'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                _tableHeader(),
                if (_filteredAppointments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Nenhuma sessão neste período.',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ),
                ..._filteredAppointments
                    .take(5)
                    .toList()
                    .asMap()
                    .entries
                    .map((e) {
                  final i = e.key;
                  final appointment = e.value;
                  return _tableRow(
                    DateFormat('dd/MM').format(appointment.date),
                    appointment.style,
                    currency.format(appointment.price),
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

  double get _chartMaxY {
    if (_monthlyData.isEmpty) return 100;
    final highest = _monthlyData
        .map((item) => item['revenue'] as double)
        .fold<double>(0, (a, b) => a > b ? a : b);
    return highest <= 0 ? 100 : highest * 1.2;
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
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
                  color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 22,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            Text(label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
              child: Text('Estilo',
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

  Widget _tableRow(String period, String sessions, String revenue, bool alt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: alt ? Colors.white : Colors.grey.shade50,
      child: Row(
        children: [
          Expanded(child: Text(period, style: const TextStyle(fontSize: 12))),
          Expanded(child: Text(sessions, style: const TextStyle(fontSize: 12))),
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
