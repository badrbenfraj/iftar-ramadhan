# Cards per region, code-only sign-up, printable cards: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** the same card number can be registered in several regions; the only way into a region is its join code, with optional approval; organizers get a ready-to-print card PDF from `/download`.

**Architecture:**
- People get a composite key `(regionId, id)`. Meal events reference that key. Every service lookup by card number adds the region.
- Sign-up resolves the region from the join code. A new region column, `approveNewVolunteers`, decides between a pending and an active account.
- A static HTML page (maintainer tool) renders the card sheets. Edge in headless mode prints them to a PDF once. The PDF is committed and served by the API at `/download/cards.pdf`.

**Tech stack:** NestJS 12 + TypeORM 1.x + PostgreSQL 16; Flutter 3.47 (Riverpod 3, go_router); plain HTML with the vendored `qrcode-generator` 1.4.4.

**Spec:** `docs/superpowers/specs/2026-10-12-region-cards-and-signup-design.md`

## Global constraints

- **No tests:** don't write, edit or run tests (the owner's preference). Verify with `npm run build` and `npm run lint` in `apps/backend`, and `flutter analyze` in `apps/mobile` through Docker (the `flutter-docker` skill). Add the manual checks listed below.
- **Translations:** every user-facing string goes into `apps/mobile/lib/l10n/app_{en,fr,ar}.arb` (the `add-translation` skill). No hard-coded strings in widgets.
- **No API name changes:** `id` stays the card number in every API payload and in the app model.
- **Migrations:** new files in `apps/backend/migrations/`, timestamped `1791700000000` and `1791800000000`. Each has a `down()`.
- **Commits:** end each message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never commit `apps/mobile/config/local.json`.
- **Docs:** README Features is updated whenever a feature changes (the owner's rule).

## Review focus

1. **The same card number on the same night in two regions:** both serves must succeed, while a second serve in the same region gets a 409.
2. **The global admin's "every region" list with the same number twice:** each row must open its own person, with the right meal-today state. This is the `todayMealsByRegion` map key.
3. **Offline sync or a confirm retry with a reused `clientEventId` for the same number in another region:** it must be rejected as reused, never treated as a duplicate.
4. **Sign-up with a code from a closed region or a turned-off code:** the same "invalid code" as an unknown code.
5. **Logging in with an account that's still pending:** the waiting page still works without a region name (generic text).

---

### Task 1: Backend — people keyed by region and card number

**Files:**
- Create: `apps/backend/migrations/1791700000000-PersonKeyPerRegion.ts`
- Modify: `apps/backend/src/fasting/entities/fasting.entity.ts`, `apps/backend/src/fasting/entities/meal-event.entity.ts`, `apps/backend/src/fasting/repositories/fasting.repository.ts`, `apps/backend/src/fasting/services/meal-event.service.ts`, `apps/backend/src/fasting/services/fasting.service.ts`, `apps/backend/src/fasting/dtos/fasting-input.dto.ts`, `deploy/local/seed.sql`, `docs/LOCAL_DEVELOPMENT.md`

**Interfaces**
- Produces:
  - `Fasting.regionId: number`, part of the primary key.
  - `personKey(regionId: number, id: number): string`, exported from `meal-event.service.ts`.
  - `MealEventService.todayMealOf(regionId, fastingId)`, `mealsOf(regionId, fastingId)` and `activeEventOn(manager, regionId, fastingId, serviceDay)`.
  - `todayMealsByRegion()` returns a `Map<string, MealEventOutput>` keyed by `personKey`.

- [ ] **Step 1: Migration.** Write the migration:

```ts
import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Every region prints the same card numbers, so a person is identified by
 * (region, card number). Meal events point to that pair, and "one meal per
 * night" is per person of a region.
 */
export class PersonKeyPerRegion1791700000000 implements MigrationInterface {
  name = 'PersonKeyPerRegion1791700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "meal_events" DROP CONSTRAINT "FK_meal_events_fasting"`,
    );
    await queryRunner.query(`DROP INDEX "UQ_meal_events_active_day"`);
    await queryRunner.query(`DROP INDEX "IDX_meal_events_fasting_served"`);
    await queryRunner.query(
      `ALTER TABLE "fastings" DROP CONSTRAINT "PK_33563b1cc12321877ca97148150"`,
    );
    await queryRunner.query(
      `ALTER TABLE "fastings" ADD CONSTRAINT "PK_fastings_region_card" PRIMARY KEY ("regionId", "id")`,
    );
    await queryRunner.query(
      `ALTER TABLE "meal_events" ADD CONSTRAINT "FK_meal_events_fasting" FOREIGN KEY ("regionId", "fastingId") REFERENCES "fastings"("regionId", "id") ON DELETE CASCADE`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_meal_events_active_day" ON "meal_events" ("regionId", "fastingId", "serviceDay") WHERE "revokedAt" IS NULL AND "conflict" = false`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_meal_events_fasting_served" ON "meal_events" ("regionId", "fastingId", "servedAt")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "IDX_meal_events_fasting_served"`);
    await queryRunner.query(`DROP INDEX "UQ_meal_events_active_day"`);
    await queryRunner.query(
      `ALTER TABLE "meal_events" DROP CONSTRAINT "FK_meal_events_fasting"`,
    );
    await queryRunner.query(
      `ALTER TABLE "fastings" DROP CONSTRAINT "PK_fastings_region_card"`,
    );
    // Fails if a card number is now used in two regions: intended.
    await queryRunner.query(
      `ALTER TABLE "fastings" ADD CONSTRAINT "PK_33563b1cc12321877ca97148150" PRIMARY KEY ("id")`,
    );
    await queryRunner.query(
      `ALTER TABLE "meal_events" ADD CONSTRAINT "FK_meal_events_fasting" FOREIGN KEY ("fastingId") REFERENCES "fastings"("id") ON DELETE CASCADE`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_meal_events_active_day" ON "meal_events" ("fastingId", "serviceDay") WHERE "revokedAt" IS NULL AND "conflict" = false`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_meal_events_fasting_served" ON "meal_events" ("fastingId", "servedAt")`,
    );
  }
}
```

- [ ] **Step 2: Entities.** In `fasting.entity.ts`, replace the `id` and `region` members (import `JoinColumn`):

```ts
  /** The number printed on the card: unique within a region only. */
  @PrimaryColumn()
  id: number;

  @PrimaryColumn()
  regionId: number;

  @ManyToOne(() => Region, (region) => region.fastingPeople)
  @JoinColumn([
    { name: 'regionId', referencedColumnName: 'id' },
    { name: 'regionName', referencedColumnName: 'name' },
  ])
  region: Region;
