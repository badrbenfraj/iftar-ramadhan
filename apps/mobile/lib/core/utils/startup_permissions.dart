import 'package:permission_handler/permission_handler.dart';

/// Runtime permissions the app needs, requested once at launch so volunteers
/// grant them up front instead of mid-distribution on the scan screen.
const _required = [Permission.camera];

Future<void> requestStartupPermissions() async {
  for (final permission in _required) {
    final status = await permission.status;
    // Permanently denied: the system dialog won't show again; the scan screen
    // explains how to re-enable it from settings.
    if (status.isGranted || status.isPermanentlyDenied) continue;
    await permission.request();
  }
}
