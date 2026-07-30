# Kolkhoz web demo

This directory contains the web shell for the public tutorial and fixed
Easy-AI demo. The Flutter app and C engine remain the source of truth.

Build the deployable site from the repository root:

```bash
./app/tool/build_web_demo.sh
```

The build requires Flutter, Emscripten, Python 3, and the `cwebp` command from
the WebP tools package.

The script compiles `engine/KolkhozCEngine` to WebAssembly, builds Flutter with
`KOLKHOZ_WEB_DEMO=true`, converts generated PNG assets to WebP, and removes
neural-policy assets, obsolete artwork, and the unused local CanvasKit copy. It
writes the result to `app/build/web`.

Set `BASE_HREF` only when hosting below a URL path. The production deployment
at `play.kolkhoz.online` uses the default `/`.