```

In `meal-event.entity.ts`:
- Change the indexes to `@Index('UQ_meal_events_active_day', ['regionId', 'fastingId', 'serviceDay'], { unique: true, where: ... })` and `@Index('IDX_meal_events_fasting_served', ['regionId', 'fastingId', 'servedAt'])`.
- Change the relation join to `@JoinColumn([{ name: 'regionId', referencedColumnName: 'regionId' }, { name: 'fastingId', referencedColumnName: 'id' }])`.
- Update the `regionId` comment: it is the person's region (the key), with no foreign key to `regions`.

- [ ] **Step 3: Repository.** In `fasting.repository.ts`:
  - `getFastingsByRegion`: `where: regionId === null ? {} : { regionId }`, `order: { regionId: 'ASC', id: 'ASC' }`.
  - `getByIdAndRegion`: `where: { id, regionId }`.

- [ ] **Step 4: MealEventService.** In `meal-event.service.ts`, add the following below the imports:

```ts
/** A person's key in maps: card numbers repeat across regions. */
export const personKey = (regionId: number, id: number): string =>
  `${regionId}:${id}`;
```

Then make these changes:
- `confirm`:
  - `manager.findOne(Fasting, { where: { id: fastingId, regionId: region }, ... })`.
  - The reuse check becomes `existing.fastingId !== fastingId || existing.regionId !== region`.
  - Call `this.activeEventOn(manager, region, fastingId, ...)`.
- `syncOne`:
  - Both reuse checks become `(stored|existing).fastingId !== event.fastingId || (stored|existing).regionId !== event.regionId`.
  - `activeEventOn(..., stored.regionId, stored.fastingId, stored.serviceDay)` and `activeEventOn(manager, event.regionId, event.fastingId, serviceDay)`.
  - The dual-write `UPDATE "fastings" ... WHERE "id" = $1 AND "regionId" = $4` gets the parameter `event.regionId` added.
- `activeEventOn(manager, regionId: number, fastingId: number, serviceDay: string)`: `WHERE e."regionId" = $1 AND e."fastingId" = $2 AND e."serviceDay" = $3 ...`.
- `todayMealsByRegion`: `new Map(rows.map((row) => [personKey(row.regionId, row.fastingId), toMealEventOutput(row)]))`. The return type is `Map<string, MealEventOutput>`. Delete the duplicated doc comment line.
- `todayMealOf(regionId: number, fastingId: number, now = new Date())`.
- `mealsOf(regionId: number, fastingId: number)`: `WHERE e."regionId" = $1 AND e."fastingId" = $2 AND ...`.
- `reviewItems`: `JOIN "fastings" f ON f."id" = e."fastingId" AND f."regionId" = e."regionId"`.
- `revoke`: the lock becomes `SELECT "id" FROM "fastings" WHERE "id" = $1 AND "regionId" = $2 FOR UPDATE` with `[found.fastingId, found.regionId]`.
- `removeFromHistory`: all three queries filter by both `"id"` (or `"fastingId"`) and `"regionId"`, using `event.regionId`.

- [ ] **Step 5: FastingService and DTO.** In `fasting.service.ts`:
  - `createFasting`: `findOne({ where: { id: input.id, regionId: user.region.id } })`. Set `fasting.regionId = user.region.id;` next to `fasting.region = ...`. The 409 message becomes `` `A person with ID ${input.id} already exists in this region` ``. Call `todayMealOf(savedFasting.regionId, savedFasting.id)`.
  - `getFastingsByRegion`: `today.get(personKey(f.regionId, f.id))`. Import `personKey`.
  - `getFastingById`: `mealsOf(fasting.regionId, fasting.id)` and `todayMealOf(fasting.regionId, fasting.id)`.
  - `updateFasting`:
    - Delete the whole "target region" block (`const target = input.region?.id; ...`).
    - Drop `region: _region` from the destructuring.
    - `this.repository.update({ id: fasting.id, regionId: region }, columns)`.
    - Re-read with `getByIdAndRegion(fastingId, region)`.
    - `todayMealOf(region, savedFasting.id)`.
  - `revokeMeal`: `todayMealOf(regionId, fastingId)`.
  - Remove imports that are now unused (`isGlobalAdmin`, `NotFoundException` if unused; `npm run lint` tells you).

  In `fasting-input.dto.ts`, delete the `region?: RegionRefInput` member of `UpdateFastingInput` and its comment. Keep `RegionRefInput` only if something else uses it, and grep first. With `whitelist: true`, older apps that still send `region` have it silently stripped.

- [ ] **Step 6: Seed.** In `deploy/local/seed.sql`, give both regions overlapping numbers. Replace the `people` CTE and the `INSERT` tail:

```sql
), people AS (
  SELECT id, id AS k, 'Dar Sokra' AS region FROM generate_series(1, 40) AS s(id)
  UNION ALL
  SELECT id, id + 100 AS k, 'Dar Sousse' FROM generate_series(1, 15) AS s(id)
)
```

In the `SELECT`, use `p.k` instead of `p.id` in every name, phone, comment, meal and CIN expression (keep `p.id` as the inserted `id`). End with `ON CONFLICT ("regionId", id) DO NOTHING;`.

In `docs/LOCAL_DEVELOPMENT.md` line 77, change the sentence to: "Fasting people: card numbers **1–40** in Dar Sokra and **1–15** in Dar Sousse (the same numbers in both regions, as with real cards), none…" (keep the rest of the line).

- [ ] **Step 7: Verify.** Run `cd apps/backend && npm run build && npm run lint`. Expected: no errors.

- [ ] **Step 8: Manual check on the local stack** (the `run-local` skill: `deploy/local/up.sh`; reseed with a fresh volume if needed). Log in as `admin`, then call:
  - `PATCH /api/v1/fastings/confirm/<sokraId>/1` → 200
  - `PATCH /api/v1/fastings/confirm/<sousseId>/1` → 200
  - `PATCH /api/v1/fastings/confirm/<sokraId>/1` again → 409 `MEAL_ALREADY_TAKEN`
  - `GET /api/v1/fastings` → two entries with `id` 1, each with its own `todayMeal`

- [ ] **Step 9: Commit:** `feat: a card number is unique per region, not globally`.

### Task 2: Mobile — person screens carry the region

**Files:**
- Modify: `apps/mobile/lib/features/people/presentation/people_controller.dart`, `person_details_page.dart`, `person_form_page.dart`, `people_list_page.dart`, `apps/mobile/lib/core/router/app_router.dart`

**Interfaces**
- Produces:
  - `typedef PersonKey = ({int regionId, int id});`
  - `personDetailsProvider` is a family keyed by `PersonKey`.
  - Routes `/people/:id?region=<regionId>` and `/people/:id/edit?region=<regionId>`, where `region` is optional and defaults to the user's own region.

- [ ] **Step 1: Controller.** In `people_controller.dart`:
  - Add `typedef PersonKey = ({int regionId, int id});`.
  - `PersonDetailsController(this.key)` with `final PersonKey key;`.
  - `build()` → `ref.read(peopleRepositoryProvider).get(key.regionId, key.id)`.
  - `confirmMeal` uses `key.regionId` and `key.id`.
  - The provider becomes `.family<PersonDetailsController, FastingPerson, PersonKey>`.
  - Delete `personRegion()`.
  - Add:

```dart
/// The person a details route points to: [regionId] from the `region`
/// query parameter (a global admin browsing another region), else the
/// user's own region.
PersonKey personKeyFor(WidgetRef ref, int id, int? regionId) =>
    (regionId: regionId ?? regionOf(ref.read(authControllerProvider)).id, id: id);

