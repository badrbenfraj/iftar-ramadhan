import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    ProviderScope(
      // Riverpod 3 retries failing providers by default; network errors are
      // surfaced to the volunteer with an explicit "Try again" instead.
      retry: (_, _) => null,
      child: const IftarApp(),
    ),
  );
}
