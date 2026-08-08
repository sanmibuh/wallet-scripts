# AGENTS.md — Technical context for AI assistants

This file describes the architecture, conventions, and design decisions of wallet-scripts so that AI assistants can understand the codebase quickly and make consistent contributions.

## What this project does

POSIX shell scripts that call the [Wallet by BudgetBakers](https://web.budgetbakers.com/) REST API to create local JSON backups. Designed to run unattended via cron on Linux, macOS, and Alpine (Docker).

## Repository layout

```
bin/backup          Main backup script. Modes: recent | monthly | yearly
bin/update          Self-updater (downloads tarball from GitHub, preserves config)
lib/wallet-common.sh  Shared: log(), load_config(), send_telegram(), notify_*()
config/wallet.conf  Runtime config (gitignored, created by setup.sh)
setup.sh            Interactive first-run wizard
backups/            Output directory (gitignored)
  monthly/          wallet-monthly-YYYY-MM.json
  yearly/           wallet-yearly-YYYY.json
```

## Key design decisions

### POSIX sh only
All scripts use `#!/bin/sh` and avoid bashisms. No arrays, no `[[`, no `$'...'`, no process substitution. This ensures compatibility with Alpine's BusyBox sh.

### JSON processing without a fixed dependency
The backup script detects and uses the first available of: `jq` > `python3` > `node`. Every JSON operation is implemented three times (one per processor) via helper functions in the script itself:
- `json_get_field <file> <field>` — reads a top-level string field
- `json_merge_arrays <combined> <page> <key> <out>` — appends a paged array into an accumulator
- `json_array_length <file>` — returns array length
- `json_build_backup ...` — assembles the final output object

### Portable date arithmetic
Three date helper functions (`date_offset`, `prev_month_year_month`, `last_day_of_month`) each try GNU date → BSD date → python3 → node, in that order.

### Backup modes
- `recent` — re-invokes `bin/backup monthly` twice: once without args (previous month) and once with `$(date '+%Y-%m')` (current month). No logic duplication.
- `monthly` — fetches all resources for a calendar month, writes a permanent file.
- `yearly` — fetches all resources for a calendar year, writes a permanent file, then deletes monthly files covered by that year.

### Telegram notifications
`lib/wallet-common.sh` exposes:
- `send_telegram <message>` — low-level curl POST with `parse_mode=HTML`
- `notify_backup_success <mode> <from> <to> <records> <accounts> <categories> <budgets> <labels> <file>` — structured HTML message with icon per mode
- `notify_update_success <branch>` — update confirmation
- `notify_error <context> <detail>` — error alert

Messages use HTML (not MarkdownV2) because shell escaping of MarkdownV2 is fragile. HTML only requires escaping `<`, `>`, `&`, which never appear in dates, integers, or filenames used in these messages.

### Pagination
`fetch_resource` loops until the API returns no `nextOffset` field. Each page is written to a temp file and merged via `json_merge_arrays`. JSON is never passed through shell variables to avoid quoting issues with large payloads.

### Temporary files
A single `TMP_DIR=$(mktemp -d)` is created at the start of each backup run. A `trap 'rm -rf "$TMP_DIR"' EXIT` ensures cleanup on any exit.

## Configuration

`config/wallet.conf` is a plain shell file sourced with `. "$CONFIG_FILE"`. Variables:

| Variable | Required | Description |
|---|---|---|
| `API_TOKEN` | Yes | Bearer token for the Wallet REST API |
| `BASE_URL` | Yes | API base URL (default: `https://rest.budgetbakers.com/wallet/v1/api`) |
| `TELEGRAM_TOKEN` | No | Telegram bot token |
| `CHAT_ID` | No | Telegram chat ID |

## API resources fetched per backup

All five resources are fetched with pagination and stored as JSON arrays:

| Resource | Endpoint | Limit | Date filter |
|---|---|---|---|
| accounts | `/accounts` | 200 | none |
| categories | `/categories` | 200 | none |
| budgets | `/budgets` | 20 | none |
| labels | `/labels` | 200 | none |
| records | `/records` | 200 | `recordDate=gte.DATE_FROM&recordDate=lte.DATE_TO` |

## Conventions

- All log output goes to stderr via `log "LEVEL" "message"`.
- Scripts exit with code 1 on any unrecoverable error.
- `bin/update` exits with code 2 when already up to date (no changes detected).
- Backup files for `monthly` and `yearly` are permanent — they are never overwritten, only deleted when a higher-granularity backup covers them (`yearly` removes `monthly`).
- The `recent` mode overwrites both monthly files nightly (previous month and current month), which is intentional — it keeps them up to date with late-arriving transactions.

## Testing changes

There is no automated test suite. Validate manually:

```sh
# Syntax check all scripts
sh -n bin/backup
sh -n bin/update
sh -n lib/wallet-common.sh

# Dry-run (requires valid config)
./bin/backup monthly 2026-01
```
