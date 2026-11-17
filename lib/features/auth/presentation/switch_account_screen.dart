import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inkflow/core/data/supabase_providers.dart';
import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/features/auth/data/saved_accounts.dart';
import 'package:inkflow/features/auth/presentation/register_screen.dart';
import 'package:inkflow/features/profile/providers/profile_provider.dart';
import 'package:inkflow/features/schedule/services/appointment_notification_service.dart';

class SwitchAccountScreen extends ConsumerStatefulWidget {
  const SwitchAccountScreen({super.key}) : loginEmail = null;

  const SwitchAccountScreen._login(this.loginEmail);

  final String? loginEmail;

  @override
  ConsumerState<SwitchAccountScreen> createState() =>
      _SwitchAccountScreenState();
}

class _SwitchAccountScreenState extends ConsumerState<SwitchAccountScreen> {
  late final _accounts = SavedAccounts(ref.read(supabaseClientProvider));
  late var _saved = _accounts.list();
  bool _busy = false;
  late String _email = widget.loginEmail ?? '';
  String _password = '';

  Future<void> _chooseAccountKind() async {
    final create = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: InkFlowColors.background,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 16),
                child: Text('Adicionar conta',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                tileColor: Colors.white,
                leading:
                    const Icon(Icons.login, color: InkFlowColors.accentDark),
                title: const Text('Usar uma conta existente'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(sheetContext, false),
              ),
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                tileColor: Colors.white,
                leading: const Icon(Icons.person_add_alt_outlined,
                    color: InkFlowColors.accentDark),
                title: const Text('Criar uma nova conta'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(sheetContext, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || create == null) return;
    final navigator = Navigator.of(context);
    var email = '';
    if (create) {
      final registeredEmail = await navigator.push<String>(
        MaterialPageRoute(
          builder: (_) => const RegisterScreen(addingAccount: true),
        ),
      );
      if (!mounted || registeredEmail == null) return;
      email = registeredEmail;
    }
    await navigator.push<void>(MaterialPageRoute(
      builder: (_) => SwitchAccountScreen._login(email),
    ));
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, userFriendlyErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reminders = ref.watch(appointmentNotificationServiceProvider);
    if (widget.loginEmail != null) {
      return PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: AppBar(title: const Text('Entrar em outra conta')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (widget.loginEmail!.isNotEmpty) ...[
                const Text(
                    'Confirme seu e-mail antes de entrar na nova conta.'),
                const SizedBox(height: 16),
              ],
              TextFormField(
                initialValue: widget.loginEmail,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail'),
                onChanged: (value) => setState(() => _email = value),
              ),
              const SizedBox(height: 12),
              TextField(
                enabled: !_busy,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Senha'),
                onChanged: (value) => setState(() => _password = value),
                onSubmitted: (_) => _submit(reminders),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _canSubmit ? () => _submit(reminders) : null,
                child: const Text('Entrar nesta conta'),
              ),
              if (_busy) const LinearProgressIndicator(),
            ],
          ),
        ),
      );
    }
    final activeEmail = _accounts.client.auth.currentUser?.email ?? 'InkFlow';
    final activeName = ref.watch(userProfileProvider).value?.name.trim();
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: InkFlowColors.background,
        appBar: AppBar(
          title: const Text('Trocar de conta'),
          backgroundColor: InkFlowColors.background,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Material(
              color: InkFlowColors.primary,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: InkFlowColors.primarySoft,
                      foregroundColor: InkFlowColors.accent,
                      child: Icon(Icons.person_outline),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Conta ativa',
                              style: TextStyle(
                                  color: InkFlowColors.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          if (activeName != null && activeName.isNotEmpty)
                            Text(
                              activeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            ),
                          Tooltip(
                            message: activeEmail,
                            child: Text(
                              activeEmail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle_rounded,
                        color: InkFlowColors.accent, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FutureBuilder(
              future: _saved,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _saved = _accounts.list()),
                    child: const Text('Tentar carregar as contas novamente'),
                  );
                }
                final saved = snapshot.data;
                if (saved == null) return const LinearProgressIndicator();
                if (saved.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                      child: Text('Contas salvas',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    for (final account in saved)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: InkFlowColors.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            enabled: !_busy,
                            contentPadding: const EdgeInsetsDirectional.only(
                                start: 12, end: 4),
                            horizontalTitleGap: 10,
                            leading: const CircleAvatar(
                              backgroundColor: InkFlowColors.background,
                              foregroundColor: InkFlowColors.accentDark,
                              child: Icon(Icons.person_outline),
                            ),
                            title: Text(
                              account.name?.isNotEmpty == true
                                  ? account.name!
                                  : 'Conta InkFlow',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Tooltip(
                              message: account.email,
                              child: Text(
                                account.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: InkFlowColors.textMuted,
                                    fontSize: 12),
                              ),
                            ),
                            onTap: () => _run(() => _accounts.switchTo(
                                  account.id,
                                  clearReminders: reminders.clear,
                                )),
                            trailing: PopupMenuButton<bool>(
                              tooltip: 'Opções da conta',
                              enabled: !_busy,
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: true,
                                    child: Text('Remover do aparelho')),
                              ],
                              onSelected: (_) => _run(() async {
                                await _accounts.forget(account.id);
                                if (mounted) {
                                  setState(() => _saved = _accounts.list());
                                }
                              }),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: InkFlowColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _busy ? null : _chooseAccountKind,
              icon: const Icon(Icons.person_add_alt_outlined),
              label: const Text('Adicionar conta'),
            ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  bool get _canSubmit =>
      !_busy && _email.trim().isNotEmpty && _password.isNotEmpty;

  void _submit(AppointmentNotificationService reminders) {
    if (_canSubmit) {
      _run(() =>
          _accounts.add(_email, _password, clearReminders: reminders.clear));
    }
  }
}
