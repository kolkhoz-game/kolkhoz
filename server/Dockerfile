FROM python:3.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends clang ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY server/deploy/requirements.lock /tmp/requirements.lock
RUN pip install --no-cache-dir --only-binary :all: --require-hashes \
    -r /tmp/requirements.lock

COPY engine ./engine
COPY policies ./policies
COPY server ./server

RUN python -c 'from engine.python.kolkhoz_c_engine import CEngine, build_shared_library; CEngine(build_shared_library(force=True))'

RUN groupadd --system kolkhoz \
    && useradd --system --gid kolkhoz --home-dir /app kolkhoz \
    && chown -R kolkhoz:kolkhoz /app

USER kolkhoz

EXPOSE 8787
CMD ["python", "-m", "server.kolkhoz_server.production"]
