FROM node:24-slim@sha256:24dc26ef1e3c3690f27ebc4136c9c186c3133b25563ae4d7f0692e4d1fe5db0e AS frontend-deps

RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

WORKDIR /app/frontend

COPY frontend/package*.json ./

RUN npm install

COPY frontend/ ./


FROM frontend-deps AS frontend-lint
# Named target for CI lint builds — avoids full Vite production build


FROM frontend-deps AS frontend-builder

RUN npm run build


FROM python:3.14-slim@sha256:1697e8e8d39bf168e177ac6b5fdab6df86d81cfc24dae17dfb96cfc3ef76b4dd AS backend-base

RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,id=debconf,target=/var/cache/debconf,sharing=locked \
    set -exu && \
    apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get upgrade -y -qq && \
    apt-get install -y -qq --no-install-recommends tzdata-legacy && \
    truncate -s 0 /var/log/apt/* && \
    truncate -s 0 /var/log/dpkg.log

COPY --from=ghcr.io/astral-sh/uv:latest@sha256:3a59a3cdd5f7c217faa36e32dbc7fddbb0412889c2a0a5229f6d790e5a019dd7 /uv /uvx /bin/

WORKDIR /app/backend

COPY backend/pyproject.toml ./
COPY backend/uv.lock ./


FROM backend-base AS backend-builder

RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,id=debconf,target=/var/cache/debconf,sharing=locked \
    set -exu && \
    apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y -qq --no-install-recommends gcc libc6-dev make && \
    truncate -s 0 /var/log/apt/* && \
    truncate -s 0 /var/log/dpkg.log

RUN uv sync --frozen --no-cache --no-dev


FROM backend-builder AS test

RUN uv sync --frozen --no-cache
COPY backend/ ./


FROM backend-base AS production

COPY --from=backend-builder /app/backend/.venv ./.venv

COPY backend/src/ ./src/

COPY --from=frontend-builder /app/frontend/dist/ /app/frontend/dist/

RUN groupadd --gid 1000 appuser && \
    useradd --uid 1000 --gid 1000 --no-create-home appuser && \
    chown -R appuser:appuser /app

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

CMD ["uv", "run", "--no-dev", "--frozen", "firemerge"]
