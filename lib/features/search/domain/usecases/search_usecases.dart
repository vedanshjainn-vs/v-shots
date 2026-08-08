// ════════════════════════════════════════════════
// Project Lyra — Search Use Cases
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/search_entities.dart';
import '../repositories/search_repository.dart';

class SearchContent implements UseCase<SearchResult, SearchContentParams> {
  const SearchContent(this.repository);
  final SearchRepository repository;
  @override
  Future<Either<Failure, SearchResult>> call(SearchContentParams params) =>
      repository.search(params.query, filter: params.filter, page: params.page, limit: params.limit);
}

class SearchContentParams extends Equatable {
  const SearchContentParams({required this.query, this.filter, this.page = 1, this.limit = 20});
  final String query;
  final String? filter;
  final int page;
  final int limit;
  @override
  List<Object?> get props => [query, filter, page, limit];
}

class GetSearchSuggestions implements UseCase<List<SearchSuggestion>, String> {
  const GetSearchSuggestions(this.repository);
  final SearchRepository repository;
  @override
  Future<Either<Failure, List<SearchSuggestion>>> call(String query) =>
      repository.getSuggestions(query);
}

class GetRecentSearches implements UseCase<List<RecentSearch>, NoParams> {
  const GetRecentSearches(this.repository);
  final SearchRepository repository;
  @override
  Future<Either<Failure, List<RecentSearch>>> call(NoParams params) =>
      repository.getRecentSearches();
}

class SaveRecentSearch implements UseCaseVoid<String> {
  const SaveRecentSearch(this.repository);
  final SearchRepository repository;
  @override
  Future<Either<Failure, void>> call(String query) => repository.saveRecentSearch(query);
}

class ClearRecentSearches implements UseCaseVoid<NoParams> {
  const ClearRecentSearches(this.repository);
  final SearchRepository repository;
  @override
  Future<Either<Failure, void>> call(NoParams params) => repository.clearRecentSearches();
}