/// Route to a person's details; [regionId] only when it isn't the user's own.
String personPath(int id, {int? regionId, bool edit = false}) =>
    '/people/$id${edit ? '/edit' : ''}${regionId == null ? '' : '?region=$regionId'}';
```

- [ ] **Step 2: Router.** In `app_router.dart`, both routes read `int.tryParse(state.uri.queryParameters['region'] ?? '')` and pass it as `regionId:` to `PersonDetailsPage` and `EditPersonPage`.

- [ ] **Step 3: Pages.**
  - `PersonDetailsPage` and `EditPersonPage` get `final int? regionId;` (an optional constructor parameter).
  - In each, replace `personDetailsProvider(widget.personId)` with `personDetailsProvider(personKeyFor(ref, widget.personId, widget.regionId))`. In `EditPersonPage`, use `personId` and `regionId` directly.
  - The edit button in the details page pushes `personPath(widget.personId, regionId: widget.regionId, edit: true)`.
  - In `person_form_page.dart` line 254, replace `ref.invalidate(personDetailsProvider(saved.id))` with `ref.invalidate(personDetailsProvider)`. The PATCH body there drops `'region': region.toJson()` (in `people_repository.dart` `update`). The URL already carries the region.

- [ ] **Step 4: List.** In `people_list_page.dart` line 337, use `onTap: () => context.push(personPath(filtered[i].id, regionId: browsingOther ? filtered[i].region?.id : null))`. The scan panels and the duplicate-CIN link stay on the user's own region, so they're unchanged.

- [ ] **Step 5: Verify.** Run `flutter analyze` through Docker. Expected: "No issues found!".

- [ ] **Step 6: Commit:** `feat(mobile): person screens know the person's region`.

