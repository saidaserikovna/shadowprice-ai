class ChatMessageModel {
  ChatMessageModel({
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessageModel.user(String content) {
    return ChatMessageModel(
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
    );
  }

  factory ChatMessageModel.assistant(String content) {
    return ChatMessageModel(
      role: 'assistant',
      content: content,
      createdAt: DateTime.now(),
    );
  }

  final String role;
  final String content;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
    };
  }
}

class ChatReply {
  ChatReply({
    required this.answer,
    required this.provider,
    required this.timestamp,
    this.model,
    this.suggestedQuestions = const [],
  });

  factory ChatReply.fromJson(Map<String, dynamic> json) {
    return ChatReply(
      answer: json['answer'] as String? ?? '',
      provider: json['provider'] as String? ?? 'rules',
      model: json['model'] as String?,
      suggestedQuestions: ((json['suggested_questions'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }

  final String answer;
  final String provider;
  final String? model;
  final List<String> suggestedQuestions;
  final DateTime timestamp;
}
