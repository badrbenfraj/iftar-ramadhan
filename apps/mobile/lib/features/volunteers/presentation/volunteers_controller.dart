import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/volunteers_repository.dart';
import '../domain/volunteer.dart';

/// The region the screen shows: the coordinator's own, or the one a global
/// admin picked (null = all regions, global admin only).
class SelectedRegion extends Notifier<int?> {
  @override
  int? build() {
    // Rebuild (and so reset the choice) when another account signs in.
    ref.watch(authControllerProvider.select((a) => a.value?.id));
    return ref.read(authControllerProvider).value?.region?.id;
  }

  void select(int? regionId) => state = regionId;
}

final selectedRegionProvider = NotifierProvider.autoDispose<SelectedRegion, int?>(
  SelectedRegion.new,
);

final volunteersProvider = FutureProvider.autoDispose<List<Volunteer>>((ref) {
  final user = ref.watch(authControllerProvider).value;
  final regionId = ref.watch(selectedRegionProvider);
  return ref
      .watch(volunteersRepositoryProvider)
      .list(regionId: user?.isAdmin == true ? regionId : null);
});

final joinCodeProvider = FutureProvider.autoDispose.family<String?, int>(
  (ref, regionId) => ref.watch(volunteersRepositoryProvider).joinCode(regionId),
);

/// Regions a global admin can pick from (the public list).
final adminRegionsProvider = FutureProvider.autoDispose<List<Region>>(
  (ref) => ref.watch(regionRepositoryProvider).listRegions(),
);