### Task 3: Backend — sign-up by join code only

**Files:**
- Create: `apps/backend/migrations/1791800000000-CodeOnlySignUp.ts`, `apps/backend/src/region/dtos/approval-input.dto.ts`
- Modify:
  - `apps/backend/src/region/entities/region.entity.ts`, `src/region/dtos/join-code-output.dto.ts`, `src/region/services/region.service.ts`, `src/region/controllers/region.controller.ts`
  - `src/auth/dtos/auth-register-input.dto.ts`, `src/auth/services/auth.service.ts`
  - `src/user/entities/user.entity.ts`, `src/user/dtos/user-create-input.dto.ts`, `src/user/dtos/user-output.dto.ts`
  - The spec (endpoint verb)

**Interfaces**
- Produces:
  - `GET`, `POST` and `DELETE /regions/:id/join-code` return `{ joinCode: string | null, approveNewVolunteers: boolean }`.
  - `POST /regions/:id/approval` with the body `{ approveNewVolunteers: boolean }` returns the same shape.
  - `POST /auth/register` requires `joinCode`; there is no `region` field.
  - `GET /regions` is removed.

- [ ] **Step 1: Migration.**

```ts
import { MigrationInterface, QueryRunner } from 'typeorm';

/** Sign-up only with a region's code; each region decides on approval. */
export class CodeOnlySignUp1791800000000 implements MigrationInterface {
  name = 'CodeOnlySignUp1791800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "regions" ADD "approveNewVolunteers" boolean NOT NULL DEFAULT true`,
    );
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "joinedWithCode"`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" ADD "joinedWithCode" boolean NOT NULL DEFAULT false`,
    );
    await queryRunner.query(
      `ALTER TABLE "regions" DROP COLUMN "approveNewVolunteers"`,
    );
  }
}
```

- [ ] **Step 2: Entities and DTOs.**
  - `region.entity.ts`: after `joinCode`, add:

    ```ts
      /** New volunteers who sign up with the code wait for approval. */
      @Column({ default: true })
      approveNewVolunteers: boolean;
    ```

  - Delete `joinedWithCode` from `user.entity.ts`, `user-create-input.dto.ts` and `user-output.dto.ts`, and from `NewAccount` in `auth-register-input.dto.ts`.
  - `join-code-output.dto.ts`: add `@ApiProperty() approveNewVolunteers: boolean;`.
  - `approval-input.dto.ts`:

    ```ts
    import { ApiProperty } from '@nestjs/swagger';
    import { IsBoolean } from 'class-validator';

    export class ApprovalInput {
      @ApiProperty()
      @IsBoolean()
      approveNewVolunteers: boolean;
    }
    ```

- [ ] **Step 3: Register.** In `RegisterInput`:
  - Delete `RegisterRegionInput` and the `region` member.
  - `joinCode` becomes `@ApiProperty({ example: 'NOUR-482193' }) @IsString() @IsNotEmpty() @MaxLength(32) joinCode: string;`.
  - Update the class comment: "The join code picks the region; the region decides whether the account waits for approval."

  In `AuthService.register`, replace the region block and the status with:

```ts
    const region = await this.regionRepository.findActiveByJoinCode(
      normalizeJoinCode(input.joinCode.trim()),
    );
    // Unknown, turned-off and closed-region codes look the same.
    if (!region) {
      throw new BadRequestException({
        message: 'This join code is not valid',
        code: AUTH_ERROR_CODES.INVALID_JOIN_CODE,
      });
    }

    const account: NewAccount = {
      name: input.name,
      username: input.username,
      password: input.password,
      email: input.email,
      roles: [ROLE.USER],
      status: region.approveNewVolunteers
        ? USER_STATUS.PENDING
        : USER_STATUS.ACTIVE,
      region,
    };
