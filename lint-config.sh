#!/usr/bin/env bash
# shellcheck disable=SC2034 # Variables used by sourcing script (lint.sh)
# Lint configuration - customize per repository
# This file is sourced by lint.sh for both local and CI runs

# MegaLinter Docker image (use digest for reproducibility)
# renovate: datasource=docker depName=ghcr.io/anthony-spruyt/megalinter-firemerge
MEGALINTER_IMAGE="ghcr.io/anthony-spruyt/megalinter-firemerge:1.0.21@sha256:aa47095cc9f87d5ad41b56cb2a65572758546c1057213d465fe8a6b55feb9b82"

# Skip linting for renovate/dependabot commits in CI
SKIP_BOT_COMMITS=false

# MegaLinter flavor (use "all" for custom images to bypass flavor validation)
MEGALINTER_FLAVOR="all"
