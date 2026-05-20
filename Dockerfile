FROM node:24-slim@sha256:b809ce06df0b8f49f8a3015e23a38f47fabfa1052d4d6916655eaae0d9950ff9 AS frontend-deps

RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

WORKDIR /app/frontend

COPY frontend/package*.json ./

RUN npm ci

COPY frontend/ ./

FROM frontend-deps AS frontend-lint
# Named target for CI lint builds — avoids full Vite production build


FROM frontend-deps AS frontend-builder

RUN npm run build


FROM python:3.13-slim@sha256:9ca3cf9a53a4087afa82efa7cfae3c9d96858a0f9a72ef7acb0119848708d87e AS backend-base

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

COPY --from=ghcr.io/astral-sh/uv:latest@sha256:e590846f4776907b254ac0f44b5b380347af5d90d668138ca7938d1b0c2f98d3 /uv /uvx /bin/

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
