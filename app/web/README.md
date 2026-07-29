# Kolkhoz web demo

This directory contains the web shell for the public tutorial and fixed
Easy-AI demo. The Flutter app and C engine remain the source of truth.

Build the deployable site from the repository root:

```bash
./app/tool/build_web_demo.sh
```

The script compiles `engine/KolkhozCEngine` to WebAssembly, builds Flutter with
`KOLKHOZ_WEB_DEMO=true`, removes neural-policy assets that the web build cannot
request, and writes the result to `app/build/web`.

Set `BASE_HREF` only when hosting below a URL path. The production deployment
at `play.kolkhoz.online` uses the default `/`.