```

Remove the imports that are now unused (`NotFoundException`, `Region` if unused).

- [ ] **Step 4: Region service and controller.**
  - `getJoinCode`, `newJoinCode` and `turnOffJoinCode` return `{ joinCode, approveNewVolunteers: region.approveNewVolunteers }`. `newJoinCode` and `turnOffJoinCode` keep the `region` returned by `regionForAdmin`.
  - Add:

    ```ts
      /** Coordinators and global admins: approval of new sign-ups on or off. */
      async setApproval(
        ctx: RequestContext,
        id: number,
        approveNewVolunteers: boolean,
      ): Promise<JoinCodeOutput> {
        const region = await this.regionForAdmin(ctx, id);
        await this.repository.update({ id }, { approveNewVolunteers });
        return { joinCode: region.joinCode ?? null, approveNewVolunteers };
      }
    ```

  - Controller: delete the public `@Get()` `getRegions` handler. Delete `RegionService.getRegions` if nothing else calls it (grep). Add, next to the join-code routes:

    ```ts
      @Post(':id/approval')
      @HttpCode(HttpStatus.OK)
      @UseGuards(JwtAuthGuard)
      @ApiBearerAuth()
      async setApproval(
        @ReqContext() ctx: RequestContext,
        @Param('id', ParseIntPipe) id: number,
        @Body() input: ApprovalInput,
      ): Promise<BaseApiResponse<JoinCodeOutput>> {
        return {
          data: await this.regionService.setApproval(
            ctx,
            id,
            input.approveNewVolunteers,
          ),
          meta: {},
        };
      }
    ```

  - Remove the now-unused imports (`PaginationParamsDto`, `PublicRegionOutput` from the controller only).

- [ ] **Step 5: Spec.** Change `PUT /regions/:id/approval` to `POST /regions/:id/approval` in the spec, because the app's API client has no PUT and the other region actions are POSTs.

- [ ] **Step 6: Verify:** `npm run build && npm run lint`.

- [ ] **Step 7: Manual check (local stack):**
  - `GET /api/v1/regions` → 404.
  - Register with `NOUR-111111` → `status: "pending"`.
  - Log in as the Sokra coordinator. `POST /api/v1/regions/<sokraId>/approval {"approveNewVolunteers":false}`, then register again → `status: "active"`.
  - Register with `WRONG-000000` → 400 `INVALID_JOIN_CODE`.

- [ ] **Step 8: Commit:** `feat: sign up only with a region's join code, approval per region`.

