// ════════════════════════════════════════════════
// Project Lyra — API Response Wrapper
// ════════════════════════════════════════════════
//
// Standardized API response envelope.
// All API responses are wrapped in this type
// for consistent error handling and data extraction.
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_response.freezed.dart';
part 'api_response.g.dart';

/// Wraps all API responses in a standardized envelope.
///
/// Handles success/error states, pagination metadata,
/// and ETag support for conditional requests.
@freezed
class ApiResponse<T> with _$ApiResponse<T> {
  const factory ApiResponse.success({
    required T data,
    ApiResponseMeta? meta,
    String? etag,
  }) = ApiResponseSuccess<T>;

  const factory ApiResponse.error({
    required ApiError error,
    ApiResponseMeta? meta,
  }) = ApiResponseError<T>;

  const factory ApiResponse.loading({
    ApiResponseMeta? meta,
  }) = ApiResponseLoading<T>;
}

/// Metadata attached to API responses.
@freezed
class ApiResponseMeta with _$ApiResponseMeta {
  const factory ApiResponseMeta({
    String? requestId,
    String? timestamp,
    int? statusCode,
    Map<String, String>? headers,
    PaginationMeta? pagination,
  }) = _ApiResponseMeta;

  factory ApiResponseMeta.fromJson(Map<String, dynamic> json) =>
      _$ApiResponseMetaFromJson(json);
}

/// Pagination metadata for list endpoints.
@freezed
class PaginationMeta with _$PaginationMeta {
  const factory PaginationMeta({
    required int page,
    required int limit,
    required int totalItems,
    required int totalPages,
    @Default(false) bool hasNextPage,
    @Default(false) bool hasPreviousPage,
    String? nextPageToken,
    String? previousPageToken,
  }) = _PaginationMeta;

  factory PaginationMeta.fromJson(Map<String, dynamic> json) =>
      _$PaginationMetaFromJson(json);
}

/// Standardized API error model.
@freezed
class ApiError with _$ApiError {
  const factory ApiError({
    required String message,
    String? code,
    int? statusCode,
    String? requestId,
    Map<String, dynamic>? details,
    @Default(false) bool isRetryable,
    @Default(false) bool isNetworkError,
    Duration? retryAfter,
  }) = _ApiError;

  factory ApiError.fromJson(Map<String, dynamic> json) =>
      _$ApiErrorFromJson(json);
}

/// Extension for mapping Dio responses to ApiResponse.
extension ApiResponseMapper on ApiResponse {
  /// Whether this response contains data.
  bool get hasData => this is ApiResponseSuccess;

  /// Whether this response is an error.
  bool get isError => this is ApiResponseError;

  /// Whether this response is loading.
  bool get isLoading => this is ApiResponseLoading;

  /// Extract data if success, null otherwise.
  T? get dataOrNull => switch (this) {
        ApiResponseSuccess(:final data) => data as T,
        _ => null,
      };

  /// Extract error if error, null otherwise.
  ApiError? get errorOrNull => switch (this) {
        ApiResponseError(:final error) => error,
        _ => null,
      };
}
