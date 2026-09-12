import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/finance/data/finance_repository.dart';
import 'package:inkflow/features/finance/domain/financial_record.dart';
import 'package:inkflow/features/finance/services/receipt_service.dart';
import 'package:inkflow/features/schedule/data/appointment_repository.dart';
import 'package:inkflow/features/schedule/domain/appointment.dart';

class StudioManagementScreen extends ConsumerWidget {
  const StudioManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(financialRecordsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: Column(
        children: [
          const AppHeader(
            title: 'Gestão do estúdio',
            showBack: true,
            backTo: '/home',
          ),
          Expanded(
            child: recordsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: InkFlowColors.accent),
              ),
              error: (error, _) => AsyncErrorView(
                error: error,
                customMessage: 'Não foi possível carregar sua gestão.',
                onRetry: () => ref.invalidate(financialRecordsProvider),
              ),
              data: (records) => _ManagementContent(
                records: records,
                onAddPayment: () => _showEntrySheet(context, ref, true),
                onAddExpense: () => _showEntrySheet(context, ref, false),
                onGenerateReceipt: (payment) async {
                  try {
                    final fiscal = await ref
                        .read(financeRepositoryProvider)
                        .getFiscalProfile();
                    await ReceiptService.shareReceipt(
                      payment: payment,
                      fiscalProfile: fiscal,
                    );
                  } catch (error) {
                    if (context.mounted) {
                      showErrorSnackBar(
                          context, userFriendlyErrorMessage(error));
                    }
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEntrySheet(
    BuildContext context,
    WidgetRef ref,
    bool isPayment,
  ) async {
    final appointments = isPayment
        ? await ref
            .read(appointmentRepositoryProvider)
            .listForUser(asArtist: true)
        : const <Appointment>[];
    if (!context.mounted) return;
    final formKey = GlobalKey<FormState>();
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    var option = isPayment ? 'PIX' : 'MATERIAIS';
    var paymentStatus = 'PAGO';
    String? appointmentId;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9DDE2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  isPayment ? 'Registrar recebimento' : 'Registrar despesa',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF202A3A),
                  ),
                ),
                const SizedBox(height: 18),
                if (isPayment && appointments.isNotEmpty) ...[
                  DropdownButtonFormField<String?>(
                    initialValue: appointmentId,
                    decoration: const InputDecoration(
                      labelText: 'Sessão vinculada (opcional)',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Lançamento avulso'),
                      ),
                      ...appointments.map((appointment) => DropdownMenuItem(
                            value: appointment.id,
                            child: Text(
                              '${appointment.clientName} · ${DateFormat('dd/MM').format(appointment.date)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                    ],
                    onChanged: (value) {
                      appointmentId = value;
                      if (value == null) return;
                      final appointment =
                          appointments.firstWhere((item) => item.id == value);
                      descriptionController.text =
                          'Sessão - ${appointment.clientName}';
                      if (appointment.price > 0) {
                        amountController.text = appointment.price
                            .toStringAsFixed(2)
                            .replaceAll('.', ',');
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Informe uma descrição.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Valor',
                    prefixText: 'R\$ ',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(
                      (value ?? '').replaceAll('.', '').replaceAll(',', '.'),
                    );
                    return parsed == null || parsed <= 0
                        ? 'Informe um valor válido.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: option,
                  decoration: InputDecoration(
                    labelText: isPayment ? 'Forma de pagamento' : 'Categoria',
                    prefixIcon: Icon(isPayment
                        ? Icons.account_balance_wallet_outlined
                        : Icons.category_outlined),
                  ),
                  items: (isPayment
                          ? [
                              'PIX',
                              'DINHEIRO',
                              'CARTAO',
                              'TRANSFERENCIA',
                              'OUTRO'
                            ]
                          : [
                              'MATERIAIS',
                              'ALUGUEL',
                              'MARKETING',
                              'EQUIPAMENTOS',
                              'OUTROS'
                            ])
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(_friendlyLabel(value)),
                          ))
                      .toList(),
                  onChanged: (value) => option = value ?? option,
                ),
                if (isPayment) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: paymentStatus,
                    decoration: const InputDecoration(
                      labelText: 'Situação',
                      prefixIcon: Icon(Icons.task_alt_outlined),
                    ),
                    items: ['PAGO', 'PENDENTE', 'PARCIAL']
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(_friendlyLabel(value)),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        paymentStatus = value ?? paymentStatus,
                  ),
                ],
                const SizedBox(height: 20),
                InkButton(
                  label: isPayment ? 'Salvar recebimento' : 'Salvar despesa',
                  isLoading: saving,
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    setSheetState(() => saving = true);
                    final amount = double.parse(amountController.text
                        .replaceAll('.', '')
                        .replaceAll(',', '.'));
                    try {
                      final repository = ref.read(financeRepositoryProvider);
                      if (isPayment) {
                        await repository.addPayment(
                          description: descriptionController.text.trim(),
                          amount: amount,
                          method: option,
                          status: paymentStatus,
                          appointmentId: appointmentId,
                        );
                      } else {
                        await repository.addExpense(
                          description: descriptionController.text.trim(),
                          amount: amount,
                          category: option,
                          date: DateTime.now(),
                        );
                      }
                      ref.invalidate(financialRecordsProvider);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    } catch (error) {
                      if (sheetContext.mounted) {
                        showErrorSnackBar(
                          sheetContext,
                          userFriendlyErrorMessage(error),
                        );
                        setSheetState(() => saving = false);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    descriptionController.dispose();
    amountController.dispose();
  }

  static String _friendlyLabel(String value) => value
      .toLowerCase()
      .split('_')
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

class _ManagementContent extends StatelessWidget {
  final List<FinancialRecord> records;
  final VoidCallback onAddPayment;
  final VoidCallback onAddExpense;
  final ValueChanged<FinancialRecord> onGenerateReceipt;

  const _ManagementContent({
    required this.records,
    required this.onAddPayment,
    required this.onAddExpense,
    required this.onGenerateReceipt,
  });

  @override
  Widget build(BuildContext context) {
    final received = records
        .where((item) =>
            item.type == FinancialRecordType.payment && item.status == 'PAGO')
        .fold<double>(0, (sum, item) => sum + item.amount);
    final pending = records
        .where((item) =>
            item.type == FinancialRecordType.payment &&
            (item.status == 'PENDENTE' || item.status == 'PARCIAL'))
        .fold<double>(0, (sum, item) => sum + item.amount);
    final expenses = records
        .where((item) => item.type == FinancialRecordType.expense)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final summary = FinancialSummary(
      received: received,
      pending: pending,
      expenses: expenses,
    );

    return RefreshIndicator(
      color: InkFlowColors.accent,
      onRefresh: () async => ProviderScope.containerOf(context)
          .refresh(financialRecordsProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          _BalanceCard(summary: summary),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.south_west_rounded,
                  label: 'Recebimento',
                  color: const Color(0xFF14847E),
                  onTap: onAddPayment,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.north_east_rounded,
                  label: 'Despesa',
                  color: const Color(0xFFE35E61),
                  onTap: onAddExpense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _ManagementLink(
            icon: Icons.receipt_long_outlined,
            title: 'Fiscal e recibos',
            subtitle: 'Dados fiscais e documentos do estúdio',
            onTap: () => context.push('/fiscal-settings'),
          ),
          const SizedBox(height: 10),
          _ManagementLink(
            icon: Icons.insights_outlined,
            title: 'Relatórios e indicadores',
            subtitle: 'Acompanhe o desempenho por período',
            onTap: () => context.push('/dashboard'),
          ),
          const SizedBox(height: 26),
          const Text('Movimentações recentes',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202A3A))),
          const SizedBox(height: 10),
          if (records.isEmpty)
            const _EmptyRecords()
          else
            ...records.take(20).map((record) => _RecordTile(
                  record: record,
                  onReceipt: record.type == FinancialRecordType.payment &&
                          record.status == 'PAGO'
                      ? () => onGenerateReceipt(record)
                      : null,
                )),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final FinancialSummary summary;

  const _BalanceCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final currency =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111218), Color(0xFF243437)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resultado atual',
              style: TextStyle(color: Color(0xFFACB4B8), fontSize: 12)),
          const SizedBox(height: 5),
          FittedBox(
            child: Text(currency.format(summary.net),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _BalanceValue('Recebido', summary.received, InkFlowColors.accent),
              _BalanceValue(
                  'Pendente', summary.pending, const Color(0xFFFFB84D)),
              _BalanceValue(
                  'Despesas', summary.expenses, const Color(0xFFFF7B7E)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceValue extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _BalanceValue(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Color(0xFF919A9E), fontSize: 10)),
            const SizedBox(height: 3),
            FittedBox(
              child: Text(
                NumberFormat.compactCurrency(locale: 'pt_BR', symbol: 'R\$')
                    .format(value),
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E8EC)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
}

class _ManagementLink extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ManagementLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        child: ListTile(
          onTap: onTap,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          leading: Icon(icon, color: const Color(0xFF167D7B)),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );
}

class _RecordTile extends StatelessWidget {
  final FinancialRecord record;
  final VoidCallback? onReceipt;

  const _RecordTile({required this.record, required this.onReceipt});

  @override
  Widget build(BuildContext context) {
    final income = record.type == FinancialRecordType.payment;
    return ListTile(
      onTap: onReceipt,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor:
            (income ? InkFlowColors.accent : const Color(0xFFE35E61))
                .withValues(alpha: 0.12),
        child: Icon(
            income ? Icons.south_west_rounded : Icons.north_east_rounded,
            color: income ? const Color(0xFF167D7B) : const Color(0xFFE35E61)),
      ),
      title: Text(record.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
          '${StudioManagementScreen._friendlyLabel(record.category)} · ${DateFormat('dd/MM/yyyy').format(record.date)}',
          style: const TextStyle(fontSize: 11)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${income ? '+' : '-'} ${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2).format(record.amount)}',
            style: TextStyle(
              color: income ? const Color(0xFF167D7B) : const Color(0xFFE35E61),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          if (onReceipt != null) ...[
            const SizedBox(width: 5),
            const Icon(Icons.receipt_long_outlined,
                size: 18, color: Color(0xFF7B8491)),
          ],
        ],
      ),
    );
  }
}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 34, color: Color(0xFF9AA2AE)),
            SizedBox(height: 10),
            Text('Nenhuma movimentação registrada',
                style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Use os botões acima para começar.',
                style: TextStyle(fontSize: 12, color: Color(0xFF7B8491))),
          ],
        ),
      );
}
