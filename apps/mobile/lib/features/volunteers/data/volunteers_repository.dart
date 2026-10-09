import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../domain/volunteer.dart';

/// Security spec §4.3–4.4: account and join-code endpoints for admins.
class VolunteersRepository {
  VolunteersRepository(this._api);

  final ApiClient _api;

  /// Every account the caller may manage; a coordinator gets their region.
  Future<List<Volunteer>> list({int? regionId}) async {
    final envelope = await _api.get(
      '/users',
      query: {'limit': 500, 'offset': 0, 'regionId': ?regionId},
    );
    return envelope.list.map(Volunteer.fromJson).toList();
  }

  Future<void> approve(int id) => _api.post('/users/$id/approve');
  Future<void> refuse(int id) => _api.post('/users/$id/refuse');
  Future<void> disable(int id) => _api.post('/users/$id/disable');
  Future<void> enable(int id) => _api.post('/users/$id/enable');

  Future<void> changeRole(int id, {required String role, required int regionId}) =>
      _api.patch('/users/$id/role', body: {'role': role, 'regionId': regionId});

  Future<String?> joinCode(int regionId) async =>
      (await _api.get('/regions/$regionId/join-code')).object['joinCode']
          as String?;

  Future<String?> newJoinCode(int regionId) async =>
      (await _api.post('/regions/$regionId/join-code')).object['joinCode']
          as String?;

  Future<void> turnOffJoinCode(int regionId) =>
      _api.delete('/regions/$regionId/join-code');
}

final volunteersRepositoryProvider = Provider<VolunteersRepository>(
  (ref) => VolunteersRepository(ref.watch(apiClientProvider)),
);
