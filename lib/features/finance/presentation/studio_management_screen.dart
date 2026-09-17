import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

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
                    await ReceiptService.previewReceipt(
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
                onDelete: (record) => _confirmDelete(context, ref, record),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    FinancialRecord record,
  ) async {
    final currency = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );
    final isExpense = record.type == FinancialRecordType.expense;
    const dangerColor = Color(0xFFE5484D);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEAEB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: dangerColor,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isExpense ? 'Excluir despesa?' : 'Excluir recebimento?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF161720),
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Confira os dados antes de continuar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF747782), fontSize: 13),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8E9EC)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isExpense
                            ? const Color(0xFFFFEAEB)
                            : const Color(0xFFE6F8F6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isExpense
                            ? Icons.north_east_rounded
                            : Icons.south_west_rounded,
                        color:
                            isExpense ? dangerColor : const Color(0xFF008B84),
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF20212A),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_friendlyLabel(record.category)} · '
                            '${DateFormat('dd/MM/yyyy').format(record.date)}',
                            style: const TextStyle(
                              color: Color(0xFF7B7E89),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currency.format(record.amount),
                      style: TextStyle(
                        color:
                            isExpense ? dangerColor : const Color(0xFF008B84),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4F4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: dangerColor, size: 19),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Essa ação é permanente e não poderá ser desfeita.',
                        style: TextStyle(
                          color: Color(0xFF8F383C),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF30323B),
                          side: const BorderSide(color: Color(0xFFDADCE1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: dangerColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Excluir'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(financeRepositoryProvider).deleteRecord(record);
      ref.invalidate(financialRecordsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Movimentação excluída.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        showErrorSnackBar(context, userFriendlyErrorMessage(error));
      }
    }
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
    final customerNameController = TextEditingController();
    final customerTaxIdController = TextEditingController();
    final customerEmailController = TextEditingController();
    final customerPhoneController = TextEditingController();
    final customerAddressController = TextEditingController();
    final cpfMask = MaskTextInputFormatter(mask: '###.###.###-##');
    final cnpjMask = MaskTextInputFormatter(mask: '##.###.###/####-##');
    final phoneMask = MaskTextInputFormatter(
      mask: '(##) #####-####',
      filter: {'#': RegExp(r'[0-9]')},
    );
    var option = isPayment ? 'PIX' : 'MATERIAIS';
    var paymentStatus = 'PAGO';
    var customerType = 'CPF';
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
            child: SingleChildScrollView(
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
                        customerNameController.text = appointment.clientName;
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
                    const SizedBox(height: 18),
                    const Text(
                      'Tomador do serviço',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: customerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome ou razão social',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Informe o tomador do serviço.'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: customerTaxIdController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        customerType == 'CPF' ? cpfMask : cnpjMask,
                      ],
                      decoration: InputDecoration(
                        labelText: '$customerType (opcional)',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        suffixIcon: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: customerType,
                            padding: const EdgeInsets.only(right: 12),
                            items: const [
                              DropdownMenuItem(
                                  value: 'CPF', child: Text('CPF')),
                              DropdownMenuItem(
                                  value: 'CNPJ', child: Text('CNPJ')),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              final digits = customerTaxIdController.text
                                  .replaceAll(RegExp(r'\D'), '');
                              setSheetState(() {
                                customerType = value;
                                customerTaxIdController.text = value == 'CPF'
                                    ? cpfMask.maskText(digits)
                                    : cnpjMask.maskText(digits);
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: customerEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail (opcional)',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: customerPhoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [phoneMask],
                      decoration: const InputDecoration(
                        labelText: 'Telefone (opcional)',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: customerAddressController,
                      decoration: const InputDecoration(
                        labelText: 'Endereço (opcional)',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
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
                            customerName: customerNameController.text.trim(),
                            customerTaxId: customerTaxIdController.text.trim(),
                            customerEmail: customerEmailController.text.trim(),
                            customerPhone: customerPhoneController.text.trim(),
                            customerAddress:
                                customerAddressController.text.trim(),
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
      ),
    );
    descriptionController.dispose();
    amountController.dispose();
    customerNameController.dispose();
    customerTaxIdController.dispose();
    customerEmailController.dispose();
    customerPhoneController.dispose();
    customerAddressController.dispose();
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
  final ValueChanged<FinancialRecord> onDelete;

  const _ManagementContent({
    required this.records,
    required this.onAddPayment,
    required this.onAddExpense,
    required this.onGenerateReceipt,
    required this.onDelete,
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
            title: 'Dados do estúdio e recibos',
            subtitle: 'Identificação e preferências dos documentos',
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
                  onDelete: () => onDelete(record),
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
  final VoidCallback onDelete;

  const _RecordTile({
    required this.record,
    required this.onReceipt,
    required this.onDelete,
  });

  Future<void> _showActions(BuildContext context) async {
    final income = record.type == FinancialRecordType.payment;
    final amount = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    ).format(record.amount);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9DCE1),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Opções da movimentação',
              style: TextStyle(
                color: Color(0xFF191B24),
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7F8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: (income
                              ? InkFlowColors.accent
                              : const Color(0xFFE35E61))
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      income
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      color: income
                          ? const Color(0xFF167D7B)
                          : const Color(0xFFE35E61),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${StudioManagementScreen._friendlyLabel(record.category)} · '
                          '${DateFormat('dd/MM/yyyy').format(record.date)}',
                          style: const TextStyle(
                            color: Color(0xFF767A86),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${income ? '+' : '-'} $amount',
                    style: TextStyle(
                      color: income
                          ? const Color(0xFF167D7B)
                          : const Color(0xFFE35E61),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (onReceipt != null) ...[
              _MovementAction(
                icon: Icons.receipt_long_outlined,
                iconColor: const Color(0xFF087F7A),
                iconBackground: const Color(0xFFE7F7F5),
                title: 'Visualizar documento',
                subtitle: 'Revisar o PDF antes de salvar ou imprimir',
                onTap: () {
                  Navigator.pop(sheetContext);
                  onReceipt?.call();
                },
              ),
              const SizedBox(height: 10),
            ],
            _MovementAction(
              icon: Icons.delete_outline_rounded,
              iconColor: const Color(0xFFE5484D),
              iconBackground: const Color(0xFFFFEAEB),
              title: 'Excluir movimentação',
              subtitle: 'Remover este lançamento permanentemente',
              danger: true,
              onTap: () {
                Navigator.pop(sheetContext);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final income = record.type == FinancialRecordType.payment;
    return ListTile(
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
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Opções da movimentação',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 20,
              color: Color(0xFF7B8491),
            ),
            onPressed: () => _showActions(context),
          ),
        ],
      ),
    );
  }
}

class _MovementAction extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final bool danger;
  final VoidCallback onTap;

  const _MovementAction({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: danger ? const Color(0xFFFFD7D9) : const Color(0xFFE6E8EC),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: danger
                              ? const Color(0xFFE5484D)
                              : const Color(0xFF20222B),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF7B7E89),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: danger
                      ? const Color(0xFFE5484D)
                      : const Color(0xFF90949E),
                ),
              ],
            ),
          ),
        ),
      );
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
