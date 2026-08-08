// ════════════════════════════════════════════════
// Project Lyra — AI Client
// ════════════════════════════════════════════════
//
// Abstract AI client interface.
// Implementations for OpenAI, Gemini, Claude, etc.
// All AI features use this unified interface.
// ════════════════════════════════════════════════

import '../models/ai_types.dart';

/// Abstract interface for AI services.
///
/// Implement this for each LLM provider (OpenAI, Gemini, etc.)
/// Features depend on this, not on specific providers.
///
/// ```dart
/// final response = await aiClient.complete(
///   messages: [ConversationMessage(role: MessageRole.user, content: 'Recommend songs')],
/// );
/// ```
abstract class AIClient {
  /// Generate a text completion.
  Future<AIResponse> complete({
    required List<ConversationMessage> messages,
    double? temperature,
    int? maxTokens,
    String? model,
  });

  /// Generate a streaming text completion.
  Stream<AIResponse> completeStream({
    required List<ConversationMessage> messages,
    double? temperature,
    int? maxTokens,
    String? model,
  });

  /// Generate embeddings for text.
  Future<Embedding> embed({
    required String text,
    String? model,
  });

  /// Generate embeddings for multiple texts.
  Future<List<Embedding>> embedBatch({
    required List<String> texts,
    String? model,
  });

  /// Perform semantic search against a vector store.
  Future<List<SemanticSearchResult>> semanticSearch({
    required String query,
    required String collectionId,
    int limit = 10,
    double? minScore,
  });

  /// Summarize text.
  Future<AIResponse> summarize({
    required String text,
    int? maxWords,
  });

  /// Translate text.
  Future<AIResponse> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  });
}

/// LLM provider types.
enum LLMProvider {
  openai,
  gemini,
  claude,
  custom,
}