### Task 4: Mobile — sign-up without the region list, approval switch

**Files:**
- Modify:
  - `apps/mobile/lib/features/auth/data/auth_repository.dart`, `features/auth/presentation/register_page.dart`, `features/auth/presentation/pending_page.dart`
  - `core/router/app_router.dart`
  - `features/volunteers/data/volunteers_repository.dart`, `features/volunteers/presentation/volunteers_controller.dart`, `join_code_card.dart`, `volunteers_page.dart`, `features/volunteers/domain/volunteer.dart`
  - `lib/l10n/app_{en,fr,ar}.arb`

**Interfaces**
- Consumes: the endpoints from Task 3.
- Produces:
  - `register(...)` returns `({RegisterOutcome outcome, String? regionName})`.
  - `class JoinCodeInfo { final String? code; final bool approveNewVolunteers; }`.
  - `joinCodeProvider` is a `FutureProvider.autoDispose.family<JoinCodeInfo, int>`.

- [ ] **Step 1: Translations** (the `add-translation` skill). Add:

| key | en | fr | ar |
|---|---|---|---|
| `joinCodeRequired` | Enter your region's code | Saisissez le code de votre région | أدخل رمز منطقتك |
| `pendingBodyRegion` (placeholder `region`) | Your account is created. A coordinator of {region} must approve it before you can sign in. | Votre compte est créé. Un coordinateur de {region} doit l'approuver avant que vous puissiez vous connecter. | تم إنشاء حسابك. يجب أن يوافق عليه منسّق {region} قبل أن تتمكّن من تسجيل الدخول. |
| `approveNewVolunteers` | Approve new volunteers | Approuver les nouveaux bénévoles | الموافقة على المتطوّعين الجدد |
| `approveNewVolunteersHelp` | On: people who sign up with the code wait for your approval. Off: they start at once. | Activé : les inscrits avec le code attendent votre approbation. Désactivé : ils commencent tout de suite. | مفعّل: من يسجّل بالرمز ينتظر موافقتك. غير مفعّل: يبدأ فورًا. |

