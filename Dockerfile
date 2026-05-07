FROM node:24-slim@sha256:03eae3ef7e88a9de535496fb488d67e02b9d96a063a8967bae657744ecd513f2 AS frontend-builder

RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

WORKDIR /app/frontend

COPY frontend/package*.json ./

RUN npm install

COPY frontend/ ./

RUN npm run build


FROM python:3.14-slim@sha256:5b3879b6f3cb77e712644d50262d05a7c146b7312d784a18eff7ff5462e77033

RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,id=debconf,target=/var/cache/debconf,sharing=locked \
    set -exu && \
    apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get upgrade -y -qq && \
    apt-get -y install -y -qq --no-install-recommends tzdata-legacy && \
    truncate -s 0 /var/log/apt/* && \
    truncate -s 0 /var/log/dpkg.log

COPY --from=ghcr.io/astral-sh/uv:latest@sha256:798712e57f879c5393777cbda2bb309b29fcdeb0532129d4b1c3125c5385975a /uv /uvx /bin/

WORKDIR /app/backend

COPY backend/pyproject.toml ./
COPY backend/uv.lock ./

RUN uv sync --frozen --no-cache --no-dev

COPY backend/ ./

COPY --from=frontend-builder /app/frontend/dist/ /app/frontend/dist/

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Default command
CMD ["uv", "run", "--no-dev", "--frozen", "firemerge"]
