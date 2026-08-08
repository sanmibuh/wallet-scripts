#!/bin/sh

log() {
    LEVEL="$1"
    MESSAGE="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$LEVEL] $MESSAGE" >&2
}

load_config() {
    SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    CONFIG_FILE="$SCRIPT_DIR/config/wallet.conf"

    if [ ! -f "$CONFIG_FILE" ]; then
        log "ERROR" "Configuration file not found: $CONFIG_FILE"
        log "ERROR" "Please run ./setup.sh first"
        exit 1
    fi

    # shellcheck source=/dev/null
    . "$CONFIG_FILE"

    if [ -z "$API_TOKEN" ]; then
        log "ERROR" "API_TOKEN is empty in config file"
        exit 1
    fi

    if [ -z "$BASE_URL" ]; then
        BASE_URL="https://rest.budgetbakers.com/wallet/v1/api"
    fi
}

send_telegram() {
    MESSAGE="$1"

    if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$CHAT_ID" ]; then
        if ! curl -sS --max-time 10 -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
            --data-urlencode "chat_id=${CHAT_ID}" \
            --data-urlencode "text=${MESSAGE}" \
            -d "parse_mode=HTML" \
            -d "disable_web_page_preview=true" >/dev/null 2>&1; then
            log "WARN" "Failed to send Telegram notification"
        fi
    fi
}

notify_backup_success() {
    _mode="$1"
    _date_from="$2"
    _date_to="$3"
    _records="$4"
    _accounts="$5"
    _categories="$6"
    _budget="$7"
    _labels="$8"
    _file="$(basename "$9")"

    case "$_mode" in
        daily)   _icon="📅" ;;
        monthly) _icon="📆" ;;
        yearly)  _icon="🗓️" ;;
        *)       _icon="📦" ;;
    esac

    send_telegram "${_icon} <b>Wallet Backup Complete</b>

Mode: <b>${_mode}</b>
Period: <code>${_date_from}</code> → <code>${_date_to}</code>

Records: <b>${_records}</b>  ·  Accounts: <b>${_accounts}</b>  ·  Categories: <b>${_categories}</b>
Budgets: <b>${_budget}</b>  ·  Labels: <b>${_labels}</b>

File: <code>${_file}</code>"
}

notify_update_success() {
    _branch="$1"
    send_telegram "✅ <b>wallet-scripts Updated</b>

Branch: <code>${_branch}</code>
All scripts have been updated successfully."
}

notify_error() {
    _context="$1"
    _detail="$2"
    send_telegram "❌ <b>Wallet Scripts: Error</b>

Context: <b>${_context}</b>
Detail: <code>${_detail}</code>"
}
