// ════════════════════════════════════════════════
// Project Lyra — AI Types
// ════════════════════════════════════════════════
//
// Data models for AI services.
// All AI APIs return these standard types.
// ════════════════════════════════════════════════

/// Response from an AI service.
class AIResponse {
  const AIResponse({
    required this.content,
    this.model,
    this.usage,
    this.metadata = const {},
    this.isStreaming = false,
  });

  /// The generated text content.
  final String content;

  /// Which model generated this response.
  final String? model;

  /// Token usage information.
  final TokenUsage? usage;

  /// Additional metadata (confidence, sources, etc.).
  final Map<String, dynamic> metadata;

  /// Whether this is a partial streaming response.
  final bool isStreaming;
}

/// Token usage information.
class TokenUsage {
  const TokenUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
}

/// Error from an AI service.
class AIError implements Exception {
  const AIError({
    required this.message,
    this.code,
    this.isRetryable = false,
    this.statusCode,
  });

  final String message;
  final String? code;
  final bool isRetryable;
  final int? statusCode;

  @override
  String toString() => 'AIError: $message (code: $code)';
}

/// A message in a conversation.
class ConversationMessage {
  const ConversationMessage({
    required this.role,
    required this.content,
    this.name,
    this.metadata = const {},
  });

  final MessageRole role;
  final String content;
  final String? name;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'content': content,
        if (name != null) 'name': name,
      };

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      role: MessageRole.values.byName(json['role'] as String),
      content: json['content'] as String,
      name: json['name'] as String?,
    );
  }
}

/// Role of a message participant.
enum MessageRole {
  /// System prompt.
  system,

  /// User message.
  user,

  /// AI assistant response.
  assistant,
}

/// A prompt template with variable substitution.
class PromptTemplate {
  const PromptTemplate({
    required this.template,
    this.variables = const {},
    this.systemPrompt,
  });

  /// The template string with {variable} placeholders.
  final String template;

  /// Default variable values.
  final Map<String, String> variables;

  /// Optional system prompt.
  final String? systemPrompt;

  /// Render the template with variable substitution.
  String render(Map<String, String> values) {
    final allValues = {...variables, ...values};
    var result = template;
    for (final entry in allValues.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }
}

/// Semantic search result.
class SemanticSearchResult {
  const SemanticSearchResult({
    required this.id,
    required this.content,
    required this.score,
    this.metadata = const {},
  });

  final String id;
  final String content;
  final double score;
  final Map<String, dynamic> metadata;
}

/// Embedding vector for semantic operations.
class Embedding {
  const Embedding({
    required this.values,
    this.model,
  });

  final List<double> values;
  final String? model;

  int get dimensions => values.length;
}
