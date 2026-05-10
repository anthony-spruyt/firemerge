#!/usr/bin/env bash
# shellcheck disable=SC2034 # Variables used by sourcing script (lint.sh)
# Lint configuration - customize per repository
# This file is sourced by lint.sh for both local and CI runs

# MegaLinter Docker image (use digest for reproducibility)
# renovate: datasource=docker depName=ghcr.io/anthony-spruyt/megalinter-firemerge
MEGALINTER_IMAGE="ghcr.io/anthony-spruyt/megalinter-firemerge:1.0.1@sha256:ecc13c7c7ac9a0e0eeab4bbdf0e9fc53b164205605524a4db5c48ad64c313c14"

# Skip linting for renovate/dependabot commits in CI
SKIP_BOT_COMMITS=true

# MegaLinter flavor (use "all" for custom images to bypass flavor validation)
MEGALINTER_FLAVOR="all"
