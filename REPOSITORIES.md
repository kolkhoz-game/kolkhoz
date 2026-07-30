# Kolkhoz Repository Map

The `kolkhoz-game` organization uses five repositories with one-way ownership
boundaries:

| Repository | Owns |
| --- | --- |
| [`kolkhoz`](https://github.com/kolkhoz-game/kolkhoz) | C engine, Python binding, Flutter app, online server, canonical rules, promoted runtime policies |
| [`kolkhoz-site`](https://github.com/kolkhoz-game/kolkhoz-site) | Public marketing site, expanded web rules, and how-to-play walkthrough |
| [`kolkhoz-play`](https://github.com/kolkhoz-game/kolkhoz-play) | Repeatable build and GitHub Pages deployment for `play.kolkhoz.online` |
| [`kolkhoz-research`](https://github.com/kolkhoz-game/kolkhoz-research) | Training, benchmarks, simulations, promotion gates, dashboards, and world-depth experiments |
| [`kolkhoz-tabletop`](https://github.com/kolkhoz-game/kolkhoz-tabletop) | Physical card, leaflet, proof, and print-vendor source artifacts |

## Dependency flow

```text
kolkhoz-research -- links --> kolkhoz/engine, server, policies, app, design
                 -- promotes reviewed runtime policy --> kolkhoz/policies

kolkhoz-tabletop -- links --> kolkhoz/app and kolkhoz/rules.txt
                 -- exports reviewed app-ready art --> kolkhoz/app/assets

kolkhoz-play -- checks out and builds --> kolkhoz/app

kolkhoz-site -- links users to --> kolkhoz-play
```

Core game behavior never flows back from the website, deployment shell, research
orchestration, or print sources. Change rules in the C engine first, then update the
consuming repositories deliberately.

## Recommended organization workspace

```text
programs/
  kolkhoz-game/
    kolkhoz/
    kolkhoz-site/
    kolkhoz-play/
    kolkhoz-research/
    kolkhoz-tabletop/
```

Open `kolkhoz-game/` as the Codex project for cross-repository work. The research and
tabletop setup scripts expect these sibling repositories and accept `KOLKHOZ_CORE_DIR`
for other arrangements.
