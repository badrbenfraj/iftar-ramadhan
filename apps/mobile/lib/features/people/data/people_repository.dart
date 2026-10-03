import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../auth/domain/user.dart';
import '../domain/fasting_person.dart';
import '../domain/person_draft.dart';

abstract interface class PeopleRepository {
  Future<List<FastingPerson>> list(int regionId);
  Future<FastingPerson> get(int regionId, int id);
  Future<FastingPerson> create(int regionId, PersonDraft draft);
  Future<FastingPerson> update(Region region, PersonDraft draft);
  Future<void> delete(int regionId, int id);

  /// Records today's meal. Throws `MealAlreadyTakenFailure` when the server
  /// says the person already collected today.
  Future<FastingPerson> confirmMeal(
    int regionId,
    int id, {
    String? phone,
    String? comment,
  });
}

class ApiPeopleRepository implements PeopleRepository {
  ApiPeopleRepository(this._api, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ApiClient _api;
  final DateTime Function() _clock;

  /// Stamps the answer's arrival: the served flag is only good for that day.
  FastingPerson _person(Map<String, dynamic> json) =>
      FastingPerson.fromJson(json, receivedAt: _clock());

  static const _pageSize = 500;

  @override
  Future<List<FastingPerson>> list(int regionId) async {
    final people = <FastingPerson>[];
    var offset = 0;
    while (true) {
      final envelope = await _api.get(
        '/fastings/$regionId',
        query: {'limit': _pageSize, 'offset': offset},
      );
      final page = envelope.list.map(_person).toList();
      people.addAll(page);
      final total = (envelope.meta['count'] as num?)?.toInt();
      offset += page.length;
      if (page.length < _pageSize || (total != null && offset >= total)) break;
    }
    return people..sort((a, b) => a.id.compareTo(b.id));
  }

  @override
  Future<FastingPerson> get(int regionId, int id) async {
    final envelope = await _api.get('/fastings/$regionId/$id');
    return _person(envelope.object);
  }

  @override
  Future<FastingPerson> create(int regionId, PersonDraft draft) async {
    final envelope = await _api.post(
      '/fastings',
      body: {
        'id': draft.id,
        'firstName': draft.firstName.trim(),
        'lastName': draft.lastName.trim(),
        'cin': ?_opt(draft.cin),
        'phone': ?_opt(draft.phone),
        'comment': ?_opt(draft.comment),
        'singleMeal': draft.singleMeal,
        'familyMeal': draft.familyMeal,
        'region': regionId,
        'cameToday': draft.cameToday,
      },
    );
    return _person(envelope.object);
  }

  @override
  Future<FastingPerson> update(Region region, PersonDraft draft) async {
    final envelope = await _api.patch(
      '/fastings/${region.id}/${draft.id}',
      body: {
        'firstName': draft.firstName.trim(),
        'lastName': draft.lastName.trim(),
        // null clears the field on the server.
        'cin': _opt(draft.cin),
        'phone': _opt(draft.phone),
        'comment': _opt(draft.comment),
        'singleMeal': draft.singleMeal,
        'familyMeal': draft.familyMeal,
        'region': region.toJson(),
      },
    );
    return _person(envelope.object);
  }

  @override
  Future<void> delete(int regionId, int id) async {
    await _api.delete('/fastings/$regionId/$id');
  }

  @override
  Future<FastingPerson> confirmMeal(
    int regionId,
    int id, {
    String? phone,
    String? comment,
  }) async {
    final envelope = await _api.patch(
      '/fastings/confirm/$regionId/$id',
      body: {'phone': ?phone?.trim(), 'comment': ?comment?.trim()},
    );
    return _person(envelope.object);
  }

  static String? _opt(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

final peopleRepositoryProvider = Provider<PeopleRepository>(
  (ref) => ApiPeopleRepository(
    ref.watch(apiClientProvider),
    clock: ref.watch(clockProvider),
  ),
);
