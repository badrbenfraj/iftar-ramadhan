# Security Fixes and Region Access Control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A volunteer can act only in their own region, new accounts get in only through a region join code or an admin's approval, no secret lives in git, a disabled account stops on its next request, and admins manage volunteers from the app.

**Architecture:** One pure `access-policy.ts` decides every right (global admin / regional admin / volunteer). A `RegionAccessGuard` applies it to every `:region` route; id-based routes call it from the service. The JWT strategies re-load the user from Postgres on every request, so role, region and status are always current and the token shape does not change. The Flutter app gains a join-code field, a "Waiting for approval" page and an admin-only Volunteers screen.

**Tech Stack:** NestJS 12, TypeORM 1.x, PostgreSQL 16, `@nestjs/throttler` 6 (already a dependency); Flutter 3.44 / Dart 3.12, Riverpod, go_router, dio, share_plus (already dependencies).

**Spec:** `docs/superpowers/specs/2026-10-09-security-region-access-design.md` (approved 2026-10-09).

## Global Constraints

- **No automated tests** (user rule "always ignore e2e and tests"). Each task is verified by backend `npm run build && npm run lint` and/or mobile `flutter gen-l10n && flutter analyze lib`, run in Docker (no SDK on the host). Do not write, fix or run tests.
- Backend check (from repo root, Git Bash):
  `MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W)/apps/backend:/app" -v iftar_backend_node_modules:/app/node_modules -w /app node:24-alpine sh -c "npm run build && npm run lint"`
  (first time on a fresh volume: prefix with `npm ci &&`).
- Mobile check (from repo root, Git Bash):
  `MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/repo" -v iftar_pub_cache:/root/.pub-cache -w /repo/apps/mobile ghcr.io/cirruslabs/flutter:stable sh -c "flutter pub get >/dev/null && flutter gen-l10n && flutter analyze lib"`
- Generated l10n files (`apps/mobile/lib/l10n/app_localizations*.dart`) are committed: regenerate and commit them with every `.arb` change.
- Every user-facing string exists in `app_en.arb`, `app_fr.arb` and `app_ar.arb` (Arabic is the fallback). Tunisian words ما خذاش / خذا are unchanged.
- Role names: `ADMIN` (global admin), `REGION_ADMIN` (regional admin), `USER` (volunteer). Account status: `pending | active | disabled`.
- Error codes travel in `error.details.code`: `ACCOUNT_PENDING`, `ACCOUNT_DISABLED` (401), `REGION_FORBIDDEN` (403), `INVALID_JOIN_CODE` (400), `NO_REGION` (400).
- Undo window and "until end of day" rules stay as in spec 2A; only "admin" widens to "regional admin of that region".
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Branch: `feat/security-region-access`.
- Never touch GitHub settings, the server, or real secrets; rotation is documented for the user.

## Deviations from the spec (decided while planning)

1. **`POST /fastings` is not region-guarded from the body.** The service already ignores the body's `region` and uses the creator's own region (`fasting.service.ts` `createFasting`). The guard skips that route; a creator with no region gets 400 `NO_REGION`. Same effect, less code.
2. **`AccessPolicy` is a set of pure functions** (`src/auth/access/access-policy.ts`), not an injectable service, so every module, guard and the meal-event service can use it without DI wiring.
3. **"Last active global admin can't be disabled"** needs no explicit check: only global admins can disable a global admin and nobody can disable themselves, so the last one can never be disabled.
4. **Forced sign-out keeps the offline queue** (the spec said unsynced meals are dropped). The queue is already stored per user and is not wiped on a server sign-out; if the account is re-enabled the meals sync, and if not, sync refuses them. Wiping would lose real meals for no gain.
5. **No delete button change in the app**: the app has no delete action today (`PeopleRepository.delete` has no UI).
6. **`UserOutput` keeps `isAccountDisabled`** (computed from `status`) next to the new `status`, so the current app's login check keeps working.

## Review Focus

1. **Stale role or region after an admin change** — after "Disable", "Make coordinator" or "Move to region", the affected user's very next request must use the new state (strategy reads Postgres, `createRequestContext` must expose `regionId`). Task 3 Step 6 checks `@Expose()` on `regionId`; Task 11's smoke list checks it end to end.
2. **Global admin with no region** — the seeded `admin` gets a region from the CLI, but a global admin without one must still use `/users`, `/regions` and every region via the URL, and get 400 `NO_REGION` only on `POST /fastings`. Task 4 Step 4 and Task 6 handle it.
3. **Regional admin escalation** — a regional admin must not approve/disable another regional admin, a global admin, or someone in another region, and must not reach `PATCH /users/:id/role`. `canManageUser` (Task 3) and Task 6's guards; Task 11 smoke checks it.
4. **Many phones behind one IP** — 8 volunteers on the same Wi-Fi must never hit the throttle during a distribution; only login/register/refresh are strict. Task 7 keeps the global limit at 600/min and Task 11 checks one login burst.
5. **Join code typed with spaces or lower case** — `" nour-4821 "` must work; a wrong code must be a clear field error, never a silent pending account. Task 5 (normalize) and Task 9 (field error).

---

### Task 1: Secrets out of git, CLI fixes, CI gates

**Files:**
- Remove from git (keep local copies): `apps/backend/.env`, `apps/backend/.env.development`, `apps/backend/.env.production`
- Modify: `.gitignore`, `apps/backend/.env.template`, `setup.sh`, `apps/backend/src/cli.ts`, `apps/backend/package.json`, `.github/workflows/deploy-backend.yml`, `.github/workflows/release.yml`, `apps/mobile/analysis_options.yaml`, `docs/DEPLOYMENT.md`

**Interfaces:**
- Produces: `node dist/src/cli.js reset-admin-password` (and `npm run cli:dev -- reset-admin-password`).

- [ ] **Step 1: Stop tracking the backend env files** (local files stay, the local dev stack keeps working)

```bash
git rm --cached apps/backend/.env apps/backend/.env.development apps/backend/.env.production
```

Append to the root `.gitignore`, under the existing "Deployment" block:

```gitignore
# Backend env files hold secrets; only the template is committed.
/apps/backend/.env*
!/apps/backend/.env.template
```

- [ ] **Step 2: Placeholders only in `apps/backend/.env.template`**

```dotenv
APP_ENV=development
APP_PORT=3000
APP_TIMEZONE=Africa/Tunis
UNDO_WINDOW_MINUTES=10
DB_HOST=localhost
DB_PORT=5432
DB_NAME=iftar_db
DB_USER=iftar
DB_PASS=change-me
JWT_ACCESS_TOKEN_EXP_IN_SEC=3600
JWT_REFRESH_TOKEN_EXP_IN_SEC=7200
# ./scripts/generate-jwt-keys prints these two lines
JWT_PUBLIC_KEY_BASE64=
JWT_PRIVATE_KEY_BASE64=
DEFAULT_ADMIN_USER_PASSWORD=change-me
RELEASES_DIR=releases
```

- [ ] **Step 3: `setup.sh` writes no secrets**

Replace the whole `echo "Creating .env file..."` → `EOL` block (lines 45–60 today) with:

```bash
echo "Creating .env file with fresh random secrets..."
if [ -f .env ]; then
  echo ".env already exists, leaving it untouched."
else
  cp .env.example .env
  DB_PASS_VALUE=$(openssl rand -base64 24 | tr -d '/+=')
  ADMIN_PASS_VALUE=$(openssl rand -base64 24 | tr -d '/+=')
  openssl genrsa -out /tmp/iftar-jwt.pem 2048 2>/dev/null
  openssl rsa -in /tmp/iftar-jwt.pem -pubout -out /tmp/iftar-jwt.pub 2>/dev/null
  JWT_PRIVATE=$(base64 -w0 /tmp/iftar-jwt.pem)
  JWT_PUBLIC=$(base64 -w0 /tmp/iftar-jwt.pub)
  rm -f /tmp/iftar-jwt.pem /tmp/iftar-jwt.pub
  sed -i \
    -e "s|^DB_PASS=.*|DB_PASS=${DB_PASS_VALUE}|" \
    -e "s|^DEFAULT_ADMIN_USER_PASSWORD=.*|DEFAULT_ADMIN_USER_PASSWORD=${ADMIN_PASS_VALUE}|" \
    -e "s|^JWT_PRIVATE_KEY_BASE64=.*|JWT_PRIVATE_KEY_BASE64=${JWT_PRIVATE}|" \
    -e "s|^JWT_PUBLIC_KEY_BASE64=.*|JWT_PUBLIC_KEY_BASE64=${JWT_PUBLIC}|" \
    .env
  chmod 600 .env
  echo "Admin password (shown once, store it safely): ${ADMIN_PASS_VALUE}"
fi
echo "Set DOMAIN and ACME_EMAIL in .env before starting the stack."
```

Delete the old line `echo "Setup complete! Please update the .env file with your actual values."` only if it now duplicates; keep the Docker-group notes. Confirm `grep -n "iftar@2026\|gmail\|LS0t" setup.sh` prints nothing.

- [ ] **Step 4: `cli.ts` stops printing the password and gains `reset-admin-password`**

In `apps/backend/src/cli.ts`:

1. Delete the line `console.log('defaultAdminUserPassword:', defaultAdminUserPassword);`.
2. Add the import `import { UserRepository } from './user/repositories/user.repository';` and `import { hash } from 'bcrypt';` (sorted per simple-import-sort).
3. Directly after the `if (!defaultAdminUserPassword) { throw ... }` block insert:

```ts
    // `reset-admin-password`: set the existing admin's password from
    // DEFAULT_ADMIN_USER_PASSWORD (secret rotation on a running server).
    if (process.argv.includes('reset-admin-password')) {
      const users = app.get(UserRepository);
      const admin = await users.findOne({ where: { username: 'admin' } });
      if (!admin) {
        throw new Error('No "admin" user to reset');
      }
      admin.password = await hash(defaultAdminUserPassword, 10);
      await users.save(admin);
      logger.log('Admin password reset from DEFAULT_ADMIN_USER_PASSWORD');
      await app.close();
      return;
    }
```

(`isAccountDisabled: false` in `initialAdmin` is replaced in Task 2.)

- [ ] **Step 5: CI gates are build/lint/analyze only**

`.github/workflows/deploy-backend.yml`, job `test`: replace the step `- run: npm test` with

```yaml
      - run: npm run lint
      - run: npm run build
```

and rename the job id `test` → `check` (update `needs: test` → `needs: check`).

`.github/workflows/release.yml`: rename job `test-mobile` → `check-mobile`, delete the step `- run: flutter test`, and update `needs: test-mobile` → `needs: check-mobile` everywhere it appears.

`apps/mobile/analysis_options.yaml`, under `analyzer:` add:

```yaml
  exclude:
    - test/**
```

- [ ] **Step 6: Rotation guide in `docs/DEPLOYMENT.md`**

Append a section:

```markdown
## Rotating secrets (do this once now: old values are in public git history)

Old JWT keys, database and admin passwords were committed before October 2026. They
are useless once replaced:

1. New JWT pair: `cd apps/backend && ./scripts/generate-jwt-keys` → GitHub secrets
   `JWT_PUBLIC_KEY_BASE64`, `JWT_PRIVATE_KEY_BASE64`.
2. New `DB_PASS` and `DEFAULT_ADMIN_USER_PASSWORD` (`openssl rand -base64 24`) →
   GitHub secrets of the same name.
3. If a server is already running:
   - change the Postgres password:
     `docker exec -it iftar-db psql -U iftar -d iftar_db -c "ALTER USER iftar PASSWORD '<new>'"`
   - run the "Deploy backend" workflow (writes the new `.env`, restarts the API;
     every phone is signed out once because the JWT keys changed);
   - set the admin password: `docker exec iftar-api node dist/src/cli.js reset-admin-password`.
4. Locally: `apps/backend/.env*` are no longer tracked; copy `.env.template`.
```

(Check container names against `docker-compose.yml` while writing; use the names it defines.)

- [ ] **Step 7: Verify and commit**

Run the backend check (Global Constraints). Expected: build and lint succeed.

```bash
git add -A .gitignore setup.sh apps/backend/.env.template apps/backend/src/cli.ts .github/workflows apps/mobile/analysis_options.yaml docs/DEPLOYMENT.md
git commit -m "chore: secrets out of git, admin password reset command, CI gates without tests"
```

---

### Task 2: Account status, regional admin role, join code column

