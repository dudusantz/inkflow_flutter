import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/finance/data/finance_repository.dart';
import 'package:inkflow/features/finance/domain/dre_summary.dart';
import 'package:inkflow/features/finance/domain/financial_record.dart';
import 'package:inkflow/features/finance/services/dre_report_service.dart';

class DreScreen extends ConsumerStatefulWidget {
  const DreScreen({super.key});

  @override
  ConsumerState<DreScreen> createState() => _DreScreenState();
}

class _DreScreenState extends ConsumerState<DreScreen> {
  late DateTimeRange _range;
  late Future<Map<String, dynamic>?> _profileFuture;
  bool _generatingPdf = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month),
      end: now,
    );
    _profileFuture = ref.read(financeRepositoryProvider).getFiscalProfile();
  }

  Future<void> _pickRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (selected != null) setState(() => _range = selected);
  }

  Future<void> _refresh() async {
    ref.invalidate(financialRecordsProvider);
    setState(() {
      _profileFuture = ref.read(financeRepositoryProvider).getFiscalProfile();
    });
    await ref.read(financialRecordsProvider.future);
  }

  Future<void> _generatePdf(
    List<FinancialRecord> records,
    Map<String, dynamic>? profile,
  ) async {
    setState(() => _generatingPdf = true);
    try {
      final end = DateTime(
          _range.end.year, _range.end.month, _range.end.day, 23, 59, 59);
      final filtered = records.where((record) =>
          !record.date.isBefore(_range.start) && !record.date.isAfter(end));
      final taxRate =
          double.tryParse(profile?['tax_rate']?.toString() ?? '') ?? 0;
      await DreReportService.preview(
        dre: DreSummary.fromRecords(filtered, taxRate: taxRate),
        start: _range.start,
        end: _range.end,
        studioName: profile?['trade_name']?.toString() ??
            profile?['legal_name']?.toString(),
      );
    } catch (error) {
      if (mounted) showErrorSnackBar(context, userFriendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(financialRecordsProvider);
    return Scaffold(
      backgroundColor: InkFlowColors.background,
      body: Column(
        children: [
          const AppHeader(
            title: 'DRE gerencial',
            showBack: true,
            backTo: '/studio-management',
          ),
          Expanded(
            child: recordsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => AsyncErrorView(
                error: error,
                customMessage: 'Não foi possível montar o DRE.',
                onRetry: _refresh,
              ),
              data: (records) => FutureBuilder<Map<String, dynamic>?>(
                future: _profileFuture,
                builder: (context, profileSnapshot) {
                  if (profileSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (profileSnapshot.hasError) {
                    return AsyncErrorView(
                      error: profileSnapshot.error!,
                      customMessage: 'Não foi possível carregar a alíquota.',
                      onRetry: _refresh,
                    );
                  }
                  final taxRate = double.tryParse(
                        profileSnapshot.data?['tax_rate']?.toString() ?? '',
                      ) ??
                      0;
                  return _DreContent(
                    records: records,
                    range: _range,
                    taxRate: taxRate,
                    onPickRange: _pickRange,
                    onRefresh: _refresh,
                    generatingPdf: _generatingPdf,
                    onGeneratePdf: () =>
                        _generatePdf(records, profileSnapshot.data),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DreContent extends StatelessWidget {
  final List<FinancialRecord> records;
  final DateTimeRange range;
  final double taxRate;
  final VoidCallback onPickRange;
  final Future<void> Function() onRefresh;
  final bool generatingPdf;
  final VoidCallback onGeneratePdf;

  const _DreContent({
    required this.records,
    required this.range,
    required this.taxRate,
    required this.onPickRange,
    required this.onRefresh,
    required this.generatingPdf,
    required this.onGeneratePdf,
  });

  static double? _variation(double current, double previous) {
    if (previous == 0) return current == 0 ? 0 : null;
    return ((current - previous) / previous.abs()) * 100;
  }

  static Future<void> _showRecords(
    BuildContext context,
    String title,
    List<FinancialRecord> records,
    NumberFormat currency,
  ) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              if (records.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Nenhum lançamento no período.')),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, index) {
                      final record = records[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(record.description,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          '${DateFormat('dd/MM/yyyy').format(record.date)} · ${record.category.toLowerCase()}',
                        ),
                        trailing: Text(currency.format(record.amount),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final end =
        DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
    final filtered = records
        .where((record) =>
            !record.date.isBefore(range.start) && !record.date.isAfter(end))
        .toList();
    final dre = DreSummary.fromRecords(filtered, taxRate: taxRate);
    final periodDays = end.difference(range.start).inDays + 1;
    final previousEnd = range.start.subtract(const Duration(seconds: 1));
    final previousStart = previousEnd.subtract(Duration(days: periodDays - 1));
    final previousRecords = records.where((record) =>
        !record.date.isBefore(previousStart) &&
        !record.date.isAfter(previousEnd));
    final previousDre =
        DreSummary.fromRecords(previousRecords, taxRate: taxRate);
    final paidRecords = filtered
        .where((record) =>
            record.type == FinancialRecordType.payment &&
            record.status == 'PAGO')
        .toList();
    final variableCosts = filtered
        .where((record) =>
            record.type == FinancialRecordType.expense &&
            record.dreClass == 'VARIABLE_COST')
        .toList();
    final operatingExpenses = filtered
        .where((record) =>
            record.type == FinancialRecordType.expense &&
            record.dreClass == 'OPERATING_EXPENSE')
        .toList();
    final taxes = filtered
        .where((record) =>
            record.type == FinancialRecordType.expense &&
            record.dreClass == 'TAX')
        .toList();
    final investments = filtered
        .where((record) =>
            record.type == FinancialRecordType.expense &&
            record.dreClass == 'INVESTMENT')
        .toList();
    final currency = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );
    final date = DateFormat('dd/MM/yyyy');
    final positive = dre.netResult >= 0;

    return RefreshIndicator(
      color: InkFlowColors.accentDark,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          Semantics(
            button: true,
            label: 'Selecionar período do DRE',
            child: InkWell(
              onTap: onPickRange,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: InkFlowColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined,
                        color: InkFlowColors.accentDark, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Período',
                              style: TextStyle(
                                  color: InkFlowColors.textMuted,
                                  fontSize: 11)),
                          Text(
                              '${date.format(range.start)} — ${date.format(range.end)}',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: InkFlowColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: generatingPdf ? null : onGeneratePdf,
            icon: generatingPdf
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Gerar DRE em PDF'),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: InkFlowColors.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RESULTADO DO PERÍODO',
                    style: TextStyle(
                        color: Color(0xFF9FA1AA),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
                const SizedBox(height: 8),
                Text(currency.format(dre.netResult),
                    style: TextStyle(
                        color: positive
                            ? InkFlowColors.accent
                            : const Color(0xFFFF777B),
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1)),
                const SizedBox(height: 8),
                Text('Margem líquida ${dre.netMargin.toStringAsFixed(1)}%',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ComparisonCard(
                  label: 'Receita',
                  value: dre.grossRevenue,
                  variation:
                      _variation(dre.grossRevenue, previousDre.grossRevenue),
                  currency: currency,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ComparisonCard(
                  label: 'Despesas',
                  value: dre.taxes + dre.serviceCosts + dre.operatingExpenses,
                  variation: _variation(
                    dre.taxes + dre.serviceCosts + dre.operatingExpenses,
                    previousDre.taxes +
                        previousDre.serviceCosts +
                        previousDre.operatingExpenses,
                  ),
                  currency: currency,
                  increaseIsPositive: false,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ComparisonCard(
                  label: 'Resultado',
                  value: dre.netResult,
                  variation: _variation(dre.netResult, previousDre.netResult),
                  currency: currency,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text('Resultado por mês',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          const Text(
            'Compare o que entrou, o que saiu e quanto sobrou.',
            style: TextStyle(color: InkFlowColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _MonthlyEvolution(
            records: filtered,
            range: range,
            taxRate: taxRate,
          ),
          const SizedBox(height: 22),
          const Text('Demonstrativo',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: InkFlowColors.border),
            ),
            child: Column(
              children: [
                _DreRow('Receita bruta', dre.grossRevenue, currency,
                    emphasis: true,
                    onTap: () => _showRecords(
                        context, 'Receita bruta', paidRecords, currency)),
                _DreRow(
                    '(-) Impostos${dre.taxesAreEstimated ? ' estimados' : ''}',
                    -dre.taxes,
                    currency,
                    note: taxRate > 0
                        ? 'Alíquota de ${taxRate.toStringAsFixed(2)}%'
                        : 'Defina a alíquota nos dados fiscais',
                    onTap: taxes.isEmpty
                        ? null
                        : () => _showRecords(
                            context, 'Impostos e taxas', taxes, currency)),
                _DreRow('(=) Receita líquida', dre.netRevenue, currency,
                    emphasis: true),
                _DreRow('(-) Custos variáveis', -dre.serviceCosts, currency,
                    onTap: () => _showRecords(
                        context, 'Custos variáveis', variableCosts, currency)),
                _DreRow('(=) Lucro bruto', dre.grossProfit, currency,
                    emphasis: true),
                _DreRow('(-) Despesas operacionais', -dre.operatingExpenses,
                    currency,
                    onTap: () => _showRecords(context, 'Despesas operacionais',
                        operatingExpenses, currency)),
                _DreRow('(=) Resultado líquido', dre.netResult, currency,
                    emphasis: true, last: true),
              ],
            ),
          ),
          if (dre.investments > 0) ...[
            const SizedBox(height: 10),
            _InvestmentCard(
              value: dre.investments,
              currency: currency,
              onTap: () =>
                  _showRecords(context, 'Investimentos', investments, currency),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF2DFC1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 19, color: Color(0xFF9A6400)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dre.pendingRevenue > 0
                        ? '${currency.format(dre.pendingRevenue)} pendentes não entram na receita. Este DRE é gerencial e não substitui a apuração contábil.'
                        : 'Este DRE usa apenas recebimentos pagos e não substitui a apuração contábil.',
                    style: const TextStyle(
                        color: Color(0xFF795411), fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DreRow extends StatelessWidget {
  final String label;
  final double value;
  final NumberFormat currency;
  final String? note;
  final bool emphasis;
  final bool last;
  final VoidCallback? onTap;

  const _DreRow(
    this.label,
    this.value,
    this.currency, {
    this.note,
    this.emphasis = false,
    this.last = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: emphasis ? const Color(0xFFF7F9F8) : null,
          border: last
              ? null
              : const Border(bottom: BorderSide(color: InkFlowColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: InkFlowColors.text,
                          fontSize: 13,
                          fontWeight:
                              emphasis ? FontWeight.w800 : FontWeight.w500)),
                  if (note != null) ...[
                    const SizedBox(height: 2),
                    Text(note!,
                        style: const TextStyle(
                            color: InkFlowColors.textMuted, fontSize: 10)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(currency.format(value),
                style: TextStyle(
                    color: value < 0 ? InkFlowColors.error : InkFlowColors.text,
                    fontSize: 13,
                    fontWeight: emphasis ? FontWeight.w800 : FontWeight.w600)),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: InkFlowColors.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final String label;
  final double value;
  final double? variation;
  final NumberFormat currency;
  final bool increaseIsPositive;

  const _ComparisonCard({
    required this.label,
    required this.value,
    required this.variation,
    required this.currency,
    this.increaseIsPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    final up = variation != null && variation! >= 0;
    final favorable = up == increaseIsPositive;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: InkFlowColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: InkFlowColors.textMuted, fontSize: 11)),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(currency.format(value),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 6),
          Text(
            variation == null
                ? 'Sem base anterior'
                : '${up ? '+' : ''}${variation!.toStringAsFixed(1)}% vs. período anterior',
            style: TextStyle(
              color: variation == null
                  ? InkFlowColors.textMuted
                  : favorable
                      ? InkFlowColors.success
                      : InkFlowColors.error,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvestmentCard extends StatelessWidget {
  final double value;
  final NumberFormat currency;
  final VoidCallback onTap;

  const _InvestmentCard({
    required this.value,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFF2EEFF),
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: onTap,
          leading: const Icon(Icons.savings_outlined, color: Color(0xFF6F56D9)),
          title: const Text('Investimentos',
              style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle:
              const Text('Exibidos separadamente do resultado gerencial.'),
          trailing: Text(currency.format(value),
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
}

class _MonthlyEvolution extends StatelessWidget {
  final List<FinancialRecord> records;
  final DateTimeRange range;
  final double taxRate;

  const _MonthlyEvolution({
    required this.records,
    required this.range,
    required this.taxRate,
  });

  @override
  Widget build(BuildContext context) {
    final values = dreMonthsInRange(range).map((month) {
      final monthlyRecords = records.where((record) =>
          record.date.year == month.year && record.date.month == month.month);
      final summary = DreSummary.fromRecords(monthlyRecords, taxRate: taxRate);
      return (month: month, summary: summary);
    }).toList();
    final currency = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: InkFlowColors.border),
      ),
      child: Column(
        children: values.asMap().entries.map((entry) {
          final summary = entry.value.summary;
          final expenses =
              summary.taxes + summary.serviceCosts + summary.operatingExpenses;
          return _MonthlyResultRow(
            month: entry.value.month,
            revenue: summary.grossRevenue,
            expenses: expenses,
            result: summary.netResult,
            currency: currency,
            last: entry.key == values.length - 1,
          );
        }).toList(),
      ),
    );
  }
}

@visibleForTesting
List<DateTime> dreMonthsInRange(DateTimeRange range) {
  final start = DateTime(range.start.year, range.start.month);
  final monthCount =
      (range.end.year - start.year) * 12 + range.end.month - start.month + 1;
  return List.generate(
    monthCount,
    (index) => DateTime(start.year, start.month + index),
  );
}

class _MonthlyResultRow extends StatelessWidget {
  final DateTime month;
  final double revenue;
  final double expenses;
  final double result;
  final NumberFormat currency;
  final bool last;

  const _MonthlyResultRow({
    required this.month,
    required this.revenue,
    required this.expenses,
    required this.result,
    required this.currency,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final resultColor =
        result < 0 ? InkFlowColors.error : InkFlowColors.success;
    final monthLabel = DateFormat('MMMM yyyy', 'pt_BR').format(month);
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: InkFlowColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${monthLabel[0].toUpperCase()}${monthLabel.substring(1)}',
                  style: const TextStyle(
                    color: InkFlowColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Saldo do mês',
                      style: TextStyle(
                          color: InkFlowColors.textMuted, fontSize: 10)),
                  const SizedBox(height: 2),
                  Text(
                    currency.format(result),
                    style: TextStyle(
                      color: resultColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _MonthlyAmount(
                  label: 'Entradas',
                  value: revenue,
                  color: InkFlowColors.accentDark,
                  currency: currency,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MonthlyAmount(
                  label: 'Saídas',
                  value: expenses,
                  color: InkFlowColors.error,
                  currency: currency,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthlyAmount extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final NumberFormat currency;

  const _MonthlyAmount({
    required this.label,
    required this.value,
    required this.color,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: InkFlowColors.textMuted, fontSize: 10)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      currency.format(value),
                      style: const TextStyle(
                        color: InkFlowColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
