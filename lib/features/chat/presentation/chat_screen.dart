import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/chat/data/chat_repository.dart';
import 'package:inkflow/features/chat/domain/chat_message.dart';
import 'package:inkflow/features/profile/providers/profile_provider.dart';

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

  void _showProposalUnavailable() {
    showErrorSnackBar(
      context,
      'O envio de propostas ainda não está disponível.',
    );
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
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text('Nenhuma mensagem. Comece a conversa!',
                          style: TextStyle(color: Color(0xFF6B7280))),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) => _MessageBubble(
                      key: ValueKey(messages[index].id),
                      message: messages[index],
                    ),
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
                  // A proposta formal (RF04/RF05) ainda não tem tabela no banco. O
                  // botão permanece visível, mas assume explicitamente que não
                  // funciona em vez de abrir um formulário que descarta os dados.
                  IconButton(
                    icon: const Icon(Icons.request_quote_outlined,
                        color: Color(0xFF6B7280)),
                    tooltip: 'Enviar proposta (em desenvolvimento)',
                    onPressed: _showProposalUnavailable,
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

  const _MessageBubble({super.key, required this.message});

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMine ? InkFlowColors.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft:
                          isMine ? const Radius.circular(16) : Radius.zero,
                      bottomRight:
                          isMine ? Radius.zero : const Radius.circular(16),
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
                      if (message.hasAttachment)
                        _AttachmentContent(message: message),
                      if (message.content.isNotEmpty) ...[
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
