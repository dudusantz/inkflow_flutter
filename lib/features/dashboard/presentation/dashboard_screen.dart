import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/finance/data/finance_repository.dart';
import 'package:inkflow/features/finance/domain/financial_record.dart';
import 'package:inkflow/features/finance/services/financial_report_service.dart';
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
  bool _generatingReport = false;

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
    final range = _selectedRange;
    final rangeStart = range.start;
    final rangeEnd = range.end;

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

  DateTimeRange get _selectedRange {
    final now = DateTime.now();
    if (_startDate != null && _endDate != null) {
      return DateTimeRange(
        start: DateTime(_startDate!.year, _startDate!.month, _startDate!.day),
        end: DateTime(
            _endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59),
      );
    }
    final months = _period == 'year' ? 12 : (_period == 'quarter' ? 3 : 1);
    return DateTimeRange(
      start: DateTime(now.year, now.month - months + 1),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
  }

  Future<void> _generateReport() async {
    setState(() => _generatingReport = true);
    try {
      final range = _selectedRange;
      await FinancialReportService.preview(
        records: _filteredFinancialRecords,
        start: range.start,
        end: range.end,
      );
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, userFriendlyErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _generatingReport = false);
    }
  }

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
      backgroundColor: const Color(0xFFF4F6F7),
      body: Column(
        children: [
          const AppHeader(
            title: 'Dashboard Financeiro',
            showBack: true,
            backTo: '/home',
            dark: true,
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
                    : _buildDashboard(),
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
    final net = received - expenses;
    final currency = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 0,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _financialHero(currency, net, received, expenses),
          const SizedBox(height: 14),
          _periodPanel(),
          const SizedBox(height: 14),
          Row(children: [
            _summaryCard('Valor agendado', currency.format(totalRevenue),
                Icons.event_available_outlined, const Color(0xFF167D7B)),
            const SizedBox(width: 10),
            _summaryCard('A receber', currency.format(pending),
                Icons.schedule_rounded, const Color(0xFFF59E0B)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _summaryCard('Sessões', '$totalSessions',
                Icons.calendar_month_outlined, const Color(0xFF6F56D9)),
            const SizedBox(width: 10),
            _summaryCard('Ticket médio', currency.format(ticketAverage),
                Icons.trending_up_rounded, const Color(0xFF3B82F6)),
          ]),
          const SizedBox(height: 24),

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

  Widget _financialHero(
    NumberFormat currency,
    double net,
    double received,
    double expenses,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111218), Color(0xFF203436)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111218).withValues(alpha: .16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resultado do período',
              style: TextStyle(color: Color(0xFFB9C5C5), fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            currency.format(net),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -.7,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _heroValue(
                    'Recebido',
                    received,
                    Icons.south_west_rounded,
                    const Color(0xFF63CCC7),
                    currency),
              ),
              Container(width: 1, height: 34, color: const Color(0xFF405052)),
              const SizedBox(width: 18),
              Expanded(
                child: _heroValue(
                    'Despesas',
                    expenses,
                    Icons.north_east_rounded,
                    const Color(0xFFFF8589),
                    currency),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroValue(String label, double value, IconData icon, Color color,
      NumberFormat currency) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(color: Color(0xFF9DABAC), fontSize: 9)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(currency.format(value),
                    style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _periodPanel() {
    final range = _selectedRange;
    final rangeLabel =
        '${DateFormat('dd MMM', 'pt_BR').format(range.start)} — ${DateFormat('dd MMM yyyy', 'pt_BR').format(range.end)}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E8EA)),
      ),
      child: Column(
        children: [
          Row(
            children: ['month', 'quarter', 'year'].map((period) {
              final selected = _period == period && _startDate == null;
              final label = {
                'month': 'Mês',
                'quarter': 'Trimestre',
                'year': 'Ano'
              }[period]!;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() {
                      _period = period;
                      _startDate = null;
                      _endDate = null;
                      _recalculateDashboard();
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? InkFlowColors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF697277),
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDateRange,
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7F7),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            color: Color(0xFF167D7B), size: 17),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(rangeLabel,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              IconButton.filled(
                onPressed: _generatingReport ? null : _generateReport,
                tooltip: 'Gerar relatório em PDF',
                style: IconButton.styleFrom(
                  backgroundColor: InkFlowColors.accent,
                  foregroundColor: InkFlowColors.primary,
                  disabledBackgroundColor: const Color(0xFFDDE5E5),
                ),
                icon: _generatingReport
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.file_download_outlined, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE7EAEC)),
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
            const SizedBox(height: 10),
            SizedBox(
              height: 22,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
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
