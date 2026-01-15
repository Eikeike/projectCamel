# Copilot / AI assistant instructions for project_camel

Purpose: Short, actionable guidance so an AI coding agent becomes productive quickly in this repository.

---

## Big picture (what this repo contains) ✅
- Two primary subsystems:
  - `trichter-device/` — Embedded firmware (Zephyr, NRF52832). See `trichter-device/README.rst` for build/setup.
  - `bierorgl_app/` — Flutter mobile app (Android/iOS/web). Main code under `lib/`.
- Communication:
  - BLE between phone and device (UUIDs and protocol in `lib/core/constants.dart` and `BleConstants`).
  - REST API for sync & auth: base URL in `lib/core/constants.dart` (AppConstants.apiBaseUrl).
- Data persistence: local SQLite DB (`sqflite`) via `lib/services/database_helper.dart` (tables: User, Event, Session, Metadata). Sync state tracked in `SyncStatus` enum.

## Key files to read first 🔎
- `lib/main.dart` — App entry, ProviderScope, `AuthGate` (login vs. home).
- `lib/auth/auth_providers.dart` — `AuthController` (`NotifierProvider`) and auth flow.
- `lib/services/database_helper.dart` — DB schema, debug helpers, sync helpers.
- `lib/services/sync_service.dart` & `lib/services/auto_sync_controller.dart` — push/pull sync logic and background debounce.
- `lib/repositories/*` — repositories that wrap DB + sync logic (e.g., `event_repository.dart`).
- `bierorgl_app/README.md` — quick usage examples (preferred provider patterns).

## Project-specific conventions & patterns 🧭
- State management: **Riverpod 3**. Use Notifier/NotifierProvider for controllers (e.g., `AuthController`), and FutureProvider/Provider for data.
- Prefer moving data loading into providers (see the README example `profileDataProvider`) and keep widgets thin. Use `ref.invalidate(...)` to refresh caches after writes.
- Repositories wrap DB + sync behavior. Where possible prefer repository methods (e.g., `eventRepo.saveEventForSync(...)`) instead of direct DB access.
- The DB is a singleton `DatabaseHelper()` in many places (legacy) — new code should prefer injecting `databaseHelperProvider` or pass `DatabaseExecutor` in sync contexts.
- Auth: tokens are stored in `flutter_secure_storage` and decoded with `jwt_decoder`. AuthRepository auto-refreshes tokens in its Dio interceptor.

## Important developer workflows & commands 🛠️
- Typical dev loop:
  - deps: `flutter pub get`
  - run app: `flutter run` (optionally specify `-d <device>`)
  - build (release): `flutter build apk` / `flutter build ios`
  - unit/widget tests: `flutter test` or single file `flutter test test/widget_test.dart`
  - static analysis: `flutter analyze` (rules in `analysis_options.yaml`)
  - format: `dart format .`
- Database debugging:
  - DB name: `bierorglDB.db` (see `DatabaseHelper._initDatabase()`)
  - On Android emulator: `adb exec-out run-as com.example.project_camel cat databases/bierorglDB.db > bierorglDB.db`
  - Use `DatabaseHelper().debugPrintTable('Event')` for quick prints.

## Network & sync specifics 🔁
- REST calls are made through `AuthRepository` (Dio). Important endpoints:
  - `POST /api/auth/login/` — login (returns access + refresh tokens)
  - `POST /api/auth/refresh/` — refresh token
  - `GET /api/sync/?since=<cursor>` — server-side changes; sync logic updates `Metadata.dbSequence`.
  - `POST/PUT/DELETE /api/events/` and `/api/sessions/` used when pushing local changes.
- Sync uses `SyncService` which runs `push()` then `pull()` and notifies app via a `StreamController<DbTopic>` bus. Respect transactional boundaries when updating DB inside `sync()`.

## Tests & CI notes ⚠️
- There are only basic widget tests (`test/widget_test.dart`) — no integration tests/CI workflows included. Add minimal unit tests for shared logic (e.g., repositories, sync edge cases) before refactors.
- Lints are configured (see `analysis_options.yaml`); follow existing styles.

## Safety notes & gotchas ⚠️
- Some files still create `DatabaseHelper()` directly (see `screens/*`). Prefer injecting providers or using repository methods when changing code.
- Auth flow decodes tokens locally (via `jwt_decoder`) and assumes `user_id` claim is present — avoid breaking that contract without migrating callers.
- `AuthController` writes `userID` into the DB currently (TODO marked). Keep an eye on this cross-cutting side-effect when changing auth logic.

## Small examples (copy-paste) 🧩
- Get current user in a screen:

  const SomeScreen(...)
  final authState = ref.watch(authControllerProvider);
  if (!authState.isAuthenticated) return const LoginScreen();

- Invalidate provider after write:

  await repo.saveEvent(event);
  ref.invalidate(allEventsProvider);

- Decode user id without network during startup (used by `AuthController`):

  await authRepository.getStoredUserIdAllowingExpired();

## Where to ask for clarification ❓
- If a change touches DB schema, sync protocol, or auth token format, ask a developer rather than guessing server behavior.
- For BLE behavior (device-side protocol), consult `trichter-device/README.rst` or the embedded code in `trichter-device/src/`.

---

If this looks good I can:
- Add a short `AGENT.md` with automated test suggestions and a checklist for safe DB/schema changes, or
- Expand any section you want more detail on (tests, CI, BLE protocol, or API contract examples).

Please tell me which sections to expand or any local conventions I missed.