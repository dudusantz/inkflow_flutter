import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/chat/data/chat_repository.dart';
import 'package:inkflow/features/chat/domain/chat_message.dart';
import 'package:inkflow/features/profile/providers/profile_provider.dart';
import 'package:inkflow/features/schedule/data/appointment_repository.dart';
import 'package:inkflow/features/schedule/presentation/schedule_screen.dart';

final chatStreamProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, contactId) {
  return ref.watch(chatRepositoryProvider).watchConversation(contactId);
});

final chatContactProvider =
    FutureProvider.autoDispose.family<ChatContact?, String>((ref, contactId) {
  return ref.watch(chatRepositoryProvider).fetchContact(contactId);
});

class ChatScreen extends ConsumerStatefulWidget {
  /// Id do outro participante da conversa.
  final String contactId;

  const ChatScreen({super.key, required this.contactId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();
  bool _isSending = false;
  String? _updatingProposalId;
  final _localProposalStatuses = <String, String>{};
  bool _isRecording = false;
  bool _isRecordingPaused = false;
  int _recordingSeconds = 0;
  int _recordingMilliseconds = 0;
  final Stopwatch _recordingStopwatch = Stopwatch();
  Timer? _recordingTimer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  final List<double> _recordingLevels = List.filled(18, .08, growable: true);

  @override
  void dispose() {
    _messageController.dispose();
    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source, {required bool video}) async {
    Navigator.pop(context);
    final file = video
        ? await _picker.pickVideo(
            source: source,
            maxDuration: const Duration(minutes: 2),
          )
        : await _picker.pickImage(
            source: source,
            imageQuality: 82,
            maxWidth: 1920,
          );
    if (file == null) return;
    final confirmed = await _confirmAttachment(
      file: file,
      type: video ? 'video' : 'image',
    );
    if (!confirmed) return;
    await _uploadAttachment(
      file: file,
      type: video ? 'video' : 'image',
      contentType: file.mimeType ?? (video ? 'video/mp4' : 'image/jpeg'),
    );
  }

  Future<bool> _confirmAttachment({
    required XFile file,
    required String type,
    int? durationSeconds,
  }) async {
    if (!mounted) return false;
    final imageBytes = type == 'image' ? await file.readAsBytes() : null;
    if (!mounted) return false;
    final duration = durationSeconds == null
        ? null
        : '${(durationSeconds ~/ 60).toString().padLeft(2, '0')}:'
            '${(durationSeconds % 60).toString().padLeft(2, '0')}';

    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Text(type == 'audio' ? 'Enviar áudio?' : 'Enviar anexo?'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: type == 'image'
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(
                        imageBytes!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined, size: 72),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          type == 'audio'
                              ? Icons.graphic_eq_rounded
                              : Icons.videocam_rounded,
                          color: InkFlowColors.accentDark,
                          size: 64,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          duration == null ? file.name : 'Duração $duration',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: InkFlowColors.accentDark,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Enviar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _uploadAttachment({
    required XFile file,
    required String type,
    required String contentType,
    int? durationSeconds,
  }) async {
    setState(() => _isSending = true);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 50 * 1024 * 1024) {
        throw Exception('Arquivo maior que 50 MB.');
      }
      await ref.read(chatRepositoryProvider).sendAttachment(
            receiverId: widget.contactId,
            bytes: bytes,
            type: type,
            fileName: file.name,
            contentType: contentType,
            durationSeconds: durationSeconds,
          );
    } catch (error) {
      if (mounted) {
        final message = type == 'audio'
            ? 'Falha ao enviar áudio: $error'
            : userFriendlyErrorMessage(error);
        showErrorSnackBar(context, message);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) return;

      if (!await _recorder.hasPermission()) {
        if (mounted) {
          showErrorSnackBar(
              context, 'Permita o acesso ao microfone para gravar.');
        }
        return;
      }

      if (kIsWeb) {
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.opus,
            numChannels: 1,
          ),
          path: 'inkflow_${DateTime.now().microsecondsSinceEpoch}.webm',
        );
      } else {
        final fileName = 'inkflow_${DateTime.now().microsecondsSinceEpoch}.m4a';
        final path = '${Directory.systemTemp.path}/$fileName';
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
          path: path,
        );
      }
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _isRecordingPaused = false;
        _recordingSeconds = 0;
        _recordingMilliseconds = 0;
      });
      _recordingStopwatch
        ..reset()
        ..start();
      _startRecordingTimer();
      if (!kIsWeb) {
        await _amplitudeSubscription?.cancel();
        _amplitudeSubscription = _recorder
            .onAmplitudeChanged(const Duration(milliseconds: 120))
            .listen(
          (amplitude) {
            if (!mounted || _isRecordingPaused) return;
            final normalized = ((amplitude.current + 55) / 55).clamp(0.08, 1.0);
            setState(() {
              _recordingLevels
                ..removeAt(0)
                ..add(normalized);
            });
          },
          onError: (_) {
            // Alguns dispositivos não oferecem medição de amplitude. A
            // gravação continua normalmente sem derrubar a tela.
          },
        );
      }
    } catch (error) {
      _recordingTimer?.cancel();
      if (mounted) {
        setState(() => _isRecording = false);
        showErrorSnackBar(
          context,
          'Não foi possível usar o microfone: $error',
        );
      }
    }
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _recordingMilliseconds = _recordingStopwatch.elapsedMilliseconds;
        _recordingSeconds = _recordingStopwatch.elapsed.inSeconds;
        if (kIsWeb && !_isRecordingPaused) {
          final nextLevel =
              .18 + (((_recordingMilliseconds ~/ 100 * 37) % 72) / 100.0);
          _recordingLevels
            ..removeAt(0)
            ..add(nextLevel);
        }
      });
    });
  }

  Future<void> _toggleRecordingPause() async {
    try {
      if (_isRecordingPaused) {
        await _recorder.resume();
        _recordingStopwatch.start();
        _startRecordingTimer();
      } else {
        await _recorder.pause();
        _recordingStopwatch.stop();
        _recordingTimer?.cancel();
      }
      if (mounted) {
        setState(() => _isRecordingPaused = !_isRecordingPaused);
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, userFriendlyErrorMessage(error));
      }
    }
  }

  Future<void> _finishRecording({required bool send}) async {
    if (_isSending) return;
    _recordingTimer?.cancel();
    _recordingStopwatch.stop();
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    try {
      final path = send ? await _recorder.stop() : null;
      if (!send) await _recorder.cancel();
      final seconds = (_recordingMilliseconds / 1000).ceil();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isRecordingPaused = false;
          _recordingSeconds = 0;
          _recordingMilliseconds = 0;
          _recordingLevels
            ..clear()
            ..addAll(List.filled(18, .08, growable: true));
        });
      }
      if (send && path != null) {
        await _uploadAttachment(
          file: XFile(
            path,
            mimeType: kIsWeb ? 'audio/webm' : 'audio/mp4',
            name: kIsWeb
                ? 'audio_${DateTime.now().millisecondsSinceEpoch}.webm'
                : null,
          ),
          type: 'audio',
          // O bucket atual aceita audio/mp4. No navegador os bytes são WebM;
          // o tipo será ampliado na próxima migração do Storage.
          contentType: 'audio/mp4',
          durationSeconds: seconds,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isRecordingPaused = false;
        });
        showErrorSnackBar(context, userFriendlyErrorMessage(error));
      }
    }
  }

  void _showAttachmentSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enviar anexo',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _AttachmentAction(
                    icon: Icons.photo_library_outlined,
                    label: 'Galeria',
                    color: InkFlowColors.accentDark,
                    onTap: () => _pickMedia(ImageSource.gallery, video: false),
                  ),
                  _AttachmentAction(
                    icon: Icons.camera_alt_outlined,
                    label: 'Câmera',
                    color: const Color(0xFF7C3AED),
                    onTap: () => _pickMedia(ImageSource.camera, video: false),
                  ),
                  _AttachmentAction(
                    icon: Icons.videocam_outlined,
                    label: 'Vídeo',
                    color: const Color(0xFFEA580C),
                    onTap: () => _pickMedia(ImageSource.gallery, video: true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await ref.read(chatRepositoryProvider).sendMessage(
            receiverId: widget.contactId,
            content: text,
          );
    } catch (e) {
      if (!mounted) return;
      // Devolve o texto ao campo para o usuário não perder o que escreveu.
      _messageController.text = text;
      showErrorSnackBar(context, userFriendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _showProposalForm() async {
    final formKey = GlobalKey<FormState>();
    final serviceController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    DateTime? scheduledDate;
    TimeOfDay? scheduledTime;
    var durationMinutes = 60;
    var showScheduleErrors = false;
    var scheduleInPast = false;
    var sending = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: InkFlowColors.background,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              22, 4, 22, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: InkFlowColors.accent.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.request_quote_outlined,
                          color: InkFlowColors.accentDark),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nova proposta',
                              style: TextStyle(
                                  color: InkFlowColors.text,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)),
                          SizedBox(height: 2),
                          Text('Combine os detalhes com o cliente',
                              style: TextStyle(
                                  color: InkFlowColors.textMuted,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Serviço *',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: serviceController,
                  decoration: const InputDecoration(
                    hintText: 'Ex.: tatuagem no antebraço',
                    prefixIcon: Icon(Icons.design_services_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Informe o serviço.'
                      : null,
                ),
                const SizedBox(height: 18),
                const Text('Valor combinado *',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: '0,00',
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(left: 14, right: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.payments_outlined),
                          SizedBox(width: 10),
                          Text('R\$'),
                        ],
                      ),
                    ),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(
                        (value ?? '').replaceAll('.', '').replaceAll(',', '.'));
                    return amount == null || amount <= 0
                        ? 'Informe um valor válido.'
                        : null;
                  },
                ),
                const SizedBox(height: 18),
                const Text('Data *',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) {
                      setSheetState(() {
                        scheduledDate = picked;
                        scheduleInPast = false;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ).copyWith(
                      errorText: showScheduleErrors && scheduledDate == null
                          ? 'Selecione uma data.'
                          : null,
                    ),
                    child: Text(
                      scheduledDate == null
                          ? 'Escolher data'
                          : DateFormat('dd/MM/yyyy').format(scheduledDate!),
                      style: TextStyle(
                        color: scheduledDate == null
                            ? InkFlowColors.textMuted
                            : InkFlowColors.text,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Horário *',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: scheduledTime ?? TimeOfDay.now(),
                    );
                    if (picked != null) {
                      setSheetState(() {
                        scheduledTime = picked;
                        scheduleInPast = false;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.access_time_outlined),
                    ).copyWith(
                      errorText: showScheduleErrors && scheduledTime == null
                          ? 'Selecione um horário.'
                          : scheduleInPast
                              ? 'Escolha uma data e horário futuros.'
                              : null,
                    ),
                    child: Text(
                      scheduledTime == null
                          ? 'Escolher horário'
                          : '${scheduledTime!.hour.toString().padLeft(2, '0')}:${scheduledTime!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: scheduledTime == null
                            ? InkFlowColors.textMuted
                            : InkFlowColors.text,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Duração estimada *',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: durationMinutes,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.timelapse_rounded),
                  ),
                  items: const [30, 60, 90, 120, 180, 240]
                      .map((minutes) => DropdownMenuItem(
                            value: minutes,
                            child: Text(minutes < 60
                                ? '$minutes min'
                                : minutes % 60 == 0
                                    ? '${minutes ~/ 60} h'
                                    : '${minutes ~/ 60} h ${minutes % 60} min'),
                          ))
                      .toList(),
                  onChanged: sending
                      ? null
                      : (value) => setSheetState(
                            () => durationMinutes = value ?? 60,
                          ),
                ),
                const SizedBox(height: 18),
                const Text('Observações',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Inclua detalhes importantes (opcional)',
                  ),
                ),
                const SizedBox(height: 24),
                InkButton(
                  label: 'Enviar proposta',
                  isLoading: sending,
                  onPressed: () async {
                    final validFields = formKey.currentState!.validate();
                    setSheetState(() => showScheduleErrors = true);
                    if (!validFields ||
                        scheduledDate == null ||
                        scheduledTime == null) {
                      return;
                    }
                    final isFuture = isFutureProposalSchedule(
                      scheduledDate!,
                      scheduledTime!.hour,
                      scheduledTime!.minute,
                      DateTime.now(),
                    );
                    setSheetState(() => scheduleInPast = !isFuture);
                    if (!isFuture) {
                      return;
                    }
                    final startsAt = DateTime(
                      scheduledDate!.year,
                      scheduledDate!.month,
                      scheduledDate!.day,
                      scheduledTime!.hour,
                      scheduledTime!.minute,
                    );
                    setSheetState(() => sending = true);
                    final amount = double.parse(amountController.text
                        .replaceAll('.', '')
                        .replaceAll(',', '.'));
                    try {
                      await ref.read(chatRepositoryProvider).sendMessage(
                            receiverId: widget.contactId,
                            content: ChatMessage.encodeProposal({
                              'service': serviceController.text.trim(),
                              'amount': amount,
                              'date': scheduledDate!.toIso8601String(),
                              'time':
                                  '${scheduledTime!.hour.toString().padLeft(2, '0')}:${scheduledTime!.minute.toString().padLeft(2, '0')}',
                              'startsAt': startsAt.toUtc().toIso8601String(),
                              'durationMinutes': durationMinutes,
                              'notes': notesController.text.trim(),
                            }),
                          );
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    } catch (error) {
                      if (sheetContext.mounted) {
                        showErrorSnackBar(
                            sheetContext, userFriendlyErrorMessage(error));
                        setSheetState(() => sending = false);
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
    serviceController.dispose();
    amountController.dispose();
    notesController.dispose();
  }

  Future<void> _openAnamnesis(ChatMessage message) async {
    final accepted = await context.push<bool>(
      '/anamnesis?proposalId=${Uri.encodeQueryComponent(message.id)}',
    );
    if (accepted == true && mounted) {
      setState(() =>
          _localProposalStatuses[message.id] = ChatMessage.proposalAccepted);
    }
  }

  void _openSavedAnamnesis(ChatMessage message, String clientName) {
    showSavedAnamnesisSheet(
      context,
      clientName: clientName,
      anamnesis: ref
          .read(appointmentRepositoryProvider)
          .anamnesisForProposal(message.id),
    );
  }

  Future<void> _updateProposalStatus(ChatMessage message, String status) async {
    final isCancellation = status == ChatMessage.proposalCancelled;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: InkFlowColors.background,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isCancellation ? 'Cancelar proposta?' : 'Recusar proposta?',
                  style: const TextStyle(
                      color: InkFlowColors.text,
                      fontSize: 21,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                isCancellation
                    ? 'Ela continuará no histórico da conversa, identificada como cancelada.'
                    : 'O tatuador será informado e a proposta continuará no histórico.',
                style: const TextStyle(
                    color: InkFlowColors.textMuted, fontSize: 14, height: 1.45),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: InkFlowColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                    isCancellation ? 'Cancelar proposta' : 'Recusar proposta'),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  style: TextButton.styleFrom(
                    foregroundColor: InkFlowColors.textMuted,
                  ),
                  child: Text(isCancellation ? 'Manter proposta' : 'Voltar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted || _updatingProposalId != null) {
      return;
    }

    setState(() => _updatingProposalId = message.id);
    try {
      await ref.read(chatRepositoryProvider).sendMessage(
            receiverId: widget.contactId,
            content: isCancellation
                ? ChatMessage.encodeProposalCancellation(message.id)
                : ChatMessage.encodeProposalResponse(
                    message.id,
                    accepted: false,
                  ),
          );
      if (mounted) {
        setState(() => _localProposalStatuses[message.id] = status);
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, userFriendlyErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _updatingProposalId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArtist = ref.watch(isArtistProvider);
    final messagesAsync = ref.watch(chatStreamProvider(widget.contactId));
    final contact = ref.watch(chatContactProvider(widget.contactId)).value;

    return Scaffold(
      backgroundColor: InkFlowColors.background,
      appBar: _buildAppBar(contact),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(
                    child:
                        CircularProgressIndicator(color: InkFlowColors.accent)),
                error: (e, s) => AsyncErrorView(
                  error: e,
                  customMessage: 'Erro ao carregar a conversa.',
                  onRetry: () =>
                      ref.invalidate(chatStreamProvider(widget.contactId)),
                ),
                data: (messages) {
                  final proposals = <String, ChatMessage>{
                    for (final message in messages)
                      if (message.isProposal) message.id: message,
                  };
                  final proposalStatuses = <String, String>{};
                  for (final event in messages) {
                    final proposalId = event.proposalEventId;
                    final proposal = proposals[proposalId];
                    final status = event.proposalEventStatus;
                    if (proposalId == null ||
                        proposal == null ||
                        status == null ||
                        proposalStatuses.containsKey(proposalId)) {
                      continue;
                    }
                    final isValidCancellation =
                        status == ChatMessage.proposalCancelled &&
                            event.senderId == proposal.senderId &&
                            event.receiverId == proposal.receiverId;
                    final isValidResponse =
                        status != ChatMessage.proposalCancelled &&
                            event.senderId == proposal.receiverId &&
                            event.receiverId == proposal.senderId;
                    if (isValidCancellation || isValidResponse) {
                      proposalStatuses[proposalId] = status;
                    }
                  }
                  final visibleMessages = messages
                      .where((message) => message.proposalEventId == null)
                      .toList();
                  if (visibleMessages.isEmpty) {
                    return const Center(
                      child: Text('Nenhuma mensagem. Comece a conversa!',
                          style: TextStyle(color: Color(0xFF6B7280))),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    itemCount: visibleMessages.length,
                    itemBuilder: (context, index) {
                      final message = visibleMessages[index];
                      final status = proposalStatuses[message.id] ??
                          _localProposalStatuses[message.id] ??
                          ChatMessage.proposalPending;
                      final isPending = status == ChatMessage.proposalPending;
                      return _MessageBubble(
                        key: ValueKey(message.id),
                        message: message,
                        proposalStatus: status,
                        onCancelProposal: isArtist &&
                                message.isMine &&
                                message.isProposal &&
                                isPending &&
                                _updatingProposalId == null
                            ? () => _updateProposalStatus(
                                  message,
                                  ChatMessage.proposalCancelled,
                                )
                            : null,
                        onAcceptProposal: !isArtist &&
                                !message.isMine &&
                                message.isProposal &&
                                isPending &&
                                _updatingProposalId == null
                            ? () => _openAnamnesis(message)
                            : null,
                        onRejectProposal: !isArtist &&
                                !message.isMine &&
                                message.isProposal &&
                                isPending &&
                                _updatingProposalId == null
                            ? () => _updateProposalStatus(
                                  message,
                                  ChatMessage.proposalRejected,
                                )
                            : null,
                        onViewAnamnesis: isArtist &&
                                message.isMine &&
                                message.isProposal &&
                                status == ChatMessage.proposalAccepted
                            ? () => _openSavedAnamnesis(
                                  message,
                                  contact?.name ?? 'Cliente',
                                )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
            _buildInputArea(isArtist),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ChatContact? contact) {
    return AppBar(
      backgroundColor: InkFlowColors.primary,
      elevation: 0,
      leading: IconButton(
        icon:
            const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        tooltip: 'Voltar',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/inbox');
          }
        },
      ),
      titleSpacing: 0,
      title: InkWell(
        onTap: contact == null
            ? null
            : () => context.push('/artist/${contact.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              AvatarImage(url: contact?.avatarUrl, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact?.name ?? 'Conversa',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'Toque para ver o perfil',
                      style: TextStyle(color: Colors.white60, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recordingBar() {
    final minutes = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingSeconds % 60).toString().padLeft(2, '0');
    final tenths = (_recordingMilliseconds ~/ 100) % 10;
    return Row(
      children: [
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFFFE4E6),
            foregroundColor: const Color(0xFFE11D48),
          ),
          tooltip: 'Excluir gravação',
          onPressed: () => _finishRecording(send: false),
          icon: const Icon(Icons.delete_outline_rounded),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: InkFlowColors.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Text(
                  '$minutes:$seconds.$tenths',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      _recordingLevels.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 2.5,
                        height: 4 + (_recordingLevels[index] * 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .65),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _isRecordingPaused ? 'Continuar' : 'Pausar',
                  onPressed: _toggleRecordingPause,
                  icon: Icon(
                    _isRecordingPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: InkFlowColors.accent,
            foregroundColor: Colors.white,
          ),
          tooltip: 'Enviar áudio',
          onPressed: () => _finishRecording(send: true),
          icon: const Icon(Icons.send_rounded),
        ),
      ],
    );
  }

  Widget _buildInputArea(bool isArtist) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4))
      ]),
      child: _isRecording
          ? _recordingBar()
          : Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: InkFlowColors.accentDark),
                  tooltip: 'Enviar foto ou vídeo',
                  onPressed:
                      _isSending || _isRecording ? null : _showAttachmentSheet,
                ),
                if (isArtist) ...[
                  IconButton(
                    icon: const Icon(Icons.request_quote_outlined,
                        color: InkFlowColors.accentDark),
                    tooltip: 'Enviar proposta',
                    onPressed: _isSending ? null : _showProposalForm,
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(24)),
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                          hintText: 'Escreva uma mensagem...',
                          hintStyle:
                              TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                          border: InputBorder.none),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(
                    Icons.mic_none_rounded,
                    color: InkFlowColors.accentDark,
                    size: 27,
                  ),
                  tooltip: 'Gravar áudio',
                  onPressed: _isSending ? null : _toggleRecording,
                ),
                const SizedBox(width: 2),
                Container(
                  decoration: const BoxDecoration(
                      color: InkFlowColors.accent, shape: BoxShape.circle),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                    tooltip: 'Enviar',
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String proposalStatus;
  final VoidCallback? onCancelProposal;
  final VoidCallback? onAcceptProposal;
  final VoidCallback? onRejectProposal;
  final VoidCallback? onViewAnamnesis;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.proposalStatus,
    this.onCancelProposal,
    this.onAcceptProposal,
    this.onRejectProposal,
    this.onViewAnamnesis,
  });

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  clipBehavior: message.isProposal ? Clip.antiAlias : Clip.none,
                  padding: message.isProposal
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: message.isProposal
                        ? Colors.white
                        : isMine
                            ? InkFlowColors.primary
                            : Colors.white,
                    borderRadius: message.isProposal
                        ? BorderRadius.circular(20)
                        : BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isMine
                                ? const Radius.circular(16)
                                : Radius.zero,
                            bottomRight: isMine
                                ? Radius.zero
                                : const Radius.circular(16),
                          ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.proposal case final proposal?)
                        _ProposalCard(
                          proposal: proposal,
                          status: proposalStatus,
                          onCancel: onCancelProposal,
                          onAccept: onAcceptProposal,
                          onReject: onRejectProposal,
                          onViewAnamnesis: onViewAnamnesis,
                        ),
                      if (message.hasAttachment)
                        _AttachmentContent(message: message),
                      if (message.content.isNotEmpty &&
                          !message.isProposal) ...[
                        if (message.hasAttachment) const SizedBox(height: 8),
                        Text(
                          message.content,
                          style: TextStyle(
                            color:
                                isMine ? Colors.white : const Color(0xFF1F2937),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(message.timeLabel,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final Map<String, dynamic> proposal;
  final String status;
  final VoidCallback? onCancel;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onViewAnamnesis;

  const _ProposalCard({
    required this.proposal,
    required this.status,
    this.onCancel,
    this.onAccept,
    this.onReject,
    this.onViewAnamnesis,
  });

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(proposal['amount']?.toString() ?? '') ?? 0;
    final scheduledDate = DateTime.tryParse(proposal['date']?.toString() ?? '');
    final scheduledTime = proposal['time']?.toString();
    final durationMinutes =
        int.tryParse(proposal['durationMinutes']?.toString() ?? '') ?? 60;
    final notes = proposal['notes']?.toString().trim() ?? '';
    final timeParts = scheduledTime?.split(':');
    final isExpired = status == ChatMessage.proposalPending &&
        scheduledDate != null &&
        timeParts?.length == 2 &&
        !isFutureProposalSchedule(
          scheduledDate,
          int.tryParse(timeParts![0]) ?? 0,
          int.tryParse(timeParts[1]) ?? 0,
          DateTime.now(),
        );
    final displayStatus = isExpired ? 'expired' : status;
    final statusLabel = switch (displayStatus) {
      ChatMessage.proposalAccepted => 'Aceita',
      ChatMessage.proposalRejected => 'Recusada',
      ChatMessage.proposalCancelled => 'Cancelada',
      'expired' => 'Expirada',
      _ => 'Enviada',
    };
    final statusColor = switch (displayStatus) {
      ChatMessage.proposalAccepted => InkFlowColors.accent,
      ChatMessage.proposalRejected ||
      ChatMessage.proposalCancelled =>
        const Color(0xFFFFA7A7),
      'expired' => const Color(0xFFC7C7CE),
      _ => InkFlowColors.accent,
    };
    final isUnavailable = displayStatus == ChatMessage.proposalRejected ||
        displayStatus == ChatMessage.proposalCancelled ||
        displayStatus == 'expired';
    final statusMessage = switch (displayStatus) {
      ChatMessage.proposalAccepted => 'Proposta aceita pelo cliente.',
      ChatMessage.proposalRejected => 'Proposta recusada pelo cliente.',
      ChatMessage.proposalCancelled => 'Esta proposta não está mais válida.',
      'expired' => 'O horário desta proposta já passou.',
      _ => null,
    };
    final statusMessageColor = displayStatus == ChatMessage.proposalAccepted
        ? InkFlowColors.accentDark
        : displayStatus == 'expired'
            ? InkFlowColors.textMuted
            : InkFlowColors.error;
    final currency =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2);

    return SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: InkFlowColors.primary,
            child: Row(
              children: [
                const Icon(Icons.request_quote_outlined,
                    color: InkFlowColors.accent, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Proposta',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SERVIÇO',
                    style: TextStyle(
                        color: InkFlowColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .9)),
                const SizedBox(height: 5),
                Text(proposal['service']?.toString() ?? 'Serviço',
                    style: const TextStyle(
                        color: InkFlowColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 14),
                const Text('Valor combinado',
                    style: TextStyle(
                        color: InkFlowColors.textMuted, fontSize: 11)),
                const SizedBox(height: 3),
                Text(currency.format(amount),
                    style: TextStyle(
                        color: isUnavailable
                            ? InkFlowColors.textMuted
                            : InkFlowColors.accentDark,
                        fontSize: 23,
                        fontWeight: FontWeight.w800)),
                if (scheduledDate != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: InkFlowColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_outlined,
                            color: InkFlowColors.accentDark, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Data e horário',
                                  style: TextStyle(
                                      color: InkFlowColors.textMuted,
                                      fontSize: 10)),
                              const SizedBox(height: 2),
                              Text(
                                '${DateFormat('dd/MM/yyyy').format(scheduledDate)}${scheduledTime == null ? '' : ' às $scheduledTime'}',
                                style: const TextStyle(
                                    color: InkFlowColors.text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Duração estimada: ${durationMinutes < 60 ? '$durationMinutes min' : durationMinutes % 60 == 0 ? '${durationMinutes ~/ 60} h' : '${durationMinutes ~/ 60} h ${durationMinutes % 60} min'}',
                                style: const TextStyle(
                                  color: InkFlowColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: InkFlowColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(notes,
                        style: const TextStyle(
                            color: InkFlowColors.textMuted,
                            fontSize: 12,
                            height: 1.4)),
                  ),
                ],
                if (statusMessage != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: statusMessageColor, size: 17),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(statusMessage,
                            style: TextStyle(
                                color: statusMessageColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ] else if (onCancel != null) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: InkFlowColors.error,
                        backgroundColor: const Color(0xFFFFF7F7),
                        side: BorderSide(
                            color: InkFlowColors.error.withValues(alpha: .25)),
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancelar proposta'),
                    ),
                  ),
                ] else if (onAccept != null && onReject != null) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onReject,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: InkFlowColors.text,
                            side: const BorderSide(color: InkFlowColors.border),
                            minimumSize: const Size(0, 46),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Recusar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: onAccept,
                          style: FilledButton.styleFrom(
                            backgroundColor: InkFlowColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 46),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Aceitar'),
                        ),
                      ),
                    ],
                  ),
                ],
                if (onViewAnamnesis != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onViewAnamnesis,
                      icon: const Icon(Icons.assignment_outlined, size: 18),
                      label: const Text('Ver ficha de anamnese'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _AttachmentContent extends StatelessWidget {
  final ChatMessage message;

  const _AttachmentContent({required this.message});

  @override
  Widget build(BuildContext context) {
    final url = message.attachmentUrl;
    if (url == null) {
      return const SizedBox(
        width: 210,
        height: 80,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    switch (message.attachmentType) {
      case 'image':
        return GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            barrierColor: Colors.black.withValues(alpha: .92),
            builder: (context) => Dialog.fullscreen(
              backgroundColor: Colors.transparent,
              child: Stack(
                children: [
                  InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: NetworkImageWithFallback(url: url),
                    ),
                  ),
                  SafeArea(
                    child: IconButton.filledTonal(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: NetworkImageWithFallback(
              url: url,
              width: 220,
              height: 180,
            ),
          ),
        );
      case 'video':
        return _VideoAttachment(url: url);
      case 'audio':
        return _AudioAttachment(
          url: url,
          durationSeconds: message.durationSeconds,
          isMine: message.isMine,
        );
      default:
        return const Text('Anexo indisponível');
    }
  }
}

class _AudioAttachment extends StatefulWidget {
  final String url;
  final int? durationSeconds;
  final bool isMine;

  const _AudioAttachment({
    required this.url,
    required this.durationSeconds,
    required this.isMine,
  });

  @override
  State<_AudioAttachment> createState() => _AudioAttachmentState();
}

class _AudioAttachmentState extends State<_AudioAttachment> {
  late final AudioPlayer _player;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.setUrl(widget.url);
  }

  @override
  void didUpdateWidget(covariant _AudioAttachment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _player
        ..stop()
        ..setUrl(widget.url);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMine ? Colors.white : InkFlowColors.primary;
    return SizedBox(
      width: 245,
      child: Row(
        children: [
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snapshot) {
              final playing = snapshot.data?.playing ?? false;
              return IconButton(
                onPressed: () async {
                  if (playing) {
                    await _player.pause();
                  } else {
                    if (_player.processingState == ProcessingState.completed) {
                      await _player.seek(Duration.zero);
                    }
                    await _player.play();
                  }
                },
                icon: Icon(
                  playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: color,
                  size: 38,
                ),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<Duration?>(
              stream: _player.durationStream,
              builder: (context, durationSnapshot) {
                final fallback = Duration(
                    seconds: widget.durationSeconds?.clamp(0, 86400) ?? 0);
                final duration = durationSnapshot.data ?? fallback;
                return StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  initialData: Duration.zero,
                  builder: (context, positionSnapshot) {
                    final rawPosition = positionSnapshot.data ?? Duration.zero;
                    final position =
                        rawPosition > duration ? duration : rawPosition;
                    final maxMilliseconds =
                        duration.inMilliseconds.clamp(1, 86400000).toDouble();
                    final value = position.inMilliseconds
                        .clamp(0, maxMilliseconds.toInt())
                        .toDouble();

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            activeTrackColor: color,
                            inactiveTrackColor: color.withValues(alpha: .28),
                            thumbColor: color,
                            overlayColor: color.withValues(alpha: .12),
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 13),
                          ),
                          child: Slider(
                            value: value,
                            max: maxMilliseconds,
                            onChanged: duration.inMilliseconds <= 0
                                ? null
                                : (milliseconds) => _player.seek(
                                      Duration(
                                          milliseconds: milliseconds.round()),
                                    ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '${_formatAudioDuration(position)} / '
                            '${_formatAudioDuration(duration)}',
                            style: TextStyle(
                              color: color.withValues(alpha: .78),
                              fontSize: 10,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                      ],
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

  String _formatAudioDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _VideoAttachment extends StatefulWidget {
  final String url;

  const _VideoAttachment({required this.url});

  @override
  State<_VideoAttachment> createState() => _VideoAttachmentState();
}

class _VideoAttachmentState extends State<_VideoAttachment> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const SizedBox(
        width: 220,
        height: 130,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying
              ? _controller.pause()
              : _controller.play();
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 220,
          child: AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoPlayer(_controller),
                if (!_controller.value.isPlaying)
                  const ColoredBox(
                    color: Colors.black26,
                    child: Center(
                      child: Icon(Icons.play_circle_fill,
                          color: Colors.white, size: 52),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
