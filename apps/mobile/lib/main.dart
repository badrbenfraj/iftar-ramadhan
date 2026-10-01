import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    ProviderScope(
      // Riverpod 3 retries failing providers by default; network errors are
      // surfaced to the volunteer with an explicit "Try again" instead.
      retry: (_, _) => null,
      child: const IftarApp(),
    ),
  );
}
