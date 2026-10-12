import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../auth/domain/user.dart';
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

  Future<void> changeRole(
    int id, {
    required String role,
    required int regionId,
  }) =>
      _api.patch('/users/$id/role', body: {'role': role, 'regionId': regionId});

  /// Global admins only; 409 REGION_NAME_TAKEN when the name is in use.
  Future<Region> createRegion(String name) async => Region.fromJson(
    (await _api.post(
      '/regions',
      body: {'name': name.trim(), 'active': true},
    )).object,
  );

  /// Global admins: every region, closed ones included.
  Future<List<Region>> listAllRegions() async =>
      (await _api.get('/regions/all')).list.map(Region.fromJson).toList();

  /// 409 REGION_NAME_TAKEN when another region has the name.
  Future<void> renameRegion(int id, String name) =>
      _api.patch('/regions/$id', body: {'name': name.trim()});

  Future<void> setOfflineServing(int id, {required bool allowed}) =>
      _api.patch('/regions/$id', body: {'allowOfflineServing': allowed});

  Future<RegionUsage> regionUsage(int id) async =>
      RegionUsage.fromJson((await _api.get('/regions/$id/usage')).object);

  /// Its volunteers are blocked, or all moved to [moveUsersTo].
  Future<void> closeRegion(int id, {int? moveUsersTo}) =>
      _api.post('/regions/$id/close', body: {'moveUsersTo': ?moveUsersTo});

  Future<void> reopenRegion(int id) => _api.post('/regions/$id/reopen');

  /// Empty regions only: 409 REGION_IN_USE otherwise.
  Future<void> deleteRegion(int id) => _api.delete('/regions/$id');

  Future<JoinCodeInfo> joinCode(int regionId) async => JoinCodeInfo.fromJson(
    (await _api.get('/regions/$regionId/join-code')).object,
  );

  Future<String?> newJoinCode(int regionId) async =>
      (await _api.post('/regions/$regionId/join-code')).object['joinCode']
          as String?;

  Future<void> turnOffJoinCode(int regionId) =>
      _api.delete('/regions/$regionId/join-code');

  /// Whether new volunteers who sign up with the code wait for approval.
  Future<void> setApproval(int regionId, bool approve) => _api.post(
    '/regions/$regionId/approval',
    body: {'approveNewVolunteers': approve},
  );
}

/// A region's join code (null = off: nobody can sign up) and whether new
/// volunteers wait for approval.
class JoinCodeInfo {
  const JoinCodeInfo({required this.code, required this.approveNewVolunteers});

  factory JoinCodeInfo.fromJson(Map<String, dynamic> json) => JoinCodeInfo(
    code: json['joinCode'] as String?,
    approveNewVolunteers: json['approveNewVolunteers'] != false,
  );

  final String? code;
  final bool approveNewVolunteers;
}

/// What still points to a region, shown before closing or deleting it.
class RegionUsage {
  const RegionUsage({
    required this.users,
    required this.people,
    required this.meals,
  });

  factory RegionUsage.fromJson(Map<String, dynamic> json) => RegionUsage(
    users: (json['users'] as num?)?.toInt() ?? 0,
    people: (json['people'] as num?)?.toInt() ?? 0,
    meals: (json['meals'] as num?)?.toInt() ?? 0,
  );

  final int users;
  final int people;
  final int meals;

  bool get isEmpty => users + people + meals == 0;
}

final volunteersRepositoryProvider = Provider<VolunteersRepository>(
  (ref) => VolunteersRepository(ref.watch(apiClientProvider)),
);
