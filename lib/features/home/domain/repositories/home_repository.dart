// ════════════════════════════════════════════════
// Project Lyra — Home Repository Interface
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/home_entities.dart';

typedef Result<T> = Either<Failure, T>;

abstract class HomeRepository {
  Future<Result<HomeFeed>> getFeed({bool forceRefresh = false});
  Future<Result<HomeFeed>> refreshFeed();
  Future<Result<List<HomeItem>>> getRecommendations({int limit = 20});
  Future<Result<List<HomeItem>>> getContinueListening();
  Future<Result<List<BannerItem>>> getBanners();
}
