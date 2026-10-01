# packages/

Shared Dart packages for the monorepo.

There are none yet: there is only one Dart application (`apps/mobile`) and the
backend is TypeScript, so a shared package would add indirection without any
reuse. Candidates if a second Dart client appears (e.g. an admin/dashboard
app):

- `iftar_domain`: `FastingPerson`, `PersonRules`, `QrPayload`, `StatsPeriod`
  (today in `apps/mobile/lib/features/*/domain`, already free of Flutter imports)
- `iftar_api`: the Dio client, `AppFailure` mapping and repositories
