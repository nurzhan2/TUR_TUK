import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/demo/demo_state.dart';
import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
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
/// Чат на сервере привязан к ЗАКАЗУ (`app/routers/chat.py`), а экран —
/// общая переписка с поддержкой. Поэтому, если заказ не передан, берётся
/// последний заказ гостя; заказов нет — понятная подсказка с контактами.
///
/// Отправка и входящие идут по WebSocket (`/ws/chat/{id}`), история — REST.
class ApiChatRepository implements ChatRepository {
  ApiChatRepository(this._api, {int? orderId}) : _orderId = orderId; // ignore: prefer_initializing_formals

  final ApiClient _api;

  /// Чат на сервере привязан к заказу (`/ws/chat/{order_id}`). Не передан —
  /// берётся последний заказ гостя: вопрос «где мой заказ» почти всегда
  /// про него.
  int? _orderId;
  int? _userId;
  WebSocketChannel? _socket;
  final StreamController<ChatMessage> _raw = StreamController.broadcast();

  Future<int> _resolveOrder() async {
    final known = _orderId;
    if (known != null) return known;
    final orders = await _api.get('/orders/history') as List;
    if (orders.isEmpty) {
      throw ApiException(
        409,
        'Чат с поддержкой открывается после первого заказа. '
        'Контакты поддержки — в профиле, раздел «О приложении».',
      );
    }
    // История отсортирована сервером от новых к старым.
    return _orderId = (orders.first as Map<String, dynamic>)['id'] as int;
  }

  Future<int?> _currentUserId() async {
    if (_userId != null) return _userId;
    try {
      final me = await _api.get('/auth/me') as Map<String, dynamic>;
      return _userId = me['id'] as int?;
    } catch (_) {
      return null;
    }
  }

  Future<WebSocketChannel> _connect() async {
    final existing = _socket;
    if (existing != null) return existing;
    final orderId = await _resolveOrder();
    final userId = await _currentUserId();
    final base = Uri.parse(ApiConfig.baseUrl);
    final socket = WebSocketChannel.connect(base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/chat/$orderId',
      queryParameters: {'token': _api.accessToken ?? ''},
    ));
    _socket = socket;
    socket.stream.listen(
      (raw) {
        final json = jsonDecode(raw as String) as Map<String, dynamic>;
        _raw.add(ChatMessage.fromJson(json, currentUserId: userId));
      },
      // Обрыв — следующее сообщение откроет сокет заново.
      onDone: () => _socket = null,
      onError: (Object _) => _socket = null,
    );
    await socket.ready;
    return socket;
  }

  @override
  Future<List<ChatMessage>> history() async {
    final orderId = await _resolveOrder();
    final userId = await _currentUserId();
    final body = await _api.get('/chat/$orderId/messages') as List;
    // Сразу подписываемся: ответ поддержки придёт, даже если гость молчит.
    unawaited(_connect().then((_) {}, onError: (Object _) {}));
    return [
      for (final item in body)
        ChatMessage.fromJson(item as Map<String, dynamic>, currentUserId: userId),
    ];
  }

  /// Сообщение уходит в сокет; возвращается то, что сервер сохранил и
  /// разослал обратно, — с настоящим id и временем. Эхо своего сообщения
  /// из [incoming] убрано, иначе оно появилось бы в ленте дважды.
  @override
  Future<ChatMessage> send(String text) async {
    final socket = await _connect();
    final echo = _raw.stream
        .firstWhere((m) => m.isMine && m.text == text)
        .timeout(const Duration(seconds: 15));
    socket.sink.add(jsonEncode({'body': text}));
    return echo;
  }

  @override
  Stream<ChatMessage> incoming() => _raw.stream.where((m) => !m.isMine);
}