**Files:**
- Create: `apps/backend/migrations/1791400000000-AccountStatusAndJoinCodes.ts`, `apps/backend/src/user/constants/user-status.constant.ts`
- Modify: `apps/backend/src/auth/constants/role.constant.ts`, `apps/backend/src/user/entities/user.entity.ts`, `apps/backend/src/region/entities/region.entity.ts`, `apps/backend/src/user/dtos/user-output.dto.ts`, `apps/backend/src/user/dtos/user-create-input.dto.ts`, `apps/backend/src/auth/dtos/auth-register-input.dto.ts`, `apps/backend/src/auth/dtos/auth-register-output.dto.ts`, `apps/backend/src/auth/services/auth.service.ts`, `apps/backend/src/cli.ts`

**Interfaces:**
- Produces: `ROLE.REGION_ADMIN = 'REGION_ADMIN'`; `USER_STATUS` const `{ PENDING: 'pending', ACTIVE: 'active', DISABLED: 'disabled' }` and type `UserStatus`; `User.status`, `User.approvedByUserId`, `User.approvedAt`, `User.joinedWithCode`; `Region.joinCode: string | null`; `UserOutput.status`, `UserOutput.joinedWithCode`, `UserOutput.isAccountDisabled` (computed).

- [ ] **Step 1: Role and status constants**

`role.constant.ts`:

```ts
export enum ROLE {
  USER = 'USER',
  /** Coordinator of one region: manages its volunteers, codes and meals. */
  REGION_ADMIN = 'REGION_ADMIN',
  ADMIN = 'ADMIN',
}
```

`src/user/constants/user-status.constant.ts`:

```ts
/** Lifecycle of an account (spec security §3.1). */
export const USER_STATUS = {
  /** Registered without a join code; waits for an admin. */
  PENDING: 'pending',
  ACTIVE: 'active',
  DISABLED: 'disabled',
} as const;

export type UserStatus = (typeof USER_STATUS)[keyof typeof USER_STATUS];
```

- [ ] **Step 2: Migration**

`migrations/1791400000000-AccountStatusAndJoinCodes.ts`:

```ts
import { MigrationInterface, QueryRunner } from 'typeorm';

/** Security spec §3.1: account status replaces isAccountDisabled; region join codes. */
export class AccountStatusAndJoinCodes1791400000000
  implements MigrationInterface
{
  name = 'AccountStatusAndJoinCodes1791400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" ADD "status" character varying(16) NOT NULL DEFAULT 'active'`,
    );
    await queryRunner.query(
      `UPDATE "users" SET "status" = CASE WHEN "isAccountDisabled" THEN 'disabled' ELSE 'active' END`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" ADD CONSTRAINT "CHK_users_status" CHECK ("status" IN ('pending', 'active', 'disabled'))`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" DROP COLUMN "isAccountDisabled"`,
    );
    await queryRunner.query(`ALTER TABLE "users" ADD "approvedByUserId" integer`);
    await queryRunner.query(
      `ALTER TABLE "users" ADD "approvedAt" TIMESTAMP WITH TIME ZONE`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" ADD "joinedWithCode" boolean NOT NULL DEFAULT false`,
    );
    await queryRunner.query(
      `ALTER TABLE "regions" ADD "joinCode" character varying(32)`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_regions_joinCode" ON "regions" ("joinCode") WHERE "joinCode" IS NOT NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "UQ_regions_joinCode"`);
    await queryRunner.query(`ALTER TABLE "regions" DROP COLUMN "joinCode"`);
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "joinedWithCode"`);
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "approvedAt"`);
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "approvedByUserId"`);
    await queryRunner.query(
      `ALTER TABLE "users" ADD "isAccountDisabled" boolean NOT NULL DEFAULT false`,
    );
    await queryRunner.query(
      `UPDATE "users" SET "isAccountDisabled" = ("status" <> 'active')`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" DROP CONSTRAINT "CHK_users_status"`,
    );
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "status"`);
  }
}
```

Before writing, open `migrations/1740317360063-InitialSchema.ts` and confirm the exact column name `isAccountDisabled` and that `users`/`regions` are the table names; adjust if not.

- [ ] **Step 3: Entities**

`user.entity.ts` — replace the `isAccountDisabled` column with:

```ts
  @Column({ length: 16, default: USER_STATUS.ACTIVE })
  status: UserStatus;

  /** Who approved a pending account (null for code joins and old accounts). */
  @Column({ type: 'int', nullable: true })
  approvedByUserId: number | null;

  @Column({ type: 'timestamptz', nullable: true })
  approvedAt: Date | null;

  @Column({ default: false })
  joinedWithCode: boolean;
```

with `import { USER_STATUS, UserStatus } from '../constants/user-status.constant';`.

`region.entity.ts` — after `allowOfflineServing`:

```ts
  /** Shared in the volunteers' group; registering with it skips approval. Null = off. */
  @Column({ type: 'varchar', length: 32, nullable: true })
  joinCode: string | null;
```

(The unique partial index lives in the migration only; no `@Index` decorator, so `migration:generate` stays quiet.)

- [ ] **Step 4: DTOs**

`user-output.dto.ts` — replace the `isAccountDisabled` property with:

```ts
  @Expose()
  @ApiProperty({ enum: ['pending', 'active', 'disabled'] })
  status: UserStatus;

  /** Kept for app versions that predate `status`. */
  @Expose()
  @Transform(({ obj }) => obj.status === USER_STATUS.DISABLED)
  @ApiProperty()
  isAccountDisabled: boolean;

  @Expose()
  @ApiProperty()
  joinedWithCode: boolean;
```

(imports: `Transform` from `class-transformer`, `USER_STATUS`, `UserStatus`.)

`user-create-input.dto.ts` — replace `isAccountDisabled` with:

```ts
  @ApiProperty({ enum: ['pending', 'active', 'disabled'] })
  @IsIn(['pending', 'active', 'disabled'])
  status: UserStatus;

  @IsOptional()
  @IsBoolean()
  joinedWithCode?: boolean;
```

`auth-register-input.dto.ts` — replace `isAccountDisabled: boolean;` with `status: UserStatus;` and add `joinedWithCode = false;` (both "set by the server" fields, no decorators; Task 5 rewrites this DTO fully).

`auth-register-output.dto.ts` — replace `isAccountDisabled` with an exposed `status: UserStatus`.

- [ ] **Step 5: Keep callers compiling**

- `auth.service.ts` `validateUser`: replace `if (user.isAccountDisabled)` with `if (user.status !== USER_STATUS.ACTIVE)` (Task 5 refines the message/code).
- `auth.service.ts` `register`: replace `input.isAccountDisabled = false;` with `input.status = USER_STATUS.ACTIVE;` (Task 5 rewrites register).
- `cli.ts` `initialAdmin`: replace `isAccountDisabled: false,` with `status: USER_STATUS.ACTIVE,`.

Run `grep -rn "isAccountDisabled" apps/backend/src` — only the computed `UserOutput` field remains.

- [ ] **Step 6: Verify and commit**

Backend check. Expected: build and lint succeed.

```bash
git add apps/backend
git commit -m "feat(backend): account status, regional admin role, region join code column"
```

---

### Task 3: Access policy, fresh user on every request

**Files:**
- Create: `apps/backend/src/auth/access/access-policy.ts`, `apps/backend/src/auth/access/auth-error-codes.ts`, `apps/backend/src/auth/access/load-request-user.ts`, `apps/backend/src/auth/guards/region-access.guard.ts`, `apps/backend/src/auth/decorators/skip-region-check.decorator.ts`
- Modify: `apps/backend/src/auth/dtos/auth-token-output.dto.ts`, `apps/backend/src/shared/acl/actor.constant.ts`, `apps/backend/src/auth/strategies/jwt-auth.strategy.ts`, `apps/backend/src/auth/strategies/jwt-refresh.strategy.ts`, `apps/backend/src/auth/guards/roles.guard.ts`

**Interfaces:**
- Consumes: `ROLE`, `USER_STATUS` (Task 2).
- Produces:
  - `AUTH_ERROR_CODES` = `{ ACCOUNT_PENDING, ACCOUNT_DISABLED, REGION_FORBIDDEN, INVALID_JOIN_CODE, NO_REGION }`
  - `interface AccessUser { id: number; roles: string[]; regionId?: number | null }`
  - `isGlobalAdmin(user: AccessUser): boolean`
  - `canAccessRegion(user: AccessUser, regionId: number): boolean`
  - `isRegionAdmin(user: AccessUser, regionId: number): boolean`
  - `isAnyAdmin(user: AccessUser): boolean` (global or regional)
  - `canManageUser(actor: AccessUser, target: { id: number; roles: string[]; regionId: number | null }): boolean`
  - `regionForbidden(): ForbiddenException`
  - `loadRequestUser(dataSource: DataSource, userId: number): Promise<UserAccessTokenClaims>` — throws 401 with code for missing/pending/disabled
  - `UserAccessTokenClaims.regionId: number | null` (exposed)
  - `RegionAccessGuard` (reads `:region`), `@SkipRegionCheck()`

- [ ] **Step 1: Error codes** — `src/auth/access/auth-error-codes.ts`

```ts
/** Machine-readable auth/access codes returned in `error.details.code`. */
export const AUTH_ERROR_CODES = {
  ACCOUNT_PENDING: 'ACCOUNT_PENDING',
  ACCOUNT_DISABLED: 'ACCOUNT_DISABLED',
  REGION_FORBIDDEN: 'REGION_FORBIDDEN',
  INVALID_JOIN_CODE: 'INVALID_JOIN_CODE',
  NO_REGION: 'NO_REGION',
} as const;
```

- [ ] **Step 2: The policy** — `src/auth/access/access-policy.ts`

```ts
import { ForbiddenException } from '@nestjs/common';

import { ROLE } from '../constants/role.constant';
import { AUTH_ERROR_CODES } from './auth-error-codes';

/** The request user as the policy sees it (fresh from the database). */
export interface AccessUser {
  id: number;
  roles: string[];
  regionId?: number | null;
}

/**
 * Every access right in one place (security spec §2–3.2).
 * Global admin: everything. Regional admin and volunteer: their own region
 * only. No region means no access (fail closed).
 */
export function isGlobalAdmin(user: AccessUser): boolean {
  return user.roles.includes(ROLE.ADMIN);
}

export function canAccessRegion(user: AccessUser, regionId: number): boolean {
  if (isGlobalAdmin(user)) return true;
  return user.regionId != null && Number(user.regionId) === Number(regionId);
}

export function isRegionAdmin(user: AccessUser, regionId: number): boolean {
  if (isGlobalAdmin(user)) return true;
  return (
    user.roles.includes(ROLE.REGION_ADMIN) && canAccessRegion(user, regionId)
  );
}

export function isAnyAdmin(user: AccessUser): boolean {
  return isGlobalAdmin(user) || user.roles.includes(ROLE.REGION_ADMIN);
}

/**
 * Approve, refuse, disable or enable `target`. A regional admin manages only
 * plain volunteers of their own region; nobody manages themselves here.
 */
export function canManageUser(
  actor: AccessUser,
  target: { id: number; roles: string[]; regionId: number | null },
): boolean {
  if (actor.id === target.id) return false;
  if (isGlobalAdmin(actor)) return true;
  if (!actor.roles.includes(ROLE.REGION_ADMIN)) return false;
  const plainVolunteer = target.roles.every((r) => r === ROLE.USER);
  return (
    plainVolunteer &&
    target.regionId != null &&
    canAccessRegion(actor, target.regionId)
  );
}

export function regionForbidden(): ForbiddenException {
  return new ForbiddenException({
    message: 'You cannot act in this region',
    code: AUTH_ERROR_CODES.REGION_FORBIDDEN,
  });
}
```

- [ ] **Step 3: Claims carry the region**

`auth-token-output.dto.ts`, in `UserAccessTokenClaims` add:

```ts
  /** The user's region, read from the database on every request. */
  @Expose()
  @ApiProperty({ type: () => Number, nullable: true })
  regionId: number | null;
```

`shared/acl/actor.constant.ts`:

```ts
export interface Actor {
  id: number;

  roles: string[];

  regionId?: number | null;
}
```

- [ ] **Step 4: Loading the user** — `src/auth/access/load-request-user.ts`

