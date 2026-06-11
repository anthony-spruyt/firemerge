FROM node:24-slim@sha256:d1006ab709fc360e4f4c4de35eb190af0c2ab939ea5dba19427388405ccdf60f AS frontend-deps

RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

WORKDIR /app/frontend

COPY frontend/package*.json ./

RUN npm ci

COPY frontend/ ./

FROM frontend-deps AS frontend-lint
# Named target for CI lint builds — avoids full Vite production build


FROM frontend-deps AS frontend-builder

RUN npm run build


FROM python:3.14-slim@sha256:c845af9399020c7e562969a13689e929074a10fd057acd1b1fad06a2fb068e97 AS backend-base

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

COPY --from=ghcr.io/astral-sh/uv:latest@sha256:b46b03ddfcfbf8f547af7e9eaefdf8a39c8cebcba7c98858d3162bd28cf536f6 /uv /uvx /bin/

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

RUN uv sync --frozen --no-cache --no-dev --no-install-project


FROM backend-builder AS test

COPY backend/ ./
RUN uv sync --frozen --no-cache


FROM backend-base AS production

COPY --from=backend-builder /app/backend/.venv ./.venv

COPY backend/src/ ./src/

# .venv from backend-builder already contains compiled native deps (e.g. thefuzz);
# this sync only installs the project package itself — no gcc needed.
RUN uv sync --frozen --no-cache --no-dev

COPY --from=frontend-builder /app/frontend/dist/ /app/frontend/dist/

RUN groupadd --gid 1000 appuser && \
    useradd --uid 1000 --gid 1000 --no-create-home appuser && \
    chown -R appuser:appuser /app

USER appuser

EXPOSE 8080

# Kubernetes manages health checks via liveness/readiness probes
HEALTHCHECK NONE

CMD [".venv/bin/firemerge"]