Change `joinCodeHelp` to: en "Ask your coordinator for your region's code."; fr "Demandez le code de votre région à votre coordinateur."; ar "اطلب رمز منطقتك من منسّقك.".

Delete `joinedWithCode`, `chooseRegion`, `loadingRegions`, `regionsFailed` and `regionRequired`, after grepping that the register page was their only user. Run `flutter gen-l10n` through Docker.

- [ ] **Step 2: Auth repository.**
  - `register({required String name, required String username, required String email, required String password, required String joinCode})` returns `Future<({RegisterOutcome outcome, String? regionName})>`.
  - The body always sends `'joinCode': joinCode.trim()`.
  - It returns `(outcome: ..., regionName: (envelope.object['region'] as Map?)?['name'] as String?)`.
  - Delete `RegionRepository`, `ApiRegionRepository` and `regionRepositoryProvider`.

- [ ] **Step 3: Register page.**
  - Delete `regionsProvider`, `_regionId`, `_hasCode`, the `_RegionPicker` usage and class, and the imports only they used.
  - The code field gets `validator: (v) => (v == null || v.trim().isEmpty) ? l.joinCodeRequired : null`.
  - Call `register(..., joinCode: _joinCode.text)`.
  - On a pending outcome: `context.go('/pending', extra: result.regionName)`.

- [ ] **Step 4: Waiting page.**
  - `PendingPage({super.key, this.regionName})` with `final String? regionName;`.
  - `lead: regionName == null ? l.pendingBody : l.pendingBodyRegion(regionName!)`.
  - Router: `GoRoute(path: '/pending', builder: (_, state) => PendingPage(regionName: state.extra as String?))`.

- [ ] **Step 5: Volunteers.** In `volunteers_repository.dart`:

```dart
/// A region's join code (null = off) and whether sign-ups wait for approval.
class JoinCodeInfo {
  const JoinCodeInfo({required this.code, required this.approveNewVolunteers});

  factory JoinCodeInfo.fromJson(Map<String, dynamic> json) => JoinCodeInfo(
    code: json['joinCode'] as String?,
    approveNewVolunteers: json['approveNewVolunteers'] != false,
  );

  final String? code;
  final bool approveNewVolunteers;
}
```

  - `joinCode(int)` returns `JoinCodeInfo.fromJson((await _api.get(...)).object)`.
  - `newJoinCode` and `turnOffJoinCode` keep their current return types.
  - Add `Future<void> setApproval(int regionId, bool value) => _api.post('/regions/$regionId/approval', body: {'approveNewVolunteers': value});`.
  - `joinCodeProvider` returns `JoinCodeInfo`.
  - In `JoinCodeCard`, `data: (info)` uses `info.code` where it used `value`. After the buttons `Wrap`, add:

```dart
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.approveNewVolunteers),
                  subtitle: Text(l.approveNewVolunteersHelp),
                  value: info.approveNewVolunteers,
                  onChanged: (on) =>
                      _run(context, ref, () => repo.setApproval(regionId, on)),
                ),
```

  - Remove the `joinedWithCode` field from `volunteer.dart` and the tag line in `volunteers_page.dart:275`.

- [ ] **Step 6: Verify:** `flutter analyze` through Docker.

- [ ] **Step 7: Commit:** `feat(mobile): sign up with a code only; approval switch for coordinators`.

### Task 5: Printable cards

**Files:**
- Create:
  - `packages/card-sheet/index.html`
  - `packages/card-sheet/qrcode.js` (vendored)
  - `packages/card-sheet/LICENSE-qrcode-generator.txt`
  - `apps/backend/assets/cards/iftar-cards-1-2000.pdf` (generated)
- Modify:
  - `apps/backend/src/app-release/download.controller.ts`, `src/app-release/download-page.ts`, `src/main.ts`
  - `apps/backend/Dockerfile`
  - `packages/README.md`