```ts
import { UnauthorizedException } from '@nestjs/common';
import { DataSource } from 'typeorm';

import { USER_STATUS } from '../../user/constants/user-status.constant';
import { UserAccessTokenClaims } from '../dtos/auth-token-output.dto';
import { AUTH_ERROR_CODES } from './auth-error-codes';

/**
 * The token only says who the caller is. Role, region and status come from
 * the database on every request, so disabling or moving someone applies on
 * their next request (security spec §3.4).
 */
export async function loadRequestUser(
  dataSource: DataSource,
  userId: number,
): Promise<UserAccessTokenClaims> {
  const [row]: Array<{
    id: number;
    username: string;
    roles: string;
    status: string;
    regionId: number | null;
  }> = await dataSource.query(
    `SELECT "id", "username", "roles", "status", "regionId" FROM "users" WHERE "id" = $1`,
    [userId],
  );
  if (!row) {
    throw new UnauthorizedException('Unknown user');
  }
  if (row.status === USER_STATUS.PENDING) {
    throw new UnauthorizedException({
      message: 'This account is waiting for approval',
      code: AUTH_ERROR_CODES.ACCOUNT_PENDING,
    });
  }
  if (row.status !== USER_STATUS.ACTIVE) {
    throw new UnauthorizedException({
      message: 'This user account has been disabled',
      code: AUTH_ERROR_CODES.ACCOUNT_DISABLED,
    });
  }
  return {
    id: row.id,
    username: row.username,
    // simple-array is stored comma-separated.
    roles: row.roles.split(',').filter(Boolean) as UserAccessTokenClaims['roles'],
    regionId: row.regionId,
  };
}
```

Check `users.regionId` is the FK column name in `InitialSchema` (TypeORM default for `region` ManyToOne). Adjust the SQL if it differs.

- [ ] **Step 5: Strategies use it**

`jwt-auth.strategy.ts`:

```ts
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { DataSource } from 'typeorm';

import { loadRequestUser } from '../access/load-request-user';
import { STRATEGY_JWT_AUTH } from '../constants/strategy.constant';
import { UserAccessTokenClaims } from '../dtos/auth-token-output.dto';

@Injectable()
export class JwtAuthStrategy extends PassportStrategy(
  Strategy,
  STRATEGY_JWT_AUTH,
) {
  constructor(
    configService: ConfigService,
    private readonly dataSource: DataSource,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: configService.get<string>('jwt.publicKey'),
      algorithms: ['RS256'],
    });
  }

  /** The token's roles claim is ignored: the database is the source of truth. */
  validate(payload: { sub: number }): Promise<UserAccessTokenClaims> {
    return loadRequestUser(this.dataSource, payload.sub);
  }
}
```

`jwt-refresh.strategy.ts` — same constructor change (inject `DataSource`), and:

```ts
  /** A disabled or pending account cannot refresh either. */
  async validate(payload: { sub: number }): Promise<UserRefreshTokenClaims> {
    const user = await loadRequestUser(this.dataSource, payload.sub);
    return { id: user.id };
  }
```

`DataSource` is provided globally by `TypeOrmModule`, so the modules that list `JwtAuthStrategy` (`UserModule`, `RegionModule`, `FastingModule`, `AuthModule`) need no change.

- [ ] **Step 6: `createRequestContext` exposes `regionId`**

No code change: it uses `plainToClass(UserAccessTokenClaims, request.user, { excludeExtraneousValues: true })`, and Step 3 put `@Expose()` on `regionId`. Confirm by reading `src/shared/request-context/util/index.ts`; if `@Expose()` were missing, `ctx.user.regionId` would silently be `undefined` and every volunteer would be refused.

- [ ] **Step 7: Region guard and opt-out decorator**

`src/auth/decorators/skip-region-check.decorator.ts`:

```ts
import { SetMetadata } from '@nestjs/common';

export const SKIP_REGION_CHECK_KEY = 'skipRegionCheck';

/** The route has no `:region`; it checks access in the service instead. */
export const SkipRegionCheck = (): MethodDecorator & ClassDecorator =>
  SetMetadata(SKIP_REGION_CHECK_KEY, true);
```

`src/auth/guards/region-access.guard.ts`:

```ts
import {
  BadRequestException,
  CanActivate,
  ExecutionContext,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { canAccessRegion, regionForbidden } from '../access/access-policy';
import { SKIP_REGION_CHECK_KEY } from '../decorators/skip-region-check.decorator';
import { UserAccessTokenClaims } from '../dtos/auth-token-output.dto';

/**
 * Runs after JwtAuthGuard on every route with a `:region` param: the caller
 * must be a global admin or belong to that region (security spec §3.3).
 */
@Injectable()
export class RegionAccessGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const skip = this.reflector.getAllAndOverride<boolean>(
      SKIP_REGION_CHECK_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (skip) return true;

    const request = context.switchToHttp().getRequest();
    const raw = request.params?.region;
    if (raw === undefined) return true;
    const regionId = Number(raw);
    if (!Number.isInteger(regionId) || regionId < 1) {
      throw new BadRequestException('region must be a positive integer');
    }
    const user = request.user as UserAccessTokenClaims;
    if (!user || !canAccessRegion(user, regionId)) {
      throw regionForbidden();
    }
    return true;
  }
}
```

- [ ] **Step 8: RolesGuard answers 403, not 401**

In `roles.guard.ts` replace `UnauthorizedException` with `ForbiddenException` (import and throw). A 401 makes the app try a token refresh and then sign the user out; a missing role is not an expired session.

- [ ] **Step 9: Verify and commit**

Backend check. Expected: build and lint succeed.

```bash
git add apps/backend/src
git commit -m "feat(backend): access policy, region guard, user re-read from the database on every request"
```

---

### Task 4: Enforce regions on people and meals

**Files:**
- Modify: `apps/backend/src/fasting/controllers/fasting.controller.ts`, `apps/backend/src/fasting/services/fasting-acl.service.ts`, `apps/backend/src/fasting/services/fasting.service.ts`, `apps/backend/src/fasting/services/meal-event.service.ts`, `apps/backend/src/fasting/services/revoke-rules.ts`, `apps/backend/src/fasting/dtos/fasting-input.dto.ts`, `apps/backend/src/shared/dtos/pagination-params.dto.ts`

**Interfaces:**
- Consumes: `RegionAccessGuard`, `SkipRegionCheck`, `canAccessRegion`, `isRegionAdmin`, `isGlobalAdmin`, `regionForbidden`, `AUTH_ERROR_CODES` (Task 3).
- Produces: `decideRevoke(event, actor, now, opts: { windowMinutes; timeZone; canAdminister: boolean })`; `RegionRefInput { id: number }`.

- [ ] **Step 1: Controller — guard on the class, ParseIntPipe, role checks**

In `fasting.controller.ts`:

1. Imports: `ParseIntPipe` from `@nestjs/common`; `RegionAccessGuard` from `../../auth/guards/region-access.guard`; `SkipRegionCheck` from `../../auth/decorators/skip-region-check.decorator`.
2. Add `@UseGuards(JwtAuthGuard, RegionAccessGuard)` on the class (below `@Controller('fastings')`) and remove `JwtAuthGuard` from every method's `@UseGuards(...)`; where a method had `@UseGuards(JwtAuthGuard, RolesGuard)` keep `@UseGuards(RolesGuard)`. Guards run class-level first, so `request.user` exists when `RegionAccessGuard` runs.
3. Every `@Param('region') region: number` → `@Param('region', ParseIntPipe) region: number`; every `@Param('id') id: number` / `fastingId: number` → with `ParseIntPipe`.
4. `getMealReview`: change `@Roles(ROLE.ADMIN)` to `@Roles(ROLE.ADMIN, ROLE.REGION_ADMIN)` (the guard then limits a regional admin to their region).
5. Add `@SkipRegionCheck()` to `revokeMeal`, `syncOfflineMeals`, `createFasting`.
6. `getFastings` (all regions): add `@SkipRegionCheck()`, `@UseGuards(RolesGuard)`, `@Roles(ROLE.ADMIN)`.
7. `deleteFasting`: add `@UseGuards(RolesGuard)` and `@Roles(ROLE.ADMIN, ROLE.REGION_ADMIN)`.

- [ ] **Step 2: ACL delegates to the policy** — `fasting-acl.service.ts`

```ts
import { Injectable } from '@nestjs/common';

import { canAccessRegion } from '../../auth/access/access-policy';
import { ROLE } from '../../auth/constants/role.constant';
import { BaseAclService } from '../../shared/acl/acl.service';
import { Action } from '../../shared/acl/action.constant';
import { Actor } from '../../shared/acl/actor.constant';
import { Fasting } from '../entities/fasting.entity';

/**
 * Security spec §2: volunteers create, read and edit in their own region;
 * regional admins also delete there; global admins do everything. The
 * RegionAccessGuard has already checked the URL region; this re-checks the
 * loaded person, so a wrong join can never leak another region.
 */
@Injectable()
export class FastingAclService extends BaseAclService<Fasting> {
  constructor() {
    super();
    this.canDo(ROLE.ADMIN, [Action.Manage]);
    this.canDo(ROLE.REGION_ADMIN, [Action.Manage], this.isInActorRegion);
    this.canDo(
      ROLE.USER,
      [Action.Create, Action.List, Action.Read, Action.Update],
      this.isInActorRegion,
    );
  }

  isInActorRegion(fasting: Fasting | undefined, actor: Actor): boolean {
    // List/Create pass no resource: the guard checked the region.
    if (!fasting) return true;
    const regionId = fasting.region?.id;
    return regionId != null && canAccessRegion(actor, regionId);
  }
}
```

In `meal-event.service.ts` `confirm`, change the `manager.findOne(Fasting, { where: { id: fastingId } })` to also load the region: `{ where: { id: fastingId }, relations: { region: true } }`, so `isInActorRegion` sees it.

In `fasting.service.ts`, every `throw new UnauthorizedException()` after an ACL check becomes `throw regionForbidden()` for read/update/create/list, and for delete:

```ts
      throw new ForbiddenException('Only an admin of this region can delete');
```

(Import `ForbiddenException`; drop `UnauthorizedException` if unused.)

- [ ] **Step 3: Region change on edit** — DTO and service

`fasting-input.dto.ts`: add

```ts
/** `{ id }` of a region; other fields the app sends are stripped. */
export class RegionRefInput {
  @IsInt()
  @Min(1)
  @ApiProperty()
  id: number;
}
```

In `UpdateFastingInput` replace the `region` property with:

```ts
  /** Only a global admin may move a person; others must send the URL region. */
  @IsOptional()
  @ValidateNested()
  @Type(() => RegionRefInput)
  @ApiProperty({ required: false, type: () => RegionRefInput })
  region?: RegionRefInput;
```

Remove the now-unused `Region` import if nothing else uses it.

In `fasting.service.ts` `updateFasting`, replace `if (edits.region !== undefined) columns.region = edits.region;` with (before `plainToClass`, using `input.region`):

```ts
    const target = input.region?.id;
    if (target !== undefined && target !== region) {
      if (!isGlobalAdmin(actor)) {
        throw regionForbidden();
      }
      const exists = await this.regionRepository.findOne({
        where: { id: target },
      });
      if (!exists) {
        throw new NotFoundException(`Region with ID ${target} not found`);
      }
      columns.region = { id: target };
    }
```

and change `editable` destructuring to `const { lastTakenMeal, takenMeals, region: _region, ...editable } = input;` so `plainToClass` never copies `region`. After a move, the final re-read must use the new region: `getByIdAndRegion(fastingId, (columns.region as { id: number })?.id ?? region)`.

`FastingService` needs `RegionRepository` injected: check its constructor; `RegionRepository` is already a provider of `FastingModule`. Add `private readonly regionRepository: RegionRepository` to the constructor if absent.

- [ ] **Step 4: Create needs a region** — `fasting.service.ts` `createFasting`

After `const user = await this.userService.getUserById(ctx, actor.id);` add:

```ts
    if (!user.region) {
      throw new BadRequestException({
        message: 'Your account has no region',
        code: AUTH_ERROR_CODES.NO_REGION,
      });
    }
```

- [ ] **Step 5: Undo — region first, then the regional-admin rule**

`revoke-rules.ts`:

```ts
/**
 * Who may undo a meal (spec 2A §4.2, widened by the security spec §2):
 * the volunteer who served it, within `windowMinutes` of the server
 * receiving it; or an admin of the meal's region (`canAdminister`), on the
 * meal's own service day. Undoing twice is not an error.
 */
export function decideRevoke(
  event: RevocableEvent,
  actor: { id: number },
  now: Date,
  opts: { windowMinutes: number; timeZone: string; canAdminister: boolean },
): RevokeDecision {
  if (event.revokedAt) {
    return 'alreadyRevoked';
  }
  if (
    opts.canAdminister &&
    event.serviceDay === localDayKey(now, opts.timeZone)
  ) {
    return 'allowed';
  }
  if (event.servedByUserId !== actor.id) {
    return opts.canAdminister ? 'windowExpired' : 'notAllowed';
  }
  const ageMs = now.getTime() - new Date(event.receivedAt).getTime();
  return ageMs <= opts.windowMinutes * 60_000 ? 'allowed' : 'windowExpired';
}
```

