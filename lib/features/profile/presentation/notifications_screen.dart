import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/utils/time_slot.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/schedule/domain/appointment.dart';
import 'package:inkflow/features/schedule/presentation/schedule_screen.dart';

enum NotificationKind { newBooking, startingSoon, startingNow }

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final NotificationKind kind;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.kind,
  });
}

/// Avisos derivados da agenda real.
///
/// Não existe tabela de notificações: as regras (sessão marcada, faltando 30
/// minutos, hora de começar) são calculadas sobre os agendamentos já
/// carregados. A tela anterior usava três clientes fixos no código.
List<AppNotification> buildNotifications(
  List<Appointment> appointments, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final notifications = <AppNotification>[];

  for (final appointment in appointments) {
    final startMinutes = TimeSlot.parseMinutes(appointment.startTime);
    if (startMinutes == null) continue;

    final startsAt = appointment.date.add(Duration(minutes: startMinutes));
    final untilStart = startsAt.difference(reference);

    notifications.add(
      AppNotification(
        id: '${appointment.id}_booked',
        title: 'Sessão agendada',
        message: '${appointment.clientName} — '
            '${DateFormat('dd/MM').format(appointment.date)} às '
            '${appointment.startTime}.',
        createdAt: startsAt,
        kind: NotificationKind.newBooking,
      ),
    );

    if (untilStart.inMinutes > 0 && untilStart.inMinutes <= 30) {
      notifications.add(
        AppNotification(
          id: '${appointment.id}_soon',
          title: 'Faltam ${untilStart.inMinutes} minutos',
          message: 'Prepare o estúdio: a sessão de '
              '${appointment.clientName} está quase começando.',
          createdAt: reference,
          kind: NotificationKind.startingSoon,
        ),
      );
    }

    if (untilStart.inMinutes <= 0 && untilStart.inMinutes > -120) {
      notifications.add(
        AppNotification(
          id: '${appointment.id}_now',
          title: 'Hora da sessão',
          message: 'A sessão de ${appointment.clientName} começou.',
          createdAt: startsAt,
          kind: NotificationKind.startingNow,
        ),
      );
    }
  }

  notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return notifications;
}

final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final appointments = await ref.watch(scheduleProvider.future);
  return buildNotifications(appointments);
});

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// Marcações de leitura mantidas apenas nesta sessão — não há coluna de
  /// `read_at` no banco. O timer da versão anterior recriava a lista a cada
  /// minuto e apagava esse estado.
  final _readIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: InkFlowColors.background,
      appBar: AppBar(
        backgroundColor: InkFlowColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          tooltip: 'Voltar',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text(
          'Notificações',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Colors.white),
            tooltip: 'Marcar todas como lidas',
            onPressed: () {
              final all = notificationsAsync.value ?? const <AppNotification>[];
              setState(() => _readIds.addAll(all.map((n) => n.id)));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const UnderDevelopmentBanner(
            message: 'Avisos calculados no aparelho a partir da agenda. '
                'Push e histórico de leitura ainda não existem.',
          ),
          Expanded(
            child: notificationsAsync.when(
              loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: InkFlowColors.accent)),
              error: (e, _) => AsyncErrorView(
                error: e,
                customMessage: 'Erro ao carregar notificações.',
                onRetry: () => ref.invalidate(scheduleProvider),
              ),
              data: (notifications) {
                if (notifications.isEmpty) return const _EmptyState();

                return ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _NotificationTile(
                      notification: notification,
                      isRead: _readIds.contains(notification.id),
                      onTap: () =>
                          setState(() => _readIds.add(notification.id)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Sem avisos no momento',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF374151))),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final bool isRead;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.isRead,
    required this.onTap,
  });

  static const _icons = {
    NotificationKind.newBooking: Icons.calendar_month_outlined,
    NotificationKind.startingSoon: Icons.access_time,
    NotificationKind.startingNow: Icons.play_circle_outline,
  };

  static const _colors = {
    NotificationKind.newBooking: Color(0xFF6B7280),
    NotificationKind.startingSoon: InkFlowColors.warning,
    NotificationKind.startingNow: InkFlowColors.success,
  };

  String _elapsed() {
    final difference = DateTime.now().difference(notification.createdAt);
    if (difference.isNegative) {
      return DateFormat('dd/MM HH:mm').format(notification.createdAt);
    }
    if (difference.inMinutes < 1) return 'Agora';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min atrás';
    if (difference.inHours < 24) return '${difference.inHours}h atrás';
    return '${difference.inDays} dias atrás';
  }

  @override
  Widget build(BuildContext context) {
    final color = _colors[notification.kind]!;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        color: isRead
            ? Colors.white
            : const Color(0xFFF3F4F6).withValues(alpha: 0.5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_icons[notification.kind], size: 24, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                isRead ? FontWeight.w500 : FontWeight.bold,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      Text(
                        _elapsed(),
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF4B5563), height: 1.4),
                  ),
                ],
              ),
            ),
            if (!isRead) ...[
              const SizedBox(width: 12),
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: InkFlowColors.primary, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
