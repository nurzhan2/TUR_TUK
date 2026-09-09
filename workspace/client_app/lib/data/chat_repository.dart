import 'dart:async';

import '../core/demo/demo_state.dart';
import '../core/network/api_client.dart';
import '../models/chat_message.dart';
import 'catalog_repository.dart' show kDemoLatency;

abstract class ChatRepository {
  Future<List<ChatMessage>> history();

  Future<ChatMessage> send(String text);

  /// Входящие сообщения: ответы бота и реплики оператора.
  Stream<ChatMessage> incoming();
}

class DemoChatRepository implements ChatRepository {
  DemoChatRepository();

  /// Пауза перед ответом бота. Мгновенный ответ выдаёт заготовку: живой
  /// собеседник — хоть бы и бот — секунду «печатает».
  static const Duration replyDelay = Duration(milliseconds: 1200);

  /// Broadcast: экран чата подписывается и отписывается при каждом входе,
  /// а одиночный поток второй подписки уже не принял бы.
  final StreamController<ChatMessage> _incoming =
      StreamController<ChatMessage>.broadcast();

  @override
  Future<List<ChatMessage>> history() async {
    await Future<void>.delayed(kDemoLatency);
    return DemoState.instance.chat;
  }

  @override
  Future<ChatMessage> send(String text) async {
    final mine = DemoState.instance.addMyMessage(text);
    // Ответ бота НЕ ждём: метод возвращает отправленную реплику сразу,
    // чтобы она появилась в списке без задержки, а ответ придёт потоком.
    Future<void>.delayed(replyDelay).then((_) {
      if (_incoming.isClosed) return;
      _incoming.add(DemoState.instance.addBotReply(text));
    });
    return mine;
  }

  @override
  Stream<ChatMessage> incoming() => _incoming.stream;

  void dispose() => _incoming.close();
}

/// Боевой чат.
///
/// ДВА ИЗВЕСТНЫХ ПРОБЕЛА, и оба — свойства бэкенда, а не недоделки здесь.
///
/// Первое: чат на сервере привязан к ЗАКАЗУ (`GET /chat/{order_id}/messages`
/// в `app/routers/chat.py`), а контракт экрана — общая переписка с
/// поддержкой. Поэтому репозиторий берёт номер заказа снаружи: экран знает,
/// про какой заказ спрашивают.
///
/// Второе: отправка и входящие идут ТОЛЬКО по WebSocket (`/ws/chat/{id}`),
/// REST-эндпоинта на запись нет, а `web_socket_channel` в зависимостях
/// не значится. Пока его не добавили, `send` отказывает с текстом, а
/// `incoming` пуст: подделка вместо живых сообщений хуже, чем их
/// отсутствие. Демо-режима это не касается.
class ApiChatRepository implements ChatRepository {
  ApiChatRepository(this._api, {this.orderId});

  final ApiClient _api;

  /// Заказ, к чату которого подключаемся. `null` — заказа ещё нет, и
  /// спрашивать нечего.
  final int? orderId;

  @override
  Future<List<ChatMessage>> history() async {
    if (orderId == null) return const [];
    final body = await _api.get('/chat/$orderId/messages') as List;
    return [
      for (final item in body) ChatMessage.fromJson(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<ChatMessage> send(String text) async {
    throw UnimplementedError(
      'Отправка сообщения идёт по WebSocket /ws/chat/{order_id}; добавьте '
      'web_socket_channel перед сборкой с --dart-define=DEMO=false',
    );
  }

  @override
  Stream<ChatMessage> incoming() => const Stream<ChatMessage>.empty();
}