(Drop the `ROLE` import.) In `meal-event.service.ts` `revoke`, right after the first `if (!found) { throw ... }`:

```ts
      // A meal of another region looks like no meal at all (no id probing).
      if (!canAccessRegion(actor, found.regionId)) {
        throw new NotFoundException({
          message: 'Meal not found',
          code: FASTING_ERROR_CODES.MEAL_EVENT_NOT_FOUND,
        });
      }
```

and pass `canAdminister: isRegionAdmin(actor, event.regionId)` in the `decideRevoke` options. Search for other `decideRevoke(` callers (`grep -rn "decideRevoke(" apps/backend/src`) and update them the same way; ignore `*.spec.ts`.

- [ ] **Step 6: Offline sync uses the fresh request user**

In `meal-event.service.ts` `syncOffline`: replace `const isAdmin = actor.roles.includes(ROLE.ADMIN);` and the `SELECT "regionId" FROM "users"` query with

```ts
    const isAdmin = isGlobalAdmin(actor);
    const actorRegionId = actor.regionId ?? null;
```

and pass `actorRegionId` to `syncOne`. (A pending or disabled user never gets here: the strategy refused them.) Remove the `ROLE` import if unused.

- [ ] **Step 7: Input limits**

`fasting-input.dto.ts`, in both `CreateFastingInput` and `UpdateFastingInput`:
- `singleMeal`, `familyMeal`: replace `@IsNumber() @IsNotEmpty()` with `@IsInt() @Min(0) @Max(50)`.
- `takenMeals`: replace `@ValidateNested({ each: true }) @Type(() => Date)` with `@IsArray()` (keep `@IsOptional()`); the server overwrites or ignores it.
- `CreateFastingInput.id`: replace `@IsNumber() @IsNotEmpty()` with `@IsInt() @Min(1)`.

`pagination-params.dto.ts`, on `limit`: add `@Max(500)` (the app loads lists 500 at a time) and update the description to "Optional, defaults to 100, at most 500".

Import `IsArray`, `IsInt`, `Max`, `Min` from `class-validator` where needed; remove unused imports so lint passes.

- [ ] **Step 8: Verify and commit**

Backend check. Then `grep -n "UseGuards(JwtAuthGuard" apps/backend/src/fasting/controllers/fasting.controller.ts` — expected: only the class-level line.

```bash
git add apps/backend/src
git commit -m "feat(backend): people and meals limited to the caller's region; delete and review for region admins"
```

---

### Task 5: Register with a join code, login says pending or disabled

**Files:**
- Create: `apps/backend/src/region/services/join-code.ts`, `apps/backend/src/region/dtos/public-region-output.dto.ts`
- Modify: `apps/backend/src/auth/dtos/auth-register-input.dto.ts`, `apps/backend/src/auth/dtos/auth-register-output.dto.ts`, `apps/backend/src/auth/services/auth.service.ts`, `apps/backend/src/region/repositories/region.repository.ts`, `apps/backend/src/region/services/region.service.ts`, `apps/backend/src/region/controllers/region.controller.ts`

**Interfaces:**
- Consumes: `USER_STATUS`, `AUTH_ERROR_CODES`, `Region.joinCode`.
- Produces: `normalizeJoinCode(raw: string): string`, `generateJoinCode(): string`, `RegionRepository.findActiveByJoinCode(code: string): Promise<Region | null>`, `PublicRegionOutput { id; name }`, register response `data.status`.

- [ ] **Step 1: Code helpers** — `src/region/services/join-code.ts`

```ts
import { randomInt } from 'crypto';

/** Easy to say over the phone, Latin letters only (spec §4.4). */
const WORDS = [
  'NOUR', 'RAHMA', 'SABR', 'BARAKA', 'AMAL', 'SALAM', 'KHAIR', 'IHSAN',
  'HILAL', 'IFTAR', 'SUHUR', 'TAQWA', 'JANNA', 'FAJR', 'DUA', 'ZAKAT',
] as const;

/** `NOUR-4821`: a word and 4 random digits. */
export function generateJoinCode(): string {
  const word = WORDS[randomInt(WORDS.length)];
  const digits = String(randomInt(10_000)).padStart(4, '0');
  return `${word}-${digits}`;
}

/** What volunteers type: spaces, case and a missing dash are forgiven. */
export function normalizeJoinCode(raw: string): string {
  const compact = raw.trim().toUpperCase().replace(/[\s_]+/g, '');
  const match = /^([A-Z]+)-?(\d{4})$/.exec(compact);
  return match ? `${match[1]}-${match[2]}` : compact;
}
```

- [ ] **Step 2: Repository lookup** — `region.repository.ts`, add:

```ts
  findActiveByJoinCode(code: string): Promise<Region | null> {
    return this.findOne({ where: { joinCode: code, active: true } });
  }
```

- [ ] **Step 3: Register input** — `auth-register-input.dto.ts` (full file)

```ts
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsEmail,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Length,
  MaxLength,
  Min,
  ValidateIf,
  ValidateNested,
} from 'class-validator';

import { Region } from '../../region/entities/region.entity';
import { UserStatus } from '../../user/constants/user-status.constant';
import { ROLE } from '../constants/role.constant';

export class RegisterRegionInput {
  @IsInt()
  @Min(1)
  @ApiProperty()
  id: number;
}

/**
 * Security spec §4.1: a join code gives instant access to its region;
 * without one, `region` is required and the account waits for approval.
 */
export class RegisterInput {
  @ApiProperty()
  @IsNotEmpty()
  @MaxLength(100)
  @IsString()
  name: string;

  @ApiProperty()
  @IsNotEmpty()
  @MaxLength(200)
  @IsString()
  username: string;

  @ApiPropertyOptional({ example: 'NOUR-4821' })
  @IsOptional()
  @IsString()
  @MaxLength(32)
  joinCode?: string;

  @ApiPropertyOptional({ type: () => RegisterRegionInput })
  @ValidateIf((o: RegisterInput) => !o.joinCode?.trim())
  @ValidateNested()
  @Type(() => RegisterRegionInput)
  region?: RegisterRegionInput;

  @ApiProperty()
  @IsNotEmpty()
  @Length(8, 100)
  @IsString()
  password: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsEmail()
  @MaxLength(100)
  email: string;
}

/** What the service hands to UserService.createUser. */
export interface NewAccount {
  name: string;
  username: string;
  password: string;
  email: string;
  roles: ROLE[];
  status: UserStatus;
  joinedWithCode: boolean;
  region: Region;
}
```

`auth-register-output.dto.ts` keeps its fields (with `status` from Task 2); `region` stays exposed.

- [ ] **Step 4: Register service** — replace `AuthService.register` with:

```ts
  async register(
    ctx: RequestContext,
    input: RegisterInput,
  ): Promise<RegisterOutput> {
    this.logger.log(ctx, `${this.register.name} was called`);

    let region: Region | null;
    let joinedWithCode = false;
    const code = input.joinCode?.trim();
    if (code) {
      region = await this.regionRepository.findActiveByJoinCode(
        normalizeJoinCode(code),
      );
      if (!region) {
        throw new BadRequestException({
          message: 'This join code is not valid',
          code: AUTH_ERROR_CODES.INVALID_JOIN_CODE,
        });
      }
      joinedWithCode = true;
    } else {
      region = await this.regionRepository.findOne({
        where: { id: input.region.id, active: true },
      });
      if (!region) {
        throw new NotFoundException('Region not found');
      }
    }

    const account: NewAccount = {
      name: input.name,
      username: input.username,
      password: input.password,
      email: input.email,
      roles: [ROLE.USER],
      status: joinedWithCode ? USER_STATUS.ACTIVE : USER_STATUS.PENDING,
      joinedWithCode,
      region,
    };
    try {
      const registeredUser = await this.userService.createUser(
        ctx,
        account as unknown as CreateUserInput,
      );
      return plainToClass(RegisterOutput, registeredUser, {
        excludeExtraneousValues: true,
      });
    } catch (error) {
      if (error.status === HttpStatus.CONFLICT) {
        throw new ConflictException('Username or email is already in use');
      }
      throw error;
    }
  }
```

Wire it: inject `RegionRepository` into `AuthService` (replace the `RegionService` dependency if `register` was its only use — check with grep), and in `auth.module.ts` add `RegionRepository` to `providers` (import from `../region/repositories/region.repository`) — `RegionModule` does not export it. Imports in `auth.service.ts`: `BadRequestException`, `Region`, `RegionRepository`, `normalizeJoinCode`, `AUTH_ERROR_CODES`, `USER_STATUS`, `NewAccount`, `CreateUserInput`.

`UserService.createUser` saves `plainToClass(User, input)`; `status`, `joinedWithCode` and `region` map onto the entity columns from Task 2 — confirm `UserOutput` returned carries `status`.

- [ ] **Step 5: Login answers with a code** — `AuthService.validateUser`

```ts
    if (user.status === USER_STATUS.PENDING) {
      throw new UnauthorizedException({
        message: 'This account is waiting for approval',
        code: AUTH_ERROR_CODES.ACCOUNT_PENDING,
      });
    }
    if (user.status !== USER_STATUS.ACTIVE) {
      throw new UnauthorizedException({
        message: 'This user account has been disabled',
        code: AUTH_ERROR_CODES.ACCOUNT_DISABLED,
      });
    }
```

(`validateUsernamePassword` returns `UserOutput`, which exposes `status` since Task 2.)

`getAuthToken` also puts `regionId` in nothing new — the access token keeps `{ username, sub, roles }`; leave it.

- [ ] **Step 6: Public region list shows only id and name**

`src/region/dtos/public-region-output.dto.ts`:

```ts
import { ApiProperty } from '@nestjs/swagger';
import { Expose } from 'class-transformer';

/** What the unauthenticated Register screen may see. */
export class PublicRegionOutput {
  @Expose()
  @ApiProperty()
  id: number;

  @Expose()
  @ApiProperty()
  name: string;
}
```

`region.service.ts` `getRegions` returns `{ regions: PublicRegionOutput[]; count }` with `plainToClass(PublicRegionOutput, regions, { excludeExtraneousValues: true })`; update `region.controller.ts` `getRegions` types accordingly (`SwaggerBaseApiResponse([PublicRegionOutput])`).

- [ ] **Step 7: Verify and commit**

Backend check.

```bash
git add apps/backend/src
git commit -m "feat(backend): register with a region join code or wait for approval; login reports pending/disabled"
```

---

### Task 6: Account management, join code endpoints, region admin rules

**Files:**
- Create: `apps/backend/src/user/dtos/user-admin-input.dto.ts`, `apps/backend/src/region/dtos/join-code-output.dto.ts`
- Modify: `apps/backend/src/user/controllers/user.controller.ts`, `apps/backend/src/user/services/user.service.ts`, `apps/backend/src/user/services/user-acl.service.ts`, `apps/backend/src/region/controllers/region.controller.ts`, `apps/backend/src/region/services/region.service.ts`, `apps/backend/src/region/services/region-acl.service.ts`

**Interfaces:**
- Consumes: policy functions (Task 3), `USER_STATUS`, `generateJoinCode` (Task 5).
- Produces (HTTP, used by Task 10):
  - `GET /users?status=&regionId=&limit=&offset=` → `UserOutput[]` (with `region`), newest first
  - `POST /users/:id/approve|refuse|disable|enable` → `UserOutput` (refuse → `204`)
  - `PATCH /users/:id/role` body `{ role: 'USER'|'REGION_ADMIN', regionId: number }` → `UserOutput`
  - `GET /regions/:id/join-code` → `{ joinCode: string | null }`; `POST` → new code; `DELETE` → `{ joinCode: null }`

- [ ] **Step 1: DTOs** — `user-admin-input.dto.ts`

```ts
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsIn, IsInt, IsOptional, Min } from 'class-validator';

import { PaginationParamsDto } from '../../shared/dtos/pagination-params.dto';
import { ROLE } from '../../auth/constants/role.constant';
import {
  USER_STATUS,
  UserStatus,
} from '../constants/user-status.constant';

export class UsersQueryDto extends PaginationParamsDto {
  @ApiPropertyOptional({ enum: Object.values(USER_STATUS) })
  @IsOptional()
  @IsIn(Object.values(USER_STATUS))
  status?: UserStatus;

  /** Global admins only; regional admins always see their own region. */
  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(1)
  @Transform(({ value }) => parseInt(value, 10), { toClassOnly: true })
  regionId?: number;
}

export class ChangeRoleInput {
  @ApiProperty({ enum: [ROLE.USER, ROLE.REGION_ADMIN] })
  @IsIn([ROLE.USER, ROLE.REGION_ADMIN])
  role: ROLE.USER | ROLE.REGION_ADMIN;

  @ApiProperty()
  @IsInt()
  @Min(1)
  regionId: number;
}
```

