# AGENT.md — MirrorStages Desktop

Rules for AI agents (and humans) working in this repo. This reflects the
actual stack — do not introduce patterns from generic Flutter guides.

## Stack

- Flutter desktop (macOS / Windows / Linux), **Cupertino widgets** — no Material.
- State: **provider + ChangeNotifier MVVM**. One `AppViewModel` drives the UI.
- DI: **manual constructor injection**, wired in `AppService.production()`.
  No get_it / injectable.
- JSON: **hand-written `fromJson` factories** with `core/utils/json_coercion.dart`
  helpers. No json_serializable / freezed.
- Navigation: none (a sidebar switches `NavSection`s). No GoRouter.
- HTTP: thin `ApiClient` wrapper over `package:http`.

## Layer map

```
lib/
├── main.dart      window bootstrap only
├── app/           composition + shared state: MirrorStagesApp, AppConfig,
│   │              AppViewModel, AppService (facade), exceptions
│   ├── initialization/  step-based tool init (InitStep, ToolInitializer,
│   │              per-tool step factories) — see docs/initialization.md
│   ├── gost/      GostController: download → launch → configure the local
│   │              go-gost proxy over its API — see docs/gost.md
│   └── models/    UI-facing aggregates: AppSnapshot, AccountSummary,
│                  LocalConfigurationStatus, NavSection
├── core/          generic, domain-free: ApiClient, utils (json/jwt/formatters)
├── data/          remote APIs, DTOs, SessionStore
├── system/        local-machine integration: dart:io, Process.run,
│                  MethodChannel (home dir, env file, process inspector,
│                  root certificate, codex config + backup, gost binary +
│                  process)
├── ui/widgets/    design-system widgets, business-agnostic
└── features/      screens by content: shell/ dashboard/ settings/ auth/
```

**Dependency rule** (imports must point this way only):
`features → { app, data, system, ui, core }`; `app → { data, system, ui, core }`;
`data → core`; `system → core`; `ui → core`.
Exception: `app/app.dart` is the composition root and may import `features/`.

## Conventions

- Name files/dirs/classes by concrete content. Avoid redundant domain
  prefixes — the whole app is a control panel, so `control_panel_*` says
  nothing.
- Constants (URLs, asset paths) go in `app/app_config.dart`. The platform
  channel is `system/platform_channel.dart` and must stay in sync with
  `macos/Runner/MainFlutterWindow.swift`.
- Colors come from `ui/app_colors.dart` (`AppColors.*`) — never inline a
  `Color(0x...)` literal in a widget; add a named token instead.
- OS-specific work (Process.run, file IO under `~`, trust stores) belongs in
  `system/`, one class per concern, returning primitives — the `AppService`
  facade assembles them into `app/models/` values.
- View models stay free of `dart:io`; widgets stay free of business logic
  (state→copy/color mappings live in `features/*/**_presentation.dart`).
- Tests: fakes implement the facade (`class Fake implements AppService`),
  never `extends`. Pure functions get plain unit tests under `test/`.
- No new dependencies without discussion.
- `flutter analyze lib/ test/` must stay at zero issues.