- Delete: `packages/qrcode-gen/` (untracked)

- [ ] **Step 1: Vendor the QR library.** In the scratchpad, run `npm pack qrcode-generator@1.4.4`, extract it, copy `package/qrcode.js` to `packages/card-sheet/qrcode.js`, and copy its `LICENSE` to `LICENSE-qrcode-generator.txt`. Don't run any of its scripts.

- [ ] **Step 2: The page.** Write `packages/card-sheet/index.html`:
  - A form with From and To (defaulting to `?from=` and `?to=`, otherwise 1 and 100), a "N cards · P pages" line, a Print button and instructions.
  - Each card is an SVG drawn from `qr.isDark(r, c)` for a `qrcode(0, 'H')` holding `String(n)`.
  - `@page { size: A4; margin: 0 }`. Sheets are 210×297 mm with 8 mm padding and a 5×5 grid. Cards are 38.8×56.2 mm with a dashed `#bbb` border, a 30 mm QR and the number at 22 pt bold.
  - `@media print { form, .help { display: none } }`.
  - Validation: integers, `1 ≤ from ≤ to ≤ 2147483647`, `to − from < 2000`.

- [ ] **Step 3: Generate the PDF.**

```bash
"/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" --headless --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="$(pwd -W)/apps/backend/assets/cards/iftar-cards-1-2000.pdf" \
  "file:///$(pwd -W)/packages/card-sheet/index.html?from=1&to=2000"
```

Check the result: 80 pages; page 1 holds cards 1–25; page 80 holds cards 1976–2000. Spot-check one QR by scanning it with a phone, and confirm it reads `42`.

- [ ] **Step 4: Serve it.**
  - `Dockerfile` runtime stage: add `COPY --from=builder /usr/src/app/assets ./assets`.
  - `main.ts`: `exclude: ['download', 'download/cards.pdf']`.
  - `download.controller.ts`:

```ts
  /** The printable cards (same numbers in every region). */
  @Get('cards.pdf')
  @Header('Content-Type', 'application/pdf')
  @Header('Content-Disposition', 'inline; filename="iftar-cards-1-2000.pdf"')
  @Header('Cache-Control', 'public, max-age=86400')
  cards(): StreamableFile {
    return new StreamableFile(
      createReadStream(join(process.cwd(), 'assets/cards/iftar-cards-1-2000.pdf')),
    );
  }
```

  - `download-page.ts`: after the iPhone section, add a `cards` section with a `.button.secondary` link to `/download/cards.pdf` ("Cards to print · بطاقات للطباعة · Cartes à imprimer"). Include the note: "25 cards per page. 100 cards: print pages 1–4; 500 cards: pages 1–20. Need more later? Print the next pages." in English, Arabic (`dir="rtl"`) and French.

- [ ] **Step 5: Docs.**
  - `packages/README.md`: what `card-sheet` is and how to regenerate the PDF (the Step 3 command).
  - Delete `packages/qrcode-gen`.

- [ ] **Step 6: Verify.** Run `npm run build && npm run lint`. On the local stack, `GET /download/cards.pdf` returns 200 `application/pdf`, and `/download` shows the cards link.

- [ ] **Step 7: Commit:** `feat: ready-to-print cards on the download page`.

### Task 6: README and final verification

- [ ] **Step 1: README.**
  - Features → "Regions and roles": replace "Volunteers join with a region code or wait for approval" with "Volunteers join only with their region's code; each region chooses whether new volunteers wait for the coordinator's approval. The list of regions is never shown publicly."
  - Add to Features: "**Printable cards.** One PDF of numbered QR cards (1–2000) on the download page; every region prints the pages it needs, and the same numbers can be used in every region."
  - "Use it for your organization": add step "Print cards from `/download`".
- [ ] **Step 2:** Run the full verification: `npm run build`, `npm run lint` and `flutter analyze`.
- [ ] **Step 3: Commit:** `docs: README for code-only sign-up and printable cards`.