(Fix import order for simple-import-sort with `npm run lint:fix` if lint complains.)

`src/region/dtos/join-code-output.dto.ts`:

```ts
import { ApiProperty } from '@nestjs/swagger';

export class JoinCodeOutput {
  @ApiProperty({ nullable: true, example: 'NOUR-4821' })
  joinCode: string | null;
}
```

- [ ] **Step 2: UserService — list and lifecycle**

Add to `user.service.ts` (imports: `ForbiddenException`, `BadRequestException`, policy functions, `USER_STATUS`, `ROLE`, `Region`, `In` is not needed):

```ts
  /** Volunteers screen list (security spec §4.3). */
  async listForAdmin(
    ctx: RequestContext,
    query: { status?: UserStatus; regionId?: number; limit: number; offset: number },
  ): Promise<{ users: UserOutput[]; count: number }> {
    const actor = ctx.user;
    if (!isAnyAdmin(actor)) {
      throw new ForbiddenException('Admins only');
    }
    let regionId = query.regionId;
    if (!isGlobalAdmin(actor)) {
      if (actor.regionId == null) throw regionForbidden();
      regionId = actor.regionId;
    }
    const [users, count] = await this.repository.findAndCount({
      where: {
        ...(query.status ? { status: query.status } : {}),
        ...(regionId ? { region: { id: regionId } } : {}),
      },
      relations: { region: true },
      order: { createdAt: 'DESC' },
      take: query.limit,
      skip: query.offset,
    });
    return {
      users: plainToClass(UserOutput, users, { excludeExtraneousValues: true }),
      count,
    };
  }

  private async loadManageable(ctx: RequestContext, id: number): Promise<User> {
    const target = await this.repository.findOne({
      where: { id },
      relations: { region: true },
    });
    // Someone you may not manage looks like nobody (no id probing).
    if (
      !target ||
      !canManageUser(ctx.user, {
        id: target.id,
        roles: target.roles,
        regionId: target.region?.id ?? null,
      })
    ) {
      throw new NotFoundException('User not found');
    }
    return target;
  }

  private async setStatus(
    ctx: RequestContext,
    id: number,
    from: UserStatus,
    to: UserStatus,
  ): Promise<UserOutput> {
    const target = await this.loadManageable(ctx, id);
    if (target.status !== from) {
      throw new BadRequestException(`This account is not ${from}`);
    }
    target.status = to;
    if (from === USER_STATUS.PENDING && to === USER_STATUS.ACTIVE) {
      target.approvedByUserId = ctx.user.id;
      target.approvedAt = new Date();
    }
    const saved = await this.repository.save(target);
    return plainToClass(UserOutput, saved, { excludeExtraneousValues: true });
  }

  approve(ctx: RequestContext, id: number): Promise<UserOutput> {
    return this.setStatus(ctx, id, USER_STATUS.PENDING, USER_STATUS.ACTIVE);
  }

  disable(ctx: RequestContext, id: number): Promise<UserOutput> {
    return this.setStatus(ctx, id, USER_STATUS.ACTIVE, USER_STATUS.DISABLED);
  }

  enable(ctx: RequestContext, id: number): Promise<UserOutput> {
    return this.setStatus(ctx, id, USER_STATUS.DISABLED, USER_STATUS.ACTIVE);
  }

  /** Refusing deletes the pending account, so the username is free again. */
  async refuse(ctx: RequestContext, id: number): Promise<void> {
    const target = await this.loadManageable(ctx, id);
    if (target.status !== USER_STATUS.PENDING) {
      throw new BadRequestException('Only a waiting account can be refused');
    }
    await this.repository.remove(target);
  }

  /** Global admins only: make coordinator / volunteer, or move region. */
  async changeRole(
    ctx: RequestContext,
    id: number,
    input: { role: ROLE.USER | ROLE.REGION_ADMIN; regionId: number },
  ): Promise<UserOutput> {
    if (!isGlobalAdmin(ctx.user)) {
      throw new ForbiddenException('Global admins only');
    }
    const target = await this.repository.findOne({
      where: { id },
      relations: { region: true },
    });
    if (!target) throw new NotFoundException('User not found');
    if (target.id === ctx.user.id || target.roles.includes(ROLE.ADMIN)) {
      throw new BadRequestException(
        'Global admin accounts are not changed here',
      );
    }
    const region = await this.repository.manager.findOne(Region, {
      where: { id: input.regionId },
    });
    if (!region) throw new NotFoundException('Region not found');
    target.roles = [input.role];
    target.region = region;
    const saved = await this.repository.save(target);
    return plainToClass(UserOutput, saved, { excludeExtraneousValues: true });
  }
```

Remove the old `getUsers` method if nothing else calls it (grep), otherwise leave it.

`user-acl.service.ts`: the `ROLE.USER` "read any user" rule goes:

```ts
    this.canDo(ROLE.ADMIN, [Action.Manage]);
    // A volunteer reads and updates only themselves (GET /users/me).
    this.canDo(ROLE.USER, [Action.Read, Action.Update], this.isUserItself);
    this.canDo(ROLE.REGION_ADMIN, [Action.Read, Action.Update], this.isUserItself);
```

- [ ] **Step 3: UserController routes**

Replace `getUsers` with the admin list and add the actions (keep `me`, `getUser`, `updateUser` which stay `@Roles(ROLE.ADMIN)`). Put the static/action routes before `':id'`:

```ts
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @UseInterceptors(ClassSerializerInterceptor)
  @Get()
  @ApiOperation({ summary: 'Volunteers list for admins (security spec §4.3)' })
  @ApiResponse({ status: HttpStatus.OK, type: SwaggerBaseApiResponse([UserOutput]) })
  async getUsers(
    @ReqContext() ctx: RequestContext,
    @Query() query: UsersQueryDto,
  ): Promise<BaseApiResponse<UserOutput[]>> {
    this.logger.log(ctx, `${this.getUsers.name} was called`);
    const { users, count } = await this.userService.listForAdmin(ctx, query);
    return { data: users, meta: { count } };
  }

  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @UseInterceptors(ClassSerializerInterceptor)
  @Post(':id/approve')
  @HttpCode(HttpStatus.OK)
  async approve(
    @ReqContext() ctx: RequestContext,
    @Param('id', ParseIntPipe) id: number,
  ): Promise<BaseApiResponse<UserOutput>> {
    return { data: await this.userService.approve(ctx, id), meta: {} };
  }

  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @Post(':id/refuse')
  @HttpCode(HttpStatus.NO_CONTENT)
  async refuse(
    @ReqContext() ctx: RequestContext,
    @Param('id', ParseIntPipe) id: number,
  ): Promise<void> {
    await this.userService.refuse(ctx, id);
  }

  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @UseInterceptors(ClassSerializerInterceptor)
  @Post(':id/disable')
  @HttpCode(HttpStatus.OK)
  async disable(
    @ReqContext() ctx: RequestContext,
    @Param('id', ParseIntPipe) id: number,
  ): Promise<BaseApiResponse<UserOutput>> {
    return { data: await this.userService.disable(ctx, id), meta: {} };
  }

  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @UseInterceptors(ClassSerializerInterceptor)
  @Post(':id/enable')
  @HttpCode(HttpStatus.OK)
  async enable(
    @ReqContext() ctx: RequestContext,
    @Param('id', ParseIntPipe) id: number,
  ): Promise<BaseApiResponse<UserOutput>> {
    return { data: await this.userService.enable(ctx, id), meta: {} };
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(ROLE.ADMIN)
  @ApiBearerAuth()
  @UseInterceptors(ClassSerializerInterceptor)
  @Patch(':id/role')
  async changeRole(
    @ReqContext() ctx: RequestContext,
    @Param('id', ParseIntPipe) id: number,
    @Body() input: ChangeRoleInput,
  ): Promise<BaseApiResponse<UserOutput>> {
    return { data: await this.userService.changeRole(ctx, id, input), meta: {} };
  }
```

Add `ParseIntPipe` to `getUser`/`updateUser` params too. Imports: `HttpCode`, `ParseIntPipe`, `Post`; `UsersQueryDto`, `ChangeRoleInput`.

`GET /users/me` must return `status` and `region` — `findById` already loads `region`.

- [ ] **Step 4: Region CRUD is global-admin only; join code endpoints**

`region.controller.ts`:
- `createRegion`, `updateRegion`, `deleteRegion`: `@UseGuards(JwtAuthGuard, RolesGuard)` + `@Roles(ROLE.ADMIN)`.
- `getRegion` (`GET /regions/:id`): add `ParseIntPipe` and, in the service, `if (!canAccessRegion(ctx.user, id)) throw regionForbidden();`.
- New routes (declare before `':id'`-only routes is not required — paths differ):

```ts
  @Get(':id/join-code')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  async getJoinCode(
    @ReqContext() ctx: RequestContext,
    @Param('id', ParseIntPipe) id: number,
  ): Promise<BaseApiResponse<JoinCodeOutput>> {
    return { data: await this.regionService.getJoinCode(ctx, id), meta: {} };
  }

  @Post(':id/join-code')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  async newJoinCode(
    @ReqContext() ctx: RequestContext,
    @Param('id', ParseIntPipe) id: number,
  ): Promise<BaseApiResponse<JoinCodeOutput>> {
    return { data: await this.regionService.newJoinCode(ctx, id), meta: {} };
  }

  @Delete(':id/join-code')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  async turnOffJoinCode(
    @ReqContext() ctx: RequestContext,
    @Param('id', ParseIntPipe) id: number,
  ): Promise<BaseApiResponse<JoinCodeOutput>> {
    return { data: await this.regionService.turnOffJoinCode(ctx, id), meta: {} };
  }
```

`region.service.ts`:

```ts
  private async regionForAdmin(ctx: RequestContext, id: number): Promise<Region> {
    if (!isRegionAdmin(ctx.user, id)) throw regionForbidden();
    const region = await this.repository.findOne({ where: { id } });
    if (!region) throw new NotFoundException('Region not found');
    return region;
  }

  async getJoinCode(ctx: RequestContext, id: number): Promise<JoinCodeOutput> {
    const region = await this.regionForAdmin(ctx, id);
    return { joinCode: region.joinCode ?? null };
  }

  /** Replaces the code; the old one stops working at once. */
  async newJoinCode(ctx: RequestContext, id: number): Promise<JoinCodeOutput> {
    await this.regionForAdmin(ctx, id);
    for (let attempt = 0; attempt < 5; attempt++) {
      const joinCode = generateJoinCode();
      try {
        await this.repository.update({ id }, { joinCode });
        return { joinCode };
      } catch (error) {
        // 23505 = unique_violation: another region drew the same code.
        if (error?.code !== '23505') throw error;
      }
    }
    throw new ConflictException('Could not draw a unique code, try again');
  }

  async turnOffJoinCode(ctx: RequestContext, id: number): Promise<JoinCodeOutput> {
    await this.regionForAdmin(ctx, id);
    await this.repository.update({ id }, { joinCode: null });
    return { joinCode: null };
  }
```

