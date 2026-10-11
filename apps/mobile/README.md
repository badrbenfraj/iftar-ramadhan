# Iftar Saim — mobile app (Flutter)

New computer (Docker only): [docs/LOCAL_DEVELOPMENT.md](../../docs/LOCAL_DEVELOPMENT.md).
Native setup, run, test and build commands: see the [root README](../../README.md#mobile-app-appsmobile).
Architecture and migration notes: [docs/MIGRATION_REPORT.md](../../docs/MIGRATION_REPORT.md).

```bash
flutter pub get
flutter run --dart-define-from-file=config/development.json
flutter analyze && flutter test
```
