/// Сообщение чата поддержки.
///
/// `isBot` и `isMine` — РАЗНЫЕ вопросы, и оба нужны: сообщение оператора
/// (не бот и не моё) выглядит иначе, чем ответ бота, и иначе, чем моя
/// реплика. Один флаг «слева/справа» эти три случая не различает.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.isBot,
    required this.isMine,
    required this.createdAt,
  });

  final int id;
  final String text;
  final bool isBot;
  final bool isMine;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json, {int? currentUserId}) {
    final senderId = json['sender_id'] as int?;
    return ChatMessage(
      id: json['id'] as int,
      text: (json['body'] ?? json['text'] ?? '') as String,
      isBot: (json['is_bot'] as bool?) ?? false,
      // `sender_id == null` — это бот (см. миграцию 53fad0634450), своим
      // такое сообщение считать нельзя даже при неизвестном currentUserId.
      isMine: senderId != null && currentUserId != null && senderId == currentUserId,
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
