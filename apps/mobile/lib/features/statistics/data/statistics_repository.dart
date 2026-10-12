import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/formatters.dart';
import '../domain/statistics.dart';

abstract interface class StatisticsRepository {
  /// [regionId] null = every region together (global admins only).
  Future<List<DailyStatistics>> fetch(
    int? regionId,
    DateTime from,
    DateTime to,
  );
}

class ApiStatisticsRepository implements StatisticsRepository {
  ApiStatisticsRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<DailyStatistics>> fetch(
    int? regionId,
    DateTime from,
    DateTime to,
  ) async {
    final envelope = await _api.get(
      regionId == null
          ? '/fastings/statistics'
          : '/fastings/statistics/$regionId',
      query: {'start': formatDayKey(from), 'end': formatDayKey(to)},
    );
    return envelope.list.map(DailyStatistics.fromJson).toList();
  }
}

final statisticsRepositoryProvider = Provider<StatisticsRepository>(
  (ref) => ApiStatisticsRepository(ref.watch(apiClientProvider)),
);
