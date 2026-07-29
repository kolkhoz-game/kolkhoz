# Codex Guidelines

## Before You Start

Read the agent documentation in `agent-docs/`:
1. `OVERVIEW.md` - Project structure and quick start
2. `ARCHITECTURE.md` - How the codebase is organized
3. `GAME_STATE.md` - State shape and state mutations
4. `PHASES.md` - Game phase flow and transitions

For any task that generates raster masters, segments depth, creates or edits depth
cards, changes the Figma world file, or exports world plates, always read
`design/field-plan-world/DEPTH_CARD_PIPELINE.md`.

## Code Principles

**Keep it simple.** This is a card game, not enterprise software. Prefer straightforward
solutions over clever abstractions.

**Follow the current owners:**
- **C engine** - Keep rules, legal actions, phase flow, AI, scoring, policy features, and deterministic simulation in `engine/KolkhozCEngine/`.
- **Flutter** - Keep app state, layout, animation, controls, and assets in `app/`.
- **Server** - Keep the authoritative online API, session execution, persistence, realtime transport, matchmaking, and deployment in `server/`.
- **Research** - Keep training, benchmarking, promotion gates, seed mining, and dashboards in [`kolkhoz-research`](https://github.com/kolkhoz-game/kolkhoz-research).
- **Tabletop** - Keep physical print sources, proofs, leaflet art, and vendor exports in [`kolkhoz-tabletop`](https://github.com/kolkhoz-game/kolkhoz-tabletop).

**Write minimal code:**
- Fix what's broken, don't refactor what works
- No premature abstractions or "just in case" code
- If three lines work, don't write a utility function
- Delete dead code, don't comment it out

**Test before committing:**
```bash
clang -std=c11 -I engine/KolkhozCEngine/include \
  -fsyntax-only engine/KolkhozCEngine/KolkhozCEngine.c
cd app
dart run tool/sync_policy_assets.dart
flutter analyze
flutter test
flutter build macos --debug
```

## Frontend Work

Use Flutter/web UI skills when changing app screens or layout. The Flutter app is the
visual and behavioral app source of truth.

### Playable Web Demo

The public tutorial and Easy-AI demo are deployed at
`https://play.kolkhoz.online/`. They are a generated build of this Flutter app,
not a separate implementation:

- Keep the UI, tutorial, rules, artwork, and game behavior in this repository.
- Keep game truth in the shared C engine. The web target compiles it to WebAssembly
  through `engine/KolkhozCEngine/KolkhozCEngineWeb.c`.
- Web sessions are deliberately offline and start fresh after reload. Do not add
  account, login, lobby, persistence, or server dependencies to the public build.
- The public demo keeps the normal app menu and exposes one fixed Easy-AI game plus
  Foreman Misha's tutorial.

Build the complete deployable artifact with:

```bash
./app/tool/build_web_demo.sh
```

The script regenerates the WebAssembly bridge, builds Flutter with
`KOLKHOZ_WEB_DEMO=true`, removes neural-policy assets the fixed demo cannot request,
and writes `app/build/web/`. Smoke-test both the tutorial and a real confirmed demo
action after changing rules, projections, tutorial content, or artwork.

Production deployment is owned by the public
`kolkhoz-game/kolkhoz-play` repository. Its **Deploy Kolkhoz Play** workflow checks
out a selected branch, tag, or commit from this repository, runs the build script, and
publishes the result to GitHub Pages. For a normal rebuild, merge the source change
here and dispatch that workflow with `kolkhoz_ref=master`. Do not copy Flutter source
or hand-edit generated build output in the deployment repository.

DNS is a Namecheap CNAME:

```text
play -> kolkhoz-game.github.io.
```

### macOS UI Iteration

For Flutter-only UI, layout, and animation work, start one long-lived
`cd app && flutter run -d macos` session and use hot reload while iterating. Run
targeted tests as needed, but reserve `flutter build macos --debug` and the full
verification suite for final handoff or changes to native C/FFI, plugins, signing, or
other build inputs that cannot hot reload.

This checkout may live inside Dropbox. Generated Flutter/Xcode output in `app/build/`
can acquire conflicted framework copies, stale symlinks, and extended attributes that
invalidate macOS code signatures and break Game Center. Before every macOS Flutter
build or `flutter run -d macos`, run:

```bash
./app/tool/use_local_flutter_build.sh
```

This is required, not optional. Do not run a macOS Flutter build when `app/build/` is a
real directory or resolves inside Dropbox. The setup script moves an existing Dropbox
build into a recoverable stale directory and links `app/build/` to an unsynced local
cache. The script rejects overrides that point back into Dropbox. Do not change the
user's global Flutter build directory.

## iPhone Deployment

Never deploy physical iPhones with Flutter debug builds. On iOS 14+, debug-mode Flutter
apps cannot be launched from the home screen; they only launch from Flutter tooling,
Flutter IDE plugins, or Xcode. For a device install the user can open normally, use:

```bash
cd app
./tool/deploy_ios_device_profile.sh
```

Pass a device id as the first argument only when targeting a different iPhone.

## Common Patterns

**Game logic** goes in `engine/KolkhozCEngine/`.

**Flutter models, adapters, and UI** go in `app/lib/`.

**Flutter assets** go in `app/assets/ui/`.

**Online server behavior and operations** go in `server/`.

**Research and model training** go in the `kolkhoz-research` repository.

**Physical print production** goes in the `kolkhoz-tabletop` repository.

**State changes** happen by applying portable engine actions through the Dart FFI bridge.
Flutter widgets should render projected state and call store actions.

## When Debugging

Check the phase flow in `agent-docs/PHASES.md`. Most bugs are phase transition issues,
C snapshot/projection issues, or Flutter UI state that drifted from the C engine.
