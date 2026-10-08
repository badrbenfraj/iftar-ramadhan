import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'api_client.dart';

/// What a failed request says about the connection: true = the server
/// answered (with an error), false = it could not be reached, null = no
/// information (cancelled).
bool? reachedServer(DioException e) => switch (e.type) {
  DioExceptionType.badResponse => true,
  DioExceptionType.cancel => null,
  _ => false,
};

/// Whether the server is reachable, judged from real request outcomes
/// (spec 2A §5.5), with no connectivity plugin. While offline, `GET /health`
/// is tried every [probeEvery] so the app notices when the network is back.
class ConnectivityController extends Notifier<bool> {
  ConnectivityController({this.probeEvery = const Duration(seconds: 15)});

  final Duration probeEvery;
  Timer? _probe;

  @override
  bool build() {
    ref.onDispose(() => _probe?.cancel());
    return true;
  }

  void reportOnline() {
    _probe?.cancel();
    _probe = null;
    if (!state) state = true;
  }

  void reportOffline() {
    if (state) state = false;
    _probe ??= Timer.periodic(probeEvery, (_) => _probeOnce());
  }

  Future<void> _probeOnce() async {
    try {
      await ref.read(healthProbeProvider)();
      if (ref.mounted) reportOnline();
    } on Object {
      // Still offline.
    }
  }
}

final connectivityProvider = NotifierProvider<ConnectivityController, bool>(
  ConnectivityController.new,
);

/// One `GET /health` on its own client, outside the app's interceptors.
final healthProbeProvider = Provider<Future<void> Function()>((ref) {
  final options = ApiClient.baseOptions(ref.watch(appConfigProvider).apiBaseUrl)
    ..connectTimeout = const Duration(seconds: 5)
    ..receiveTimeout = const Duration(seconds: 5);
  final dio = Dio(options);
  ref.onDispose(dio.close);
  return () async {
    await dio.get<dynamic>('/health');
  };
});

/// Feeds every request outcome to [ConnectivityController].
class ConnectivityInterceptor extends Interceptor {
  ConnectivityInterceptor({required this.onOnline, required this.onOffline});

  final void Function() onOnline;
  final void Function() onOffline;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    onOnline();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (reachedServer(err)) {
      case true:
        onOnline();
      case false:
        onOffline();
      case null:
        break;
    }
    handler.next(err);
  }
}
