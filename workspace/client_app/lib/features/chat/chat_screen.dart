import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/chat_controller.dart';
import '../../controllers/controller_state.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/chat_message.dart';

/// Чат поддержки: бот отвечает сам, оператор подключается на сложном.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  /// Сколько сообщений уже показано и шли ли точки — по изменению этих
  /// двух чисел лента доматывается вниз. Слушать сам контроллер нельзя:
  /// прокручивать нужно ПОСЛЕ кадра, когда новая высота уже известна.
  int _shownCount = 0;
  bool _shownTyping = false;

  /// Быстрые вопросы подобраны под ключевые слова демо-бота — менять
  /// формулировки нельзя, иначе бот ответит заглушкой.
  // TODO l10n: строк нет в общем файле, новые ключи заводить нельзя
  static const List<String> _quickQuestions = [
    'Минимальная сумма заказа?',
    'Как оплатить?',
    'Куда привезут заказ?',
    'Есть промокод?',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chat = context.read<ChatController>();
      if (chat.state == ControllerState.initial) chat.load();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    context.read<ChatController>().send(text);
    _input.clear();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chat = context.watch<ChatController>();

    if (chat.messages.length != _shownCount || chat.botTyping != _shownTyping) {
      _shownCount = chat.messages.length;
      _shownTyping = chat.botTyping;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.chatTitle),
            Text(
              // TODO l10n: строки нет в общем файле, новые ключи заводить нельзя
              'Отвечаем за пару минут',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _feed(chat, l10n)),
          if (chat.messages.length <= 2) _quickRow(),
          _composer(l10n),
        ],
      ),
    );
  }

  Widget _feed(ChatController chat, AppLocalizations l10n) {
    if (chat.messages.isEmpty && chat.state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (chat.messages.isEmpty && chat.state.isError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.loadingError,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      // Лента в естественном порядке: история короткая, а `reverse: true`
      // перевернул бы и порядок чтения, и пустое состояние.
      itemCount: chat.messages.length + (chat.botTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= chat.messages.length) return const TypingBubble();
        return _MessageBubble(message: chat.messages[index], l10n: l10n);
      },
    );
  }

  Widget _quickRow() {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
        itemCount: _quickQuestions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => Center(
          child: ActionChip(
            label: Text(_quickQuestions[index]),
            onPressed: () => _send(_quickQuestions[index]),
          ),
        ),
      ),
    );
  }

  Widget _composer(AppLocalizations l10n) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.gap),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  focusNode: _inputFocus,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: l10n.chatHint,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (value) {
                    _send(value);
                    // Фокус возвращаем сразу: в переписке следующая реплика
                    // почти всегда идёт следом, и лишний тап по полю мешает.
                    _inputFocus.requestFocus();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: AppColors.accent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: const Icon(Icons.arrow_upward, color: Colors.white),
                  tooltip: l10n.chatSend,
                  onPressed: () => _send(_input.text),
                  constraints: const BoxConstraints.tightFor(width: 48, height: 48),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Пузырь сообщения. Три вида отправителя — я, бот, оператор — различаются
/// цветом и меткой: без метки ответ бота выдаёт себя только формулировкой.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.l10n});

  final ChatMessage message;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final width = MediaQuery.sizeOf(context).width * 0.78;
    final label = mine
        ? null
        : (message.isBot ? l10n.chatBotLabel : l10n.chatOperatorLabel);

    final background = mine
        ? AppColors.accent
        : (message.isBot ? AppColors.surface : AppColors.accentSoft);
    final foreground = mine ? Colors.white : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.gap),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: background,
                // Срезанный угол со стороны отправителя — «хвостик»
                // пузыря: он и задаёт направление реплики.
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppSizes.radius),
                  topRight: const Radius.circular(AppSizes.radius),
                  bottomLeft: Radius.circular(mine ? AppSizes.radius : 4),
                  bottomRight: Radius.circular(mine ? 4 : AppSizes.radius),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(fontSize: 15, height: 1.35, color: foreground),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(
              DateFormat('HH:mm').format(message.createdAt),
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Три прыгающие точки, пока бот «печатает».
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.gap),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppSizes.radius),
              topRight: Radius.circular(AppSizes.radius),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(AppSizes.radius),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
                  child: _Dot(animation: _dots, order: i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.animation, required this.order});

  final Animation<double> animation;
  final int order;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // Точки прыгают по очереди: каждая берёт свою треть цикла.
        final start = order * 0.2;
        final t = ((animation.value - start) % 1.0).clamp(0.0, 1.0);
        final lift = t < 0.3 ? Curves.easeOut.transform(t / 0.3) : 0.0;
        return Transform.translate(
          offset: Offset(0, -4 * lift),
          child: child,
        );
      },
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: AppColors.textMuted,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
