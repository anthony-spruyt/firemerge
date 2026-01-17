# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FireMerge is a web-based transaction merger and import tool for Firefly III. It parses bank statements (CSV, XLSX, PDF), matches transactions using fuzzy search, suggests metadata from similar historical transactions, and pushes enriched transactions to Firefly III.

- **Backend**: Python 3.13 + FastAPI (package manager: `uv`)
- **Frontend**: React 19 + TypeScript + Vite + Material-UI

## Development Commands

All commands run from repository root:

```bash
# Run servers (backend requires .env file with FIREFLY_BASE_URL and FIREFLY_TOKEN)
make run-backend          # Start FastAPI server on port 8080
make run-frontend         # Start Vite dev server

# Linting and type checking
make check                # Run all checks (backend + frontend)
make check-backend        # mypy + ruff
make check-frontend       # eslint + tsc
make ruff-fix             # Auto-format and fix Python code

# Testing
make test                 # Run all backend tests

# Run a single test file
cd backend && uv run pytest tests/test_parser.py -vv

# Run a specific test
cd backend && uv run pytest tests/test_parser.py::test_function_name -vv
```

## Architecture

### Backend (`backend/src/firemerge/`)

| Directory/File      | Purpose                                                                  |
| ------------------- | ------------------------------------------------------------------------ |
| `api/`              | FastAPI route handlers (accounts, transactions, statements)              |
| `model/`            | Pydantic models for API, Firefly III data, account settings              |
| `statement/`        | Statement parsing (reader.py for CSV/XLSX/PDF, parser.py for extraction) |
| `merge.py`          | Transaction matching using fuzzy search (thefuzz)                        |
| `firefly_client.py` | Async HTTP client for Firefly III API                                    |
| `main.py`           | FastAPI app definition and entry point                                   |

### Frontend (`frontend/src/`)

| Component             | Purpose                                                       |
| --------------------- | ------------------------------------------------------------- |
| `Main.tsx`            | Root component with routing logic                             |
| `TransactionList.tsx` | Displays parsed transactions by state (new, matched, etc.)    |
| `TransactionCard.tsx` | Individual transaction with edit/save actions                 |
| `Candidates.tsx`      | Shows similar historical transactions for metadata suggestion |
| `AccountSettings/`    | Parser config, export config, blacklist management            |

State management uses TanStack Query for server state synchronization.

## Git & PRs

This is a fork of `lvu/firemerge`. When creating PRs:

- **Always use `--repo anthony-spruyt/firemerge`** to create PRs in this fork
- Never create PRs to the upstream repo unless explicitly asked
