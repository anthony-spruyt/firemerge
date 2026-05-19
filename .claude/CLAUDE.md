# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FireMerge is a web-based transaction merger and import tool for Firefly III. It parses bank statements (CSV, XLSX, PDF), matches transactions using fuzzy search, suggests metadata from similar historical transactions, and pushes enriched transactions to Firefly III.

- **Backend**: Python 3.13 + FastAPI (package manager: `uv`)
- **Frontend**: React 19 + TypeScript + Vite + Material-UI

## Development Commands

All commands run from repository root:

```bash
# Run servers (backend requires .env with FIREFLY_BASE_URL and FIREFLY_TOKEN)
make run-backend          # FastAPI on port 8080
make run-frontend         # Vite dev server on port 5173, proxies /api → localhost:8080

# Linting and type checking
make check                # All checks (backend + frontend)
make check-backend        # mypy + ruff format + ruff check
make check-frontend       # eslint + tsc
make ruff-fix             # Auto-format and fix Python code

# Testing
make test                 # All backend tests (pytest -vv)

# Single test file
cd backend && uv run pytest tests/test_parser.py -vv

# Single test function
cd backend && uv run pytest tests/test_parser.py::test_function_name -vv
```

## Environment Variables

| Variable           | Required | Purpose                                          |
| ------------------ | -------- | ------------------------------------------------ |
| `FIREFLY_BASE_URL` | Yes      | Firefly III instance URL                         |
| `FIREFLY_TOKEN`    | Yes      | Firefly III API bearer token                     |
| `LISTEN_URL`       | No       | Backend listen address (default: `0.0.0.0:8080`) |

Copy `env.example` → `.env` and fill in values. Backend loads `.env` via `make run-backend`.

## Architecture

### Request Flow

1. **Upload**: Frontend sends file to `POST /api/statement/parse` → `StatementParser` reads CSV/XLSX/PDF via `BaseStatementReader` factory → returns `list[StatementTransaction]`
2. **Match**: Frontend sends parsed transactions to `POST /api/transactions/` → `merge_transactions()` fuzzy-matches against Firefly III history → returns `list[DisplayTransaction]` with states (Matched/Annotated/New) and candidate suggestions
3. **Save**: User reviews, edits, then `PUT /api/transactions/` pushes enriched transaction to Firefly III

### Backend (`backend/src/firemerge/`)

| Module                | Purpose                                                                                                                                                                                                 |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `api/deps.py`         | FastAPI dependency injection via `Annotated[T, Depends()]` — lifespan context manages `httpx.AsyncClient` and `FireflyClient`                                                                           |
| `api/statement.py`    | Statement upload, parsing, parser-settings guessing                                                                                                                                                     |
| `api/transactions.py` | Transaction merge, save, description search                                                                                                                                                             |
| `api/accounts.py`     | Account listing and settings CRUD                                                                                                                                                                       |
| `model/`              | Pydantic models — uses discriminated unions for `StatementFormatSettings` (CSV/XLSX/PDF) and `ExportField` types                                                                                        |
| `statement/reader.py` | Abstract factory `BaseStatementReader` with CSV/XLSX/PDF implementations                                                                                                                                |
| `statement/parser.py` | `StatementParser`: header detection, row parsing, IBAN filtering, document joining (debit/credit rows with matching doc_number), blacklist filtering                                                    |
| `merge.py`            | Fuzzy matching via `thefuzz` — score cutoff 93/100, max 10 candidates, deduplicates by keeping highest-scored per unique transaction                                                                    |
| `firefly_client.py`   | Async Firefly III client — paginated GET via async generator, `@async_collect` decorator converts to list, 300s timeout, stores account settings as Firefly III attachments (`firemerge-settings.json`) |

### Frontend (`frontend/src/`)

- **No router library** — `Main.tsx` uses state-based rendering: no account → account picker → no statement → upload → transaction list
- **TanStack Query** for server state (`hooks/backend.ts`): accounts (staleTime: Infinity), transactions, categories, currencies, mutations with cache updates
- **Session storage persistence** via `useSessionState<T>()` hook — selected account and statement survive page reload
- **API client** (`services/backend.ts`): checks `res.ok`, parses error detail, custom `PydanticError` class for validation errors
- **Vite proxy**: dev server proxies `/api` → `http://localhost:8080`; production serves frontend from `/frontend/dist` mounted in FastAPI

### Transaction States

- **Matched**: Same amount + date + notes in Firefly III — nothing to do
- **Annotated**: Amount/date match but notes differ — user can update notes
- **New**: Not in Firefly III — shows up to 10 fuzzy-matched candidates for metadata suggestion
- **Unmatched**: Exists in Firefly III but not in statement

### Matching Algorithm (`merge.py`)

1. Filter candidates by exact amount match + date within ±1 day
2. Fuzzy match on `notes` field using `thefuzz.process.extractBests()` with score cutoff 93
3. Deduplicate: group by normalized data (ignoring date/score/notes), keep latest date + max score
4. Sort by score DESC then date DESC

## Testing

- **Framework**: pytest + pytest-asyncio
- **Fixtures** (`conftest.py`): `currency_usd`, `currency_eur`, `utc`, `account_primary`, `account_secondary`
- **Mocking**: `unittest.mock.patch` on `BaseStatementReader.create()` with `MockReader` for test data

## Git & PRs

This is a fork of `lvu/firemerge`. When creating PRs:

- **Always use `--repo anthony-spruyt/firemerge`** to create PRs in this fork
- Never create PRs to the upstream repo unless explicitly asked

## Linting

- **Python (ruff)**: rules `E`, `F`, `I` only (PEP 8, Pyflakes, isort)
- **MyPy**: with Pydantic plugin; `thefuzz`, `aiocache`, `hidateinfer` set to follow untyped imports
- **Pre-commit**: yamllint, gitleaks (secret detection), shellcheck, mdformat, markdownlint, actionlint, trailing whitespace/CRLF/tab fixes
