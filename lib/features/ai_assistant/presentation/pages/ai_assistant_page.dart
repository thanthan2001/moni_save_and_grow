import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:my_clean_app/features/ai_assistant/domain/entities/ai_transaction_parse_entity.dart';
import 'package:my_clean_app/features/ai_assistant/presentation/bloc/ai_assistant_bloc.dart';
import 'package:my_clean_app/features/ai_assistant/presentation/bloc/ai_assistant_event.dart';
import 'package:my_clean_app/features/ai_assistant/presentation/bloc/ai_assistant_state.dart';
import 'package:my_clean_app/features/category/domain/entities/category_entity.dart';
import 'package:my_clean_app/global/widgets/widgets.dart';
import 'package:speech_to_text/speech_to_text.dart';

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage>
    with SingleTickerProviderStateMixin {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SpeechToText _speechToText = SpeechToText();
  final ImagePicker _imagePicker = ImagePicker();
  final List<_ChatBubbleData> _chatMessages = [];
  AnimationController? _voiceWaveController;

  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isProcessingOcr = false;

  @override
  void initState() {
    super.initState();
    _ensureVoiceWaveController();
    context.read<AiAssistantBloc>().add(const LoadAiAssistantContext());
    _initSpeech();
    _chatMessages.add(
      _ChatBubbleData(
        text:
            'Xin chào, mình có thể giúp bạn phân tích giao dịch từ đoạn chat tự nhiên, giọng nói hoặc ảnh hóa đơn.',
        isUser: false,
        icon: Icons.smart_toy_rounded,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _speechToText.stop();
    _voiceWaveController?.dispose();
    _voiceWaveController = null;
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  AnimationController _ensureVoiceWaveController() {
    return _voiceWaveController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  void _setListeningState(bool listening) {
    if (_isListening == listening) return;
    final controller = _ensureVoiceWaveController();

    setState(() {
      _isListening = listening;
    });

    if (listening) {
      controller.repeat();
    } else {
      controller.stop();
      controller.reset();
    }
  }

  Future<void> _initSpeech() async {
    try {
      final enabled = await _speechToText.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            _setListeningState(false);
          }
        },
        onError: (_) {
          if (!mounted) return;
          _setListeningState(false);
        },
      );

      if (!mounted) return;
      setState(() {
        _speechEnabled = enabled;
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _speechEnabled = false;
        _isListening = false;
      });
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _speechEnabled = false;
        _isListening = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _speechEnabled = false;
        _isListening = false;
      });
    }
  }

  Future<void> _toggleVoiceInput() async {
    FocusScope.of(context).unfocus();

    if (!_speechEnabled) {
      await _initSpeech();
      if (!_speechEnabled) {
        if (!mounted) return;
        AppSnackBar.showError(
          context,
          'Voice chưa sẵn sàng. Nếu vừa thêm plugin, hãy tắt app và chạy lại hoàn toàn (không chỉ hot reload).',
        );
        return;
      }
    }

    if (_isListening) {
      await _speechToText.stop();
      if (!mounted) return;
      _setListeningState(false);
      return;
    }

    try {
      final dynamic listenResult = await _speechToText.listen(
        localeId: 'vi_VN',
        listenMode: ListenMode.dictation,
        onResult: (result) {
          final text = result.recognizedWords.trim();
          if (text.isEmpty || !mounted) return;

          _messageController.text = text;
          _messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: _messageController.text.length),
          );
        },
      );

      if (!mounted) return;
      final isListeningNow =
          listenResult is bool ? listenResult : _speechToText.isListening;
      _setListeningState(isListeningNow);
    } on PlatformException {
      if (!mounted) return;
      _setListeningState(false);
      AppSnackBar.showError(
        context,
        'Không thể bật Voice to Text. Vui lòng thử lại.',
      );
    } catch (_) {
      if (!mounted) return;
      _setListeningState(false);
      AppSnackBar.showError(
        context,
        'Voice gặp lỗi không xác định. Vui lòng thử lại.',
      );
    }
  }

  Future<void> _openOcrSourcePicker() async {
    FocusScope.of(context).unfocus();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Chụp hóa đơn'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Chọn ảnh từ thư viện'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;
    await _extractTextFromImage(source);
  }

  Future<void> _extractTextFromImage(ImageSource source) async {
    TextRecognizer? textRecognizer;
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (image == null) return;

      if (!mounted) return;
      setState(() {
        _isProcessingOcr = true;
      });

      textRecognizer = TextRecognizer();
      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await textRecognizer.processImage(inputImage);

      final extracted = recognizedText.text.trim();
      if (!mounted) return;

      if (extracted.isEmpty) {
        AppSnackBar.showError(
            context, 'Không đọc được nội dung từ ảnh hóa đơn');
      } else {
        final currentText = _messageController.text.trim();
        final mergedText =
            currentText.isEmpty ? extracted : '$currentText\n$extracted';

        _messageController.text = mergedText;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length),
        );

        AppSnackBar.showSuccess(
          context,
          'Đã trích xuất văn bản từ ảnh. Bạn có thể bấm Phân tích ngay.',
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Không thể xử lý ảnh hóa đơn. Vui lòng thử lại.',
        );
      }
    } finally {
      await textRecognizer?.close();
      if (mounted) {
        setState(() {
          _isProcessingOcr = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  void _appendMessage({
    required String text,
    required bool isUser,
    IconData? icon,
    Color? accent,
  }) {
    setState(() {
      _chatMessages.add(
        _ChatBubbleData(
          text: text,
          isUser: isUser,
          icon: icon,
          accent: accent,
          createdAt: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  void _sendMessage(AiAssistantState state) {
    if (state.isLoading) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) {
      AppSnackBar.showError(context, 'Vui lòng nhập nội dung tin nhắn');
      return;
    }

    FocusScope.of(context).unfocus();
    _appendMessage(text: message, isUser: true);
    context.read<AiAssistantBloc>().add(ParseAiMessage(message: message));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Text(
          'Trợ lý AI',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: colorScheme.primary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/features');
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Xóa hội thoại',
            onPressed: () {
              _messageController.clear();
              setState(() {
                _chatMessages
                  ..clear()
                  ..add(
                    _ChatBubbleData(
                      text:
                          'Hội thoại đã được làm mới. Bạn hãy gửi tin nhắn giao dịch mới nhé.',
                      isUser: false,
                      icon: Icons.refresh_rounded,
                      createdAt: DateTime.now(),
                    ),
                  );
              });
              context
                  .read<AiAssistantBloc>()
                  .add(const ClearParsedTransactions());
            },
            icon: Icon(Icons.delete_sweep_rounded, color: colorScheme.primary),
          ),
        ],
      ),
      body: BlocConsumer<AiAssistantBloc, AiAssistantState>(
        listenWhen: (previous, current) {
          final messageChanged =
              previous.successMessage != current.successMessage ||
                  previous.errorMessage != current.errorMessage;
          final becameEmpty = previous.parsedTransactions.isNotEmpty &&
              current.parsedTransactions.isEmpty;
          return messageChanged || becameEmpty;
        },
        listener: (context, state) {
          if (state.errorMessage != null) {
            AppSnackBar.showError(context, state.errorMessage!);
            _appendMessage(
              text: state.errorMessage!,
              isUser: false,
              icon: Icons.error_outline_rounded,
              accent: colorScheme.error,
            );
          }

          final becameEmptyAfterAction = state.parsedTransactions.isEmpty;

          if (state.successMessage != null) {
            AppSnackBar.showSuccess(context, state.successMessage!);

            final success = state.successMessage!.toLowerCase();
            final parsedSuccess = success.contains('đã phân tích');
            _appendMessage(
              text: state.successMessage!,
              isUser: false,
              icon: Icons.auto_awesome_rounded,
              accent: colorScheme.primary,
            );
            if (parsedSuccess) {
              _messageController.clear();
              _scrollToBottom();
            }
          }

          if (becameEmptyAfterAction) {
            _messageController.clear();
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    children: [
                      ..._chatMessages.map(
                        (message) => _buildChatBubble(
                          message,
                          colorScheme,
                        ),
                      ),
                      if (state.isLoading) _buildTypingBubble(colorScheme),
                      _buildGuideCard(state, colorScheme),
                      if (state.parsedTransactions.isNotEmpty)
                        _buildParsedResultPanel(state, colorScheme),
                    ],
                  ),
                ),
                _buildInputSection(state, colorScheme),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputSection(AiAssistantState state, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.6)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildInputTools(colorScheme),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    maxLines: 5,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(state),
                    decoration: InputDecoration(
                      hintText: 'Nhập tin nhắn thu chi...',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.75),
                      ),
                      filled: true,
                      fillColor:
                          colorScheme.surfaceContainerHighest.withOpacity(0.55),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.primary,
                  child: IconButton(
                    onPressed:
                        state.isLoading ? null : () => _sendMessage(state),
                    icon: state.isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : Icon(Icons.send_rounded,
                            color: colorScheme.onPrimary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputTools(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isProcessingOcr ? null : _toggleVoiceInput,
            icon: _isListening
                ? _buildVoiceWave(colorScheme)
                : Icon(Icons.mic_none_rounded, color: colorScheme.primary),
            label: Text(_isListening ? 'Đang nghe...' : 'Voice'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              side: BorderSide(color: colorScheme.primary.withOpacity(0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isProcessingOcr ? null : _openOcrSourcePicker,
            icon: _isProcessingOcr
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.receipt_long_rounded, color: colorScheme.primary),
            label: Text(_isProcessingOcr ? 'Đang OCR...' : 'OCR hóa đơn'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              side: BorderSide(color: colorScheme.primary.withOpacity(0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceWave(ColorScheme colorScheme) {
    final controller = _ensureVoiceWaveController();

    return SizedBox(
      width: 24,
      height: 18,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (index) {
              final phase = controller.value * (2 * math.pi);
              final amp = (math.sin(phase + (index * 0.8)) + 1) / 2;
              final barHeight = 5.0 + (amp * 10.0);

              return Container(
                width: 3,
                height: barHeight,
                decoration: BoxDecoration(
                  color: Colors.red.shade500,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildChatBubble(_ChatBubbleData message, ColorScheme colorScheme) {
    final align = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = message.isUser
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest.withOpacity(0.7);
    final textColor =
        message.isUser ? colorScheme.onPrimary : colorScheme.onSurface;

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.icon != null && !message.isUser) ...[
                Row(
                  children: [
                    Icon(
                      message.icon,
                      size: 16,
                      color: message.accent ?? colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'AI Assistant',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Text(
                message.text,
                style: TextStyle(
                  color: textColor,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                DateFormat('HH:mm').format(message.createdAt),
                style: TextStyle(
                  color: textColor.withOpacity(0.75),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingBubble(ColorScheme colorScheme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'AI đang phân tích...',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParsedResultPanel(
    AiAssistantState state,
    ColorScheme colorScheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.55)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      margin: const EdgeInsets.only(top: 2, bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Kết quả (${state.parsedTransactions.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: state.isSaving
                    ? null
                    : () {
                        context
                            .read<AiAssistantBloc>()
                            .add(const SaveParsedTransactions());
                      },
                icon: state.isSaving && state.savingIndex == null
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_alt_rounded),
                label: const Text('Lưu tất cả'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(
            state.parsedTransactions.length,
            (index) {
              final item = state.parsedTransactions[index];
              return _buildParsedItem(index, item, state, colorScheme);
            },
          ),
          // _buildDebugJson(state, colorScheme),
        ],
      ),
    );
  }

  Widget _buildDebugJson(AiAssistantState state, ColorScheme colorScheme) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          'Dữ liệu JSON gốc (Debug)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        collapsedBackgroundColor: colorScheme.surface,
        backgroundColor: colorScheme.surface,
        iconColor: colorScheme.primary,
        collapsedIconColor: colorScheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              state.rawJson,
              style: const TextStyle(
                color: Color(0xFFA6E22E),
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard(AiAssistantState state, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.secondaryContainer),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mẹo nhập nhanh',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bạn có thể nhập tự nhiên như chat. Ví dụ: "ăn sáng 50" sẽ hiểu là 50.000đ. Nhập "nhận lương 20tr" sẽ hiểu là 20.000.000đ.',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSecondaryContainer.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Danh mục khả dụng: ${state.categories.length} • Hỗ trợ nhiều giao dịch trong 1 câu',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSecondaryContainer.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParsedItem(
    int index,
    AiTransactionParseEntity item,
    AiAssistantState state,
    ColorScheme colorScheme,
  ) {
    final isSavingThisCard = state.isSaving && state.savingIndex == index;
    final isIncome = item.type == 'thu nhập';
    final cardColor = isIncome ? Colors.green.shade50 : Colors.red.shade50;
    final iconColor = isIncome ? Colors.green.shade600 : Colors.red.shade600;
    final iconData = isIncome
        ? Icons.arrow_circle_up_rounded
        : Icons.arrow_circle_down_rounded;
    final amountColor = isIncome ? Colors.green.shade700 : Colors.red.shade700;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                color: iconColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(iconData, color: iconColor, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  item.type.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: iconColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.delete_outline_rounded,
                                color: Colors.red.shade500, size: 20),
                            onPressed: state.isSaving
                                ? null
                                : () {
                                    context.read<AiAssistantBloc>().add(
                                          RemoveParsedTransaction(index: index),
                                        );
                                  },
                            tooltip: 'Xóa giao dịch',
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.edit_rounded,
                                color: colorScheme.primary, size: 20),
                            onPressed: () =>
                                _showEditDialog(index, item, state),
                            tooltip: 'Sửa giao dịch',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.categoryName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today_rounded,
                                        size: 14,
                                        color: colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _formatDisplayDateTime(item.datetime),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(
                            item.amount == null
                                ? '?'
                                : _formatAmount(item.amount!),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: amountColor,
                            ),
                          ),
                        ],
                      ),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withOpacity(0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: state.isSaving
                              ? null
                              : () {
                                  context.read<AiAssistantBloc>().add(
                                        SaveParsedTransaction(index: index),
                                      );
                                },
                          icon: isSavingThisCard
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.check_circle_outline_rounded),
                          label: Text(isSavingThisCard
                              ? 'Đang lưu...'
                              : 'Lưu riêng giao dịch này'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            side: BorderSide(
                                color: colorScheme.primary.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(
    int index,
    AiTransactionParseEntity item,
    AiAssistantState state,
  ) async {
    final amountController = TextEditingController(
      text: item.amount?.toString() ?? '',
    );
    final descriptionController = TextEditingController(text: item.description);
    final datetimeController = TextEditingController(text: item.datetime);

    var selectedType = item.type;
    var selectedCategoryId = item.categoryId;

    List<CategoryEntity> getCategoriesByType(String type) {
      final isIncome = type == 'thu nhập';
      return state.categories.where((cat) {
        if (cat.type == TransactionCategoryType.both) return true;
        if (isIncome) return cat.type == TransactionCategoryType.income;
        return cat.type == TransactionCategoryType.expense;
      }).toList();
    }

    final editedTransaction = await showDialog<AiTransactionParseEntity>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final categories = getCategoriesByType(selectedType);
            if (!categories.any((c) => c.id == selectedCategoryId) &&
                categories.isNotEmpty) {
              selectedCategoryId = categories.first.id;
            }

            final colorScheme = Theme.of(context).colorScheme;

            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.edit_document,
                                  color: colorScheme.primary),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Sửa giao dịch #${index + 1}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          decoration: _buildInputDecoration(
                              'Loại', Icons.swap_vert_rounded),
                          items: const [
                            DropdownMenuItem(
                                value: 'chi phí', child: Text('Chi phí')),
                            DropdownMenuItem(
                                value: 'thu nhập', child: Text('Thu nhập')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setStateDialog(() => selectedType = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: amountController,
                          decoration: _buildInputDecoration(
                              'Số tiền (Ví dụ: 50 hoặc 50000)',
                              Icons.payments_rounded),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue:
                              categories.isEmpty ? null : selectedCategoryId,
                          decoration: _buildInputDecoration(
                              'Danh mục', Icons.category_rounded),
                          isExpanded: true,
                          items: categories
                              .map(
                                (cat) => DropdownMenuItem(
                                  value: cat.id,
                                  child: Text(cat.name,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setStateDialog(() => selectedCategoryId = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: descriptionController,
                          decoration: _buildInputDecoration(
                              'Ghi chú', Icons.notes_rounded),
                          maxLines: 2,
                          minLines: 1,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: datetimeController,
                          decoration: _buildInputDecoration(
                              'Thời gian', Icons.event_rounded),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Hủy',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: categories.isEmpty
                                    ? null
                                    : () {
                                        final amount = _normalizeAmountInput(
                                            amountController.text);
                                        final selectedCategory =
                                            state.categories.firstWhere(
                                          (c) => c.id == selectedCategoryId,
                                          orElse: () => state.categories.first,
                                        );

                                        final updated = item.copyWith(
                                          type: selectedType,
                                          amount: amount,
                                          clearAmount: amount == null,
                                          categoryId: selectedCategory.id,
                                          categoryName: selectedCategory.name,
                                          description: descriptionController
                                                  .text
                                                  .trim()
                                                  .isEmpty
                                              ? item.description
                                              : descriptionController.text
                                                  .trim(),
                                          datetime: datetimeController.text
                                                  .trim()
                                                  .isEmpty
                                              ? 'now'
                                              : datetimeController.text.trim(),
                                        );

                                        Navigator.pop(dialogContext, updated);
                                      },
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: const Text('Lưu',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    amountController.dispose();
    descriptionController.dispose();
    datetimeController.dispose();

    if (!mounted) return;

    if (editedTransaction != null) {
      context.read<AiAssistantBloc>().add(
            UpdateParsedTransaction(
              index: index,
              transaction: editedTransaction,
            ),
          );
      AppSnackBar.showSuccess(context, 'Đã cập nhật giao dịch #${index + 1}');
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 22),
      filled: true,
      fillColor: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }

  String _formatAmount(int amount) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(amount)} đ';
  }

  String _formatDisplayDateTime(String raw) {
    if (raw.trim().toLowerCase() == 'now') {
      return 'Bây giờ';
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }

    return DateFormat('dd/MM/yyyy HH:mm').format(parsed);
  }

  int? _normalizeAmountInput(String text) {
    final value = int.tryParse(text.replaceAll(RegExp(r'[^\d]'), ''));
    if (value == null) return null;
    if (value > 0 && value < 1000) return value * 1000;
    return value;
  }
}

class _ChatBubbleData {
  final String text;
  final bool isUser;
  final IconData? icon;
  final Color? accent;
  final DateTime createdAt;

  const _ChatBubbleData({
    required this.text,
    required this.isUser,
    required this.createdAt,
    this.icon,
    this.accent,
  });
}
