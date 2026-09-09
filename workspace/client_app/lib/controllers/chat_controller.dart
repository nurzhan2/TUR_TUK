import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/di.dart';
import '../models/chat_message.dart';
import 'controller_state.dart';

class ChatController extends ChangeNotifier {
  ControllerState state = ControllerState.initial;
  String? errorMessage;

  List<ChatMessage> messages = const [];

  /// Собеседник «печатает». Пока ждём ответа бота, экран показывает три
  /// точки — иначе секунда тишины после отправки читается как «не дошло».
  bool botTyping = false;

  StreamSubscription<ChatMessage>? _incoming;

  Future<void> load() async {
    state = ControllerState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      messages = await Di.chat.history();
      state = ControllerState.loaded;
      _listen();
    } catch (error) {
      state = ControllerState.error;
      errorMessage = '$error';
    }
    notifyListeners();
  }

  void _listen() {
    // Подписка одна на всё время жизни контроллера: экран чата открывают
    // и закрывают много раз, а вторая подписка удвоила бы каждое входящее.
    _incoming ??= Di.chat.incoming().listen((message) {
      botTyping = false;
      messages = [...messages, message];
      notifyListeners();
    });
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      final mine = await Di.chat.send(trimmed);
      messages = [...messages, mine];
      botTyping = true;
      errorMessage = null;
    } catch (error) {
      errorMessage = '$error';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _incoming?.cancel();
    super.dispose();
  }
}
