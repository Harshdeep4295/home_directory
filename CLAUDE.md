# CLAUDE.md — Offline Home (working name)

Read this first, every session. If `docs/HANDOFF.md` exists, read it next (current state + what is left). Then read `docs/PLAN.md` (what and why), `docs/TASKS.md`
(what to do next) and `docs/PSEUDOCODE.md` (how each module should behave).

## What we are building

A Flutter app (Android + iOS, one codebase) that discovers smart plugs, switches and bulbs on
the home Wi-Fi and controls them **directly over the LAN, with no internet and no vendor
cloud**, by tap or by **offline voice** (English + Hinglish), including timers
("geyser on for 20 minutes", "AC band karo 11 baje").

Personal, open-source, non-commercial project. Built on a MacBook, installed on the owner's
own Android phone and iPhone via `flutter run` (iOS signed with a free Apple ID).

## Non-negotiable rules

1. **No internet on the control path.** Discovery, control, state, voice and timers must work
   with the router's WAN cable unplugged. The ONLY code allowed to reach the internet lives in
   `lib/onboarding/cloud_import/` and runs only when the user explicitly starts an import.
2. **Never invent protocol constants.** Ports, packet layouts, command IDs, data-point (DP)
   numbers, crypto modes: port them from the reference implementations listed in
   `docs/PLAN.md §6` and cite the source file in a code comment. If unsure, write a failing
   test + a `// VERIFY:` comment and flag it in your task summary. `PSEUDOCODE.md` marks such
   spots with `VERIFY`.
3. **Every adapter is tested against a simulator** in `sim/` before it is considered done.
   Real-hardware checks are done by the human and recorded in `docs/HARDWARE_LOG.md`.
4. **Device-native timers first.** Only fall back to phone-side timers when the adapter has no
   countdown capability; always tell the user which tier a timer is running on.
5. **Secrets** (Tuya local keys, account credentials, Hue usernames) go only through
   `SecretStore` (Keychain / Keystore). Never log them, never write them to SQLite in clear.
6. **Audio never leaves the device.** Speech recognition must run in on-device mode.
7. Keep the platform-native code thin: only what Dart cannot do (Wi-Fi network binding,
   foreground service, exact alarms, local-network permission, Bonjour browsing).

## How to work a task

1. Open `docs/TASKS.md`, pick the first unchecked task whose `deps` are all checked.
2. Read its section in `docs/PSEUDOCODE.md`. State a short plan before writing code.
3. Implement. Write/extend tests named in the task's acceptance criteria.
4. Run, and make green: `cd app && dart format . && flutter analyze && flutter test`
   (and `cd sim && pytest` when you touched simulators).
5. Tick the task in `docs/TASKS.md`, add a one-line note under it (what was done, any VERIFY
   left open). Commit with message `T<id>: <title>`.
6. If a task is too big for one session, split it into sub-tasks in `TASKS.md` first.

## Branches and PRs

- One commit per task (`T<id>: <title>`), on the working branch.
- One PR per milestone into `main`. Each milestone PR stands alone: it starts from the latest
  `main` (after the previous milestone's PR is merged), and CI must be green before merging.
- `make test` locally before pushing; CI (`.github/workflows/ci.yml`) runs the same checks.

## Repo layout (target)

```
home_directory/          (repo root; project working name "Offline Home")
  CLAUDE.md  Makefile  LICENSE  .github/workflows/ci.yml
  docs/        PLAN.md  TASKS.md  PSEUDOCODE.md  HARDWARE_LOG.md
  spike/       Python scripts used to explore real devices (human-owned)
  sim/         Python device simulators + pytest (used by Flutter integration tests)
  app/         Flutter app
    lib/ core/ net/ registry/ discovery/ adapters/ engine/ timers/ voice/ onboarding/ ui/
    android/   Kotlin plugin: LanBinding, TimerService
    ios/       Swift plugin: LocalNetwork
    test/  integration_test/
```

## Conventions

- Dart 3, null-safe, `riverpod` for state, `drift` for SQLite, `freezed` for models.
- Generated code (`*.g.dart`, `*.freezed.dart`) is committed. After changing a model or table run
  `make codegen`; CI fails if generated code is stale (`make codegen-check`).
- Every network call has a timeout (default 1500 ms LAN) and returns `Result<T, DeviceError>`;
  adapters never throw across their public interface.
- All sockets are created through `LanSocketFactory` (so Android binds them to Wi-Fi).
- Logging via `log.d/i/w/e` with a `tag`; redact anything from `SecretStore`.
- Tests: unit tests next to the feature in `test/`. Simulator-backed adapter tests live in
  `test/sim/` (tag `sim`; they spawn `sim/run.py` via `test/support/sim_process.dart`, Python
  from `$OH_PYTHON` or `python3`) — `integration_test/` is reserved for on-device tests.
  Every adapter runs `adapterContractTest()` against its simulator. Voice parser has a golden
  corpus in `test/voice/corpus/*.yaml`.

## Owner context

Senior backend engineer (Python-first, prior Android/Kotlin). Prefers direct, practical
output. Devices at home: Wipro and Syska (likely Tuya-based), Philips (likely WiZ), 3 Echo Dots
(out of scope), a Fire TV Stick (TV control deferred).