`RegionOutput` must not expose `joinCode` (it doesn't list it; with `excludeExtraneousValues` absent in `plainToClass(RegionOutput, …)`, add `@Exclude()` on nothing — instead make sure every `plainToClass(RegionOutput, …)` in `region.service.ts` passes `{ excludeExtraneousValues: true }`).

`region-acl.service.ts`: drop the `ROLE.USER` author rule (`this.canDo(ROLE.USER, ...)` line and `isRegionAuthor`); regions are managed by global admins.

- [ ] **Step 5: Verify and commit**

Backend check.

```bash
git add apps/backend/src
git commit -m "feat(backend): approve/refuse/disable/enable volunteers, coordinator role, region join codes"
```

---

### Task 7: Rate limits, proxy IP, no CORS

**Files:**
- Modify: `apps/backend/src/app.module.ts`, `apps/backend/src/main.ts`, `apps/backend/src/auth/controllers/auth.controller.ts`

- [ ] **Step 1: Throttler** — `app.module.ts`

Replace the commented throttler import/config with:

```ts
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
```

in `imports`:

```ts
    // Volunteers often share one Wi-Fi/carrier IP: a high backstop only;
    // the strict limits are on the auth routes (security spec §5.1).
    ThrottlerModule.forRoot([{ name: 'default', ttl: 60_000, limit: 600 }]),
```

in `providers`: `{ provide: APP_GUARD, useClass: ThrottlerGuard }`.

- [ ] **Step 2: Strict limits on auth routes** — `auth.controller.ts`

`import { Throttle } from '@nestjs/throttler';` then:
- `login`: `@Throttle({ default: { limit: 10, ttl: 60_000 } })`
- `registerLocal`: `@Throttle({ default: { limit: 5, ttl: 600_000 } })`
- `refreshToken`: `@Throttle({ default: { limit: 30, ttl: 60_000 } })`

- [ ] **Step 3: Real client IP, no CORS** — `main.ts`

```ts
import { NestExpressApplication } from '@nestjs/platform-express';
...
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    bufferLogs: true,
  });
  // Caddy is the one proxy in front: trust its X-Forwarded-For so rate
  // limits count phones, not Caddy.
  app.set('trust proxy', 1);
```

Delete `// CORS configuration` and `app.enableCors();` — the client is a native app and `/download` is same-origin.

- [ ] **Step 4: Verify and commit**

Backend check.

```bash
git add apps/backend/src
git commit -m "feat(backend): rate limits on auth routes, trust Caddy's forwarded IP, no CORS"
```

---

### Task 8: App — account states, failures, register call, strings

**Files:**
- Modify: `apps/mobile/lib/features/auth/domain/user.dart`, `apps/mobile/lib/core/network/app_failure.dart`, `apps/mobile/lib/core/network/failure_text.dart`, `apps/mobile/lib/core/network/auth_interceptor.dart`, `apps/mobile/lib/core/providers.dart`, `apps/mobile/lib/features/auth/presentation/auth_controller.dart`, `apps/mobile/lib/features/auth/data/auth_repository.dart`, `apps/mobile/lib/l10n/app_en.arb`, `app_fr.arb`, `app_ar.arb` (+ regenerated `app_localizations*.dart`)

**Interfaces:**
- Produces:
  - `User.status` (`String`, `'active'` default), `User.isRegionAdmin`, `User.canManageVolunteers`, `User.isAccountDisabled` (getter)
  - `AccountPendingFailure extends UnauthorizedFailure`; `AccountDisabledFailure` unchanged; `InvalidJoinCodeFailure extends ValidationFailure`; codes on `ForbiddenFailure.regionForbidden = 'REGION_FORBIDDEN'`
  - `sessionExpiredEventsProvider` → `StreamController<AppFailure>`
  - `enum RegisterOutcome { active, pending }`; `AuthRepository.register({..., String? joinCode, int? regionId})` → `Future<RegisterOutcome>`
  - All l10n keys listed in Step 7.

- [ ] **Step 1: User model** — `user.dart`, class `User`

Replace `isAccountDisabled` field/param with `this.status = 'active'` (`final String status;`), parse `status: (json['status'] as String?) ?? (json['isAccountDisabled'] == true ? 'disabled' : 'active')`, serialize `'status': status`, and add:

```dart
  bool get isAccountDisabled => status == 'disabled';

  /// Coordinator of [region] (security spec §2).
  bool get isRegionAdmin => roles.contains('REGION_ADMIN');

  /// Sees Profile → Volunteers.
  bool get canManageVolunteers => isAdmin || isRegionAdmin;
```

Search `isAccountDisabled:` constructor uses (`grep -rn "isAccountDisabled" apps/mobile/lib`) and remove the argument.

- [ ] **Step 2: Failures** — `app_failure.dart`

After `AccountDisabledFailure` add:

```dart
/// Registered without a join code; a coordinator has not approved it yet.
final class AccountPendingFailure extends UnauthorizedFailure {
  const AccountPendingFailure()
    : super('This account is waiting for approval.');

  static const code = 'ACCOUNT_PENDING';
}
```

Give `AccountDisabledFailure` `static const code = 'ACCOUNT_DISABLED';`. Change `ForbiddenFailure` to carry the region code:

```dart
class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure([
    super.message = 'You are not allowed to perform this action.',
  ]);

  /// The account can't act in that region (security spec §2).
  static const regionForbidden = 'REGION_FORBIDDEN';
}
```

After `ValidationFailure` add:

```dart
/// 400 INVALID_JOIN_CODE on register.
final class InvalidJoinCodeFailure extends ValidationFailure {
  const InvalidJoinCodeFailure() : super('This join code is not valid.');

  static const code = 'INVALID_JOIN_CODE';
}
```

In `failureFromResponse`:

```dart
    case 400:
      if (code == InvalidJoinCodeFailure.code) {
        return const InvalidJoinCodeFailure();
      }
      return ValidationFailure(message ?? 'Some fields are invalid.');
    case 401:
      if (code == AccountPendingFailure.code) {
        return const AccountPendingFailure();
      }
      if (code == AccountDisabledFailure.code) {
        return const AccountDisabledFailure();
      }
      return UnauthorizedFailure(
        message == null || message == 'Unauthorized'
            ? const UnauthorizedFailure().message
            : message,
      );
```

- [ ] **Step 3: Texts** — `failure_text.dart`

Add, above `AccountDisabledFailure() => ...`:

```dart
  AccountPendingFailure() => l.errAccountPending,
```

and above `ValidationFailure(:final message) => message,`:

```dart
  InvalidJoinCodeFailure() => l.errInvalidJoinCode,
```

Change `AccountDisabledFailure() => l.errAccountDisabled` text in the arb (Step 7) to "This account is disabled. Ask your coordinator."

- [ ] **Step 4: Sign-out carries the reason**

`providers.dart`:

```dart
/// Emits why the server ended the session; the auth controller signs out.
final sessionExpiredEventsProvider = Provider<StreamController<AppFailure>>((
  ref,
) {
  final controller = StreamController<AppFailure>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});
```

and `onSessionExpired: (reason) { if (!events.isClosed) events.add(reason); },` (import `network/app_failure.dart`).

`auth_interceptor.dart`:
- `final void Function(AppFailure reason) onSessionExpired;` (import `app_failure.dart`).
- Field `AppFailure? _refreshFailure;`.
- In `_refresh`'s `on DioException catch (e)`: before `return null;` add `_refreshFailure = failureFromResponse(e.response?.statusCode, e.response?.data);`. At the top of `_refresh`: `_refreshFailure = null;`.
- Both `onSessionExpired();` calls become:

```dart
        onSessionExpired(_sessionEndReason(err));
```

with the helper:

```dart
  /// Disabled or pending accounts get their own message on the login page.
  AppFailure _sessionEndReason(DioException err) {
    final fromResponse = failureFromResponse(
      err.response?.statusCode,
      err.response?.data,
    );
    final reason = _refreshFailure ?? fromResponse;
    return reason is UnauthorizedFailure ? reason : const UnauthorizedFailure();
  }
```

(For the retry branch pass `retryError` instead of `err`.)

`auth_controller.dart` `build`: `.listen((reason) => _signOut(reason: reason));`.

- [ ] **Step 5: Register call** — `auth_repository.dart`

```dart
/// Whether a new account can sign in now or waits for a coordinator.
enum RegisterOutcome { active, pending }
```

Interface and implementation:

```dart
  Future<RegisterOutcome> register({
    required String name,
    required String username,
    required String email,
    required String password,
    String? joinCode,
    int? regionId,
  });
```

```dart
  @override
  Future<RegisterOutcome> register({
    required String name,
    required String username,
    required String email,
    required String password,
    String? joinCode,
    int? regionId,
  }) async {
    final code = joinCode?.trim() ?? '';
    try {
      final envelope = await _api.post(
        '/auth/register',
        body: {
          'name': name.trim(),
          'username': username.trim(),
          'email': email.trim(),
          'password': password,
          if (code.isNotEmpty) 'joinCode': code,
          if (code.isEmpty && regionId != null) 'region': {'id': regionId},
        },
        extra: _public,
      );
      return envelope.object['status'] == 'pending'
          ? RegisterOutcome.pending
          : RegisterOutcome.active;
    } on ConflictFailure {
      throw const ConflictFailure(
        'Username or email is already in use',
        code: ConflictFailure.usernameTaken,
      );
    }
  }
```

`login`: replace the `on UnauthorizedFailure catch (e)` block with

```dart
    } on AccountPendingFailure {
      rethrow;
    } on AccountDisabledFailure {
      rethrow;
    } on UnauthorizedFailure {
      throw const InvalidCredentialsFailure();
    }
```

- [ ] **Step 6: Fix callers of `register`**

`register_page.dart` currently passes `regionId: _regionId!`; Task 9 rewrites the call. For this task make it compile: `final outcome = await ... register(..., regionId: _regionId);` and keep the existing navigation (Task 9 uses `outcome`). Add `// ignore: unused_local_variable` only if analyze complains, and remove it in Task 9.

- [ ] **Step 7: Strings** — add to all three `.arb` files (before the closing `}`; keep the trailing-comma style of each file)

`app_en.arb`:

```json
  "joinCodeHint": "Join code (if you have one)",
  "joinCodeHelp": "With your region's code you can start at once. Without it, a coordinator approves your account.",
  "errInvalidJoinCode": "This code isn't valid. Check it with your coordinator.",
  "errAccountPending": "This account is waiting for a coordinator's approval.",
  "pendingTitle": "Waiting for approval",
  "pendingBody": "Your account is created. A coordinator of your region must approve it before you can sign in. You can ask them directly.",
  "backToSignIn": "Back to sign in",
  "teamSection": "Team",
  "volunteers": "Volunteers",
  "joinCodeTitle": "Join code",
  "joinCodeOff": "Joining by code is off. New volunteers wait for approval.",
  "joinCodeShare": "Share",
  "joinCodeNew": "New code",
  "joinCodeTurnOn": "Create a code",
  "joinCodeTurnOff": "Turn off",
  "joinCodeNewTitle": "Make a new code?",
  "joinCodeNewBody": "The current code stops working at once. Accounts already created stay active.",
  "joinCodeOffTitle": "Turn off joining by code?",
  "joinCodeOffBody": "New volunteers will have to wait for approval.",
  "joinCodeShareMessage": "Join the iftar volunteers of {region}: install the app, tap Create account and enter the code {code}.",
  "@joinCodeShareMessage": {"placeholders": {"region": {"type": "String"}, "code": {"type": "String"}}},
  "tabWaiting": "Waiting",
  "tabActive": "Active",
  "tabDisabled": "Disabled",
  "tabWithCount": "{label} · {count}",
  "@tabWithCount": {"placeholders": {"label": {"type": "String"}, "count": {"type": "int"}}},
  "approve": "Approve",
  "refuse": "Refuse",
  "disable": "Disable",
  "enable": "Enable",
  "refuseTitle": "Refuse {name}?",
  "@refuseTitle": {"placeholders": {"name": {"type": "String"}}},
  "refuseBody": "Their account is deleted. They can register again.",
  "disableTitle": "Disable {name}?",
  "@disableTitle": {"placeholders": {"name": {"type": "String"}}},
  "disableBody": "They are signed out on their next action and can't sign in until enabled again.",
  "makeCoordinator": "Make coordinator",
  "makeVolunteer": "Make volunteer",
  "moveToRegion": "Move to region",
  "coordinator": "Coordinator",
  "joinedWithCode": "Joined with code",
  "noneWaiting": "Nobody is waiting for approval.",
  "noneActive": "No active volunteers yet.",
  "noneDisabled": "No disabled accounts.",
  "allRegions": "All regions"
```

`app_fr.arb`:

```json
  "joinCodeHint": "Code d’accès (si vous en avez un)",
  "joinCodeHelp": "Avec le code de votre région, vous commencez tout de suite. Sans code, un coordinateur valide votre compte.",
  "errInvalidJoinCode": "Ce code n’est pas valide. Vérifiez-le avec votre coordinateur.",
  "errAccountPending": "Ce compte attend la validation d’un coordinateur.",
  "pendingTitle": "En attente de validation",
  "pendingBody": "Votre compte est créé. Un coordinateur de votre région doit le valider avant que vous puissiez vous connecter. Vous pouvez le lui demander directement.",
  "backToSignIn": "Retour à la connexion",
  "teamSection": "Équipe",
  "volunteers": "Bénévoles",
  "joinCodeTitle": "Code d’accès",
  "joinCodeOff": "L’accès par code est désactivé. Les nouveaux bénévoles attendent une validation.",
  "joinCodeShare": "Partager",
  "joinCodeNew": "Nouveau code",
  "joinCodeTurnOn": "Créer un code",
  "joinCodeTurnOff": "Désactiver",
  "joinCodeNewTitle": "Créer un nouveau code ?",
  "joinCodeNewBody": "Le code actuel cesse de fonctionner tout de suite. Les comptes déjà créés restent actifs.",
  "joinCodeOffTitle": "Désactiver l’accès par code ?",
  "joinCodeOffBody": "Les nouveaux bénévoles devront attendre une validation.",
  "joinCodeShareMessage": "Rejoignez les bénévoles de l’iftar de {region} : installez l’application, touchez Créer un compte et saisissez le code {code}.",
  "tabWaiting": "En attente",
  "tabActive": "Actifs",
  "tabDisabled": "Désactivés",
  "tabWithCount": "{label} · {count}",
  "approve": "Valider",
  "refuse": "Refuser",
  "disable": "Désactiver",
  "enable": "Réactiver",
  "refuseTitle": "Refuser {name} ?",
  "refuseBody": "Son compte est supprimé. Il ou elle peut s’inscrire à nouveau.",
  "disableTitle": "Désactiver {name} ?",
  "disableBody": "Déconnexion à sa prochaine action, et plus de connexion possible jusqu’à réactivation.",
  "makeCoordinator": "Nommer coordinateur",
  "makeVolunteer": "Repasser bénévole",
  "moveToRegion": "Changer de région",
  "coordinator": "Coordinateur",
  "joinedWithCode": "Inscrit avec le code",
  "noneWaiting": "Personne n’attend de validation.",
  "noneActive": "Aucun bénévole actif pour l’instant.",
  "noneDisabled": "Aucun compte désactivé.",
  "allRegions": "Toutes les régions"
```

`app_ar.arb`:

```json
  "joinCodeHint": "رمز الانضمام (إن وُجد)",
  "joinCodeHelp": "برمز منطقتك تبدأ فورًا. بدونه، يوافق منسّق على حسابك.",
  "errInvalidJoinCode": "هذا الرمز غير صالح. تحقّق منه مع منسّقك.",
  "errAccountPending": "هذا الحساب في انتظار موافقة المنسّق.",
  "pendingTitle": "في انتظار الموافقة",
  "pendingBody": "تمّ إنشاء حسابك. يجب أن يوافق عليه منسّق منطقتك قبل أن تتمكّن من الدخول. يمكنك أن تطلب منه ذلك مباشرة.",
  "backToSignIn": "العودة إلى تسجيل الدخول",
  "teamSection": "الفريق",
  "volunteers": "المتطوّعون",
  "joinCodeTitle": "رمز الانضمام",
  "joinCodeOff": "الانضمام بالرمز متوقّف. ينتظر المتطوّعون الجدد الموافقة.",
  "joinCodeShare": "مشاركة",
  "joinCodeNew": "رمز جديد",
  "joinCodeTurnOn": "إنشاء رمز",
  "joinCodeTurnOff": "إيقاف",
  "joinCodeNewTitle": "إنشاء رمز جديد؟",
  "joinCodeNewBody": "يتوقّف الرمز الحالي فورًا. تبقى الحسابات المنشأة نشطة.",
  "joinCodeOffTitle": "إيقاف الانضمام بالرمز؟",
  "joinCodeOffBody": "سيتعيّن على المتطوّعين الجدد انتظار الموافقة.",
  "joinCodeShareMessage": "انضمّ إلى متطوّعي الإفطار في {region}: ثبّت التطبيق، اضغط على إنشاء حساب وأدخل الرمز {code}.",
  "tabWaiting": "في الانتظار",
  "tabActive": "نشطون",
  "tabDisabled": "معطّلون",
  "tabWithCount": "{label} · {count}",
  "approve": "موافقة",
  "refuse": "رفض",
  "disable": "تعطيل",
  "enable": "تفعيل",
  "refuseTitle": "رفض {name}؟",
  "refuseBody": "يُحذف حسابه. يمكنه التسجيل من جديد.",
  "disableTitle": "تعطيل {name}؟",
  "disableBody": "يُسجَّل خروجه عند إجرائه التالي ولا يمكنه الدخول حتى يُعاد تفعيله.",
  "makeCoordinator": "تعيين منسّقًا",
  "makeVolunteer": "إرجاعه متطوّعًا",
  "moveToRegion": "نقل إلى منطقة",
  "coordinator": "منسّق",
  "joinedWithCode": "انضمّ بالرمز",
  "noneWaiting": "لا أحد ينتظر الموافقة.",
  "noneActive": "لا متطوّعين نشطين بعد.",
  "noneDisabled": "لا حسابات معطّلة.",
  "allRegions": "كل المناطق"
```

Also update existing keys in all three files:
- `passwordTooShort`: en "Use at least 8 characters.", fr "Au moins 8 caractères.", ar "8 أحرف على الأقل."
- `errAccountDisabled`: en "This account is disabled. Ask your coordinator.", fr "Ce compte est désactivé. Adressez-vous à votre coordinateur.", ar "هذا الحساب معطّل. تواصل مع منسّقك."

Edit `.arb` files with the Edit tool (LF line endings; the Windows-Python CRLF pitfall applies to scripts).

- [ ] **Step 8: Verify and commit**

Mobile check (regenerates l10n). Expected: `No issues found!`.

```bash
git add apps/mobile/lib
git commit -m "feat(mobile): pending/disabled account states, join code register call, sign-out reason, new strings"
```

---

### Task 9: App — join code on Register, Waiting for approval page

**Files:**
- Create: `apps/mobile/lib/features/auth/presentation/pending_page.dart`
- Modify: `apps/mobile/lib/features/auth/presentation/register_page.dart`, `apps/mobile/lib/features/auth/presentation/login_page.dart`, `apps/mobile/lib/core/router/app_router.dart`

**Interfaces:**
- Consumes: `RegisterOutcome`, `AccountPendingFailure`, `InvalidJoinCodeFailure`, l10n keys (Task 8).
- Produces: public route `/pending`.

- [ ] **Step 1: Pending page** — `pending_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import 'auth_scaffold.dart';

/// After registering without a join code, or signing in before approval
/// (security spec §8).
class PendingPage extends StatelessWidget {
  const PendingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AuthScaffold(
      title: l.pendingTitle,
      lead: l.pendingBody,
      switchLabel: l.backToSignIn,
      onSwitch: () => context.go('/login'),
      child: EmptyView(
        icon: Icons.hourglass_top_rounded,
        title: l.pendingTitle,
        action: FilledButton(
          onPressed: () => context.go('/login'),
          child: Text(l.backToSignIn),
        ),
      ),
    );
  }
}
```

Check `AuthScaffold`'s constructor (`auth_scaffold.dart`) for the exact parameter names (`title`, `lead`, `switchLabel`, `onSwitch`, `child` are used by `register_page.dart`) and `EmptyView`'s (`icon`, `title`, `message`, `action`).

- [ ] **Step 2: Route** — `app_router.dart`

`const _publicRoutes = {'/welcome', '/login', '/register', '/pending'};` and add `GoRoute(path: '/pending', builder: (_, _) => const PendingPage()),` after `/register` (import `pending_page.dart`).

- [ ] **Step 3: Register page**

In `_RegisterPageState`:
- Add `final _joinCode = TextEditingController();` (dispose it with the others) and in `initState` (create one) `_joinCode.addListener(() => setState(() {}));` so the region picker hides as soon as a code is typed.
- `bool get _hasCode => _joinCode.text.trim().isNotEmpty;`
- Submit:

```dart
      final outcome = await ref
          .read(authRepositoryProvider)
          .register(
            name: _name.text,
            username: _username.text,
            email: _email.text,
            password: _password.text,
            joinCode: _hasCode ? _joinCode.text : null,
            regionId: _hasCode ? null : _regionId,
          );
      if (!mounted) return;
      if (outcome == RegisterOutcome.pending) {
        context.go('/pending');
      } else {
        showAppSnackBar(context, AppLocalizations.of(context).accountCreated);
        context.pushReplacement('/login');
      }
```

- Catch the code error into the field instead of the banner: add `String? _joinCodeError;`, reset it with `_failure` at submit start, and

```dart
    } on InvalidJoinCodeFailure {
      if (mounted) {
        setState(
          () => _joinCodeError = AppLocalizations.of(context).errInvalidJoinCode,
        );
      }
    } on AppFailure catch (e) {
```

- Form: insert above `_RegionPicker`:

```dart
              PillTextField(
                controller: _joinCode,
                hint: l.joinCodeHint,
                icon: Icons.key_rounded,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.characters,
                errorText: _joinCodeError,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 12),
                child: Text(
                  l.joinCodeHelp,
                  style: TextStyle(color: context.colors.inkMuted, fontSize: 12),
                ),
              ),
              if (!_hasCode)
                _RegionPicker(...existing arguments...),
```

and the region validator only applies without a code (the picker is not in the tree with a code, so its validator doesn't run).

`PillTextField` (`core/widgets/pill_text_field.dart`) may lack `textCapitalization` / `errorText`; if so add both as optional parameters passed to the inner `TextFormField` / `InputDecoration` (`errorText: errorText`).

- Password validator: `if (v.length < 8) return l.passwordTooShort;` and the comment "Matches the backend rule (8–100 characters)."

- [ ] **Step 4: Login sends pending accounts to the page** — `login_page.dart` `_submit`

```dart
    } on AccountPendingFailure {
      if (mounted) context.go('/pending');
    } on AppFailure catch (e) {
```

(import `go_router` if not present.)

- [ ] **Step 5: Verify and commit**

Mobile check.

```bash
git add apps/mobile/lib
git commit -m "feat(mobile): join code on Register, Waiting for approval page"
```

---

### Task 10: App — Volunteers screen for coordinators and admins

**Files:**
- Create: `apps/mobile/lib/features/volunteers/domain/volunteer.dart`, `apps/mobile/lib/features/volunteers/data/volunteers_repository.dart`, `apps/mobile/lib/features/volunteers/presentation/volunteers_controller.dart`, `apps/mobile/lib/features/volunteers/presentation/volunteers_page.dart`, `apps/mobile/lib/features/volunteers/presentation/join_code_card.dart`
- Modify: `apps/mobile/lib/core/router/app_router.dart`, `apps/mobile/lib/features/profile/presentation/profile_page.dart`

**Interfaces:**
- Consumes: HTTP endpoints from Task 6; `User.canManageVolunteers`, `User.isAdmin`; `regionRepositoryProvider.listRegions()`; l10n keys (Task 8).
- Produces: route `/volunteers`.

- [ ] **Step 1: Model** — `volunteer.dart`

```dart
import '../../auth/domain/user.dart';

/// One account as the Volunteers screen sees it.
class Volunteer {
  const Volunteer({
    required this.id,
    required this.name,
    required this.username,
    required this.status,
    required this.roles,
    required this.joinedWithCode,
    this.region,
  });

  factory Volunteer.fromJson(Map<String, dynamic> json) {
    final region = json['region'];
    return Volunteer(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'active',
      roles: ((json['roles'] as List?) ?? const []).map((r) => '$r').toList(),
      joinedWithCode: json['joinedWithCode'] == true,
      region: region is Map<String, dynamic> ? Region.fromJson(region) : null,
    );
  }

  final int id;
  final String name;
  final String username;

  /// `pending`, `active` or `disabled`.
  final String status;
  final List<String> roles;
  final bool joinedWithCode;
  final Region? region;

  bool get isCoordinator => roles.contains('REGION_ADMIN');
  bool get isGlobalAdmin => roles.contains('ADMIN');
}
```

- [ ] **Step 2: Repository** — `volunteers_repository.dart`

```dart
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
```

(`'regionId': ?regionId` is Dart 3.8+ null-aware map element; the project is on Dart 3.12. If `ApiEnvelope.object` throws on a `204`/empty body, these void calls never read it — `refuse` returns 204 and only `_send` runs; confirm `_send` tolerates an empty body by reading `api_client.dart` lines 67–105 and, if not, make `ApiEnvelope` treat a null body as empty.)

- [ ] **Step 3: Controller** — `volunteers_controller.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/volunteers_repository.dart';
import '../domain/volunteer.dart';

/// The region the screen shows: the coordinator's own, or the one a global
/// admin picked (null = all regions, global admin only).
class SelectedRegion extends Notifier<int?> {
  @override
  int? build() => ref.read(authControllerProvider).value?.region?.id;

  void select(int? regionId) => state = regionId;
}

final selectedRegionProvider = NotifierProvider<SelectedRegion, int?>(
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
```

(import `../../auth/data/auth_repository.dart` for `regionRepositoryProvider`.)

- [ ] **Step 4: Join code card** — `join_code_card.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/failure_text.dart';
import '../../../core/theme/iftar_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/info_tile.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../data/volunteers_repository.dart';
import 'volunteers_controller.dart';

/// The region's code in large letters, with Share / New code / Turn off.
class JoinCodeCard extends ConsumerWidget {
  const JoinCodeCard({super.key, required this.regionId, required this.regionName});

  final int regionId;
  final String regionName;

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String body,
    String action,
  ) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(joinCodeProvider(regionId));
    } on AppFailure catch (e) {
      if (context.mounted) {
        showAppSnackBar(context, failureText(AppLocalizations.of(context), e), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final repo = ref.read(volunteersRepositoryProvider);
    final code = ref.watch(joinCodeProvider(regionId));
    return InfoCard(
      title: l.joinCodeTitle,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: code.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              failureText(l, toAppFailure(e)),
              style: TextStyle(color: c.clayInk),
            ),
            data: (value) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (value == null)
                  Text(l.joinCodeOff, style: TextStyle(color: c.inkMuted))
                else
                  SelectableText(
                    ltr(value),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (value != null)
                      FilledButton.icon(
                        icon: const Icon(Icons.ios_share_rounded),
                        label: Text(l.joinCodeShare),
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(text: l.joinCodeShareMessage(regionName, value)),
                        ),
                      ),
                    OutlinedButton(
                      onPressed: () async {
                        if (value != null &&
                            !await _confirm(context, l.joinCodeNewTitle, l.joinCodeNewBody, l.joinCodeNew)) {
                          return;
                        }
                        if (!context.mounted) return;
                        await _run(context, ref, () => repo.newJoinCode(regionId));
                      },
                      child: Text(value == null ? l.joinCodeTurnOn : l.joinCodeNew),
                    ),
                    if (value != null)
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: c.clayInk),
                        onPressed: () async {
                          if (!await _confirm(context, l.joinCodeOffTitle, l.joinCodeOffBody, l.joinCodeTurnOff)) {
                            return;
                          }
                          if (!context.mounted) return;
                          await _run(context, ref, () => repo.turnOffJoinCode(regionId));
                        },
                        child: Text(l.joinCodeTurnOff),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```

Check the color token names (`clayInk`, `inkMuted`) exist in `IftarColors` (`core/theme/iftar_colors.dart`) — they are used by `status_chip.dart` and `profile_page.dart`.

- [ ] **Step 5: Page** — `volunteers_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/failure_text.dart';
import '../../../core/theme/iftar_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/volunteers_repository.dart';
import '../domain/volunteer.dart';
import 'join_code_card.dart';
import 'volunteers_controller.dart';

/// Profile → Volunteers (security spec §8): join code, then accounts by
/// status. Coordinators see their region; global admins pick one.
class VolunteersPage extends ConsumerStatefulWidget {
  const VolunteersPage({super.key});

  @override
  ConsumerState<VolunteersPage> createState() => _VolunteersPageState();
}

class _VolunteersPageState extends ConsumerState<VolunteersPage> {
  String _tab = 'pending';

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
    } on AppFailure catch (e) {
      if (mounted) {
        showAppSnackBar(context, failureText(AppLocalizations.of(context), e), isError: true);
      }
    }
    ref.invalidate(volunteersProvider);
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(action)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _moveTo(Volunteer v, List<Region> regions) async {
    final regionId = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final r in regions)
              ListTile(
                title: Text(r.name),
                selected: r.id == v.region?.id,
                onTap: () => Navigator.pop(sheet, r.id),
              ),
          ],
        ),
      ),
    );
    if (regionId == null) return;
    await _act(
      () => ref.read(volunteersRepositoryProvider).changeRole(
        v.id,
        role: v.isCoordinator ? 'REGION_ADMIN' : 'USER',
        regionId: regionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final me = ref.watch(authControllerProvider).value;
    final isGlobal = me?.isAdmin == true;
    final regionId = ref.watch(selectedRegionProvider);
    final regions = isGlobal
        ? ref.watch(adminRegionsProvider).value ?? const <Region>[]
        : const <Region>[];
    final regionName = isGlobal
        ? regions.where((r) => r.id == regionId).map((r) => r.name).firstOrNull
        : me?.region?.name;
    final all = ref.watch(volunteersProvider);
    final repo = ref.read(volunteersRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.volunteers)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(volunteersProvider);
          if (regionId != null) ref.invalidate(joinCodeProvider(regionId));
          await ref.read(volunteersProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isGlobal)
              DropdownButtonFormField<int?>(
                initialValue: regionId,
                decoration: InputDecoration(labelText: l.region),
                items: [
                  DropdownMenuItem(value: null, child: Text(l.allRegions)),
                  for (final r in regions)
                    DropdownMenuItem(value: r.id, child: Text(r.name)),
                ],
                onChanged: (id) => ref.read(selectedRegionProvider.notifier).select(id),
              ),
            if (regionId != null) ...[
              const SizedBox(height: 16),
              JoinCodeCard(regionId: regionId, regionName: regionName ?? ''),
            ],
            const SizedBox(height: 16),
            all.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(
                failure: toAppFailure(e),
                onRetry: () => ref.invalidate(volunteersProvider),
              ),
              data: (list) {
                int count(String s) => list.where((v) => v.status == s).length;
                final shown = list.where((v) => v.status == _tab).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<String>(
                      segments: [
                        for (final (value, label) in [
                          ('pending', l.tabWaiting),
                          ('active', l.tabActive),
                          ('disabled', l.tabDisabled),
                        ])
                          ButtonSegment(
                            value: value,
                            label: Text(l.tabWithCount(label, count(value))),
                          ),
                      ],
                      selected: {_tab},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => setState(() => _tab = s.first),
                    ),
                    const SizedBox(height: 8),
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          switch (_tab) {
                            'pending' => l.noneWaiting,
                            'active' => l.noneActive,
                            _ => l.noneDisabled,
                          },
                          textAlign: TextAlign.center,
                          style: TextStyle(color: c.inkMuted),
                        ),
                      ),
                    for (final v in shown) ...[
                      _VolunteerRow(
                        volunteer: v,
                        showRegion: isGlobal && regionId == null,
                        actions: [
                          if (v.status == 'pending') ...[
                            (l.approve, () => _act(() => repo.approve(v.id))),
                            (
                              l.refuse,
                              () async {
                                if (await _confirm(l.refuseTitle(v.name), l.refuseBody, l.refuse)) {
                                  await _act(() => repo.refuse(v.id));
                                }
                              },
                            ),
                          ],
                          if (v.status == 'active' && v.id != me?.id && !v.isGlobalAdmin)
                            (
                              l.disable,
                              () async {
                                if (await _confirm(l.disableTitle(v.name), l.disableBody, l.disable)) {
                                  await _act(() => repo.disable(v.id));
                                }
                              },
                            ),
                          if (v.status == 'disabled')
                            (l.enable, () => _act(() => repo.enable(v.id))),
                          if (isGlobal && !v.isGlobalAdmin && v.region != null) ...[
                            (
                              v.isCoordinator ? l.makeVolunteer : l.makeCoordinator,
                              () => _act(
                                () => repo.changeRole(
                                  v.id,
                                  role: v.isCoordinator ? 'USER' : 'REGION_ADMIN',
                                  regionId: v.region!.id,
                                ),
                              ),
                            ),
                            (l.moveToRegion, () => _moveTo(v, regions)),
                          ],
                        ],
                      ),
                      const Divider(height: 1),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A hairline row: name, username and badges, actions in a menu.
class _VolunteerRow extends StatelessWidget {
  const _VolunteerRow({
    required this.volunteer,
    required this.showRegion,
    required this.actions,
  });

  final Volunteer volunteer;
  final bool showRegion;
  final List<(String, Future<void> Function())> actions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final v = volunteer;
    final details = [
      ltr('@${v.username}'),
      if (v.isCoordinator) l.coordinator,
      if (v.joinedWithCode) l.joinedWithCode,
      if (showRegion && v.region != null) v.region!.name,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(v.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(details, style: TextStyle(color: c.inkMuted)),
      trailing: actions.isEmpty
          ? null
          : PopupMenuButton<int>(
              onSelected: (i) => actions[i].$2(),
              itemBuilder: (_) => [
                for (var i = 0; i < actions.length; i++)
                  PopupMenuItem(value: i, child: Text(actions[i].$1)),
              ],
            ),
    );
  }
}
```

Notes for the implementer: `DropdownButtonFormField.initialValue` is the Flutter 3.35+ name (older: `value`); `ErrorView`, `showAppSnackBar` come from `state_views.dart`; `ltr` from `core/utils/formatters.dart`. For a waiting volunteer, Approve is the most common action — keep it first in the menu. If `flutter analyze` flags `firstOrNull`, import `package:collection/collection.dart` or use a loop.

- [ ] **Step 6: Route and Profile entry**

`app_router.dart`: import `../../features/volunteers/presentation/volunteers_page.dart` and add

```dart
      GoRoute(
        path: '/volunteers',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const VolunteersPage(),
      ),
```

`profile_page.dart`: before the "Settings" `InfoCard`, when `user.canManageVolunteers`:

```dart
                if (user.canManageVolunteers) ...[
                  InfoCard(
                    title: l.teamSection,
                    children: [
                      InfoTile(
                        icon: Icons.groups_rounded,
                        label: l.volunteers,
                        showPlaceholder: false,
                        trailing: chevron,
                        onTap: () => context.push('/volunteers'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
```

(`user` and `chevron` are already in scope in `build`; import `go_router` if absent.)

- [ ] **Step 7: Verify and commit**

Mobile check. Expected: `No issues found!`.

```bash
git add apps/mobile/lib
git commit -m "feat(mobile): Volunteers screen with join code, approve/refuse/disable/enable, coordinator and region for global admins"
```

---

### Task 11: Smoke check, docs, spec status

**Files:**
- Modify: `docs/superpowers/specs/2026-10-09-security-region-access-design.md` (status line), `docs/MIGRATION_REPORT.md` §6 items 5–6, `README.md` (env table: note that `.env` is not committed)

- [ ] **Step 1: Run the backend locally**

Use the existing dev stack if it runs (`docker ps` shows `iftar-test-api` and `iftar-test-db`), otherwise start Postgres and the API per README. Then run migrations:

```bash
MSYS_NO_PATHCONV=1 docker exec -w /app iftar-test-api npm run migration:run
```

- [ ] **Step 2: Manual smoke list with curl** (base `http://localhost:3300/api/v1` for the dev stack; adjust)

Record each result (status code) in the commit message body or a scratch note:

1. Login as `admin` → 200. Create a second region if only one exists (`POST /regions`).
2. `POST /regions/1/join-code` as admin → `{ joinCode: "WORD-1234" }`.
3. Register `vol1` with `joinCode: " word-1234 "` (lower case, spaces) → 201, `status: active`.
4. Register `vol2` with `region: {id: 1}` and no code → 201, `status: pending`; login `vol2` → 401 `ACCOUNT_PENDING`.
5. Register with `joinCode: "NOPE-0000"` → 400 `INVALID_JOIN_CODE`.
6. As `vol1`: `GET /fastings/1` → 200; `GET /fastings/2` → 403 `REGION_FORBIDDEN`; `GET /fastings` → 403; `DELETE /fastings/1/<id>` → 403; `PATCH /fastings/1/<id>` with `region: {id: 2}` → 403; `GET /users` → 403; `GET /regions/1/join-code` → 403.
7. Make `vol1` coordinator: `PATCH /users/<vol1>/role {role: REGION_ADMIN, regionId: 1}` as admin → 200. With vol1's **existing** token: `GET /users` → 200 (only region 1); `POST /users/<vol2>/approve` → 200; `POST /users/<admin>/disable` → 404.
8. As admin `POST /users/<vol2>/disable` → 200; with vol2's existing token `GET /users/me` → 401 `ACCOUNT_DISABLED`; refresh → 401.
9. 11 logins in a minute from one IP → the 11th is 429; 50 quick `GET /fastings/1` → all 200.
10. `curl -I -H "Origin: https://evil.example" .../health` → no `Access-Control-Allow-Origin` header.

Fix anything that fails in the owning task's files and commit the fix separately (`fix: ...`).

- [ ] **Step 3: Docs**

- Spec status line → `Status: implemented on feat/security-region-access (2026-10-…)`.
- `MIGRATION_REPORT.md` §6: item 5 → "Secrets removed from the repo; rotation steps in DEPLOYMENT.md (to do by the owner)". Item 6 → "Done: region access control (security spec 2026-10-09)".
- `README.md` backend section: after `cp .env.template .env`, note "`.env` files are git-ignored; never commit real values".

- [ ] **Step 4: Commit**

```bash
git add docs README.md
git commit -m "docs: security spec implemented, rotation steps, region access control done"
```
