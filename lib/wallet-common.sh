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
            --data-urlencode "text=${MESSAGE}" >/dev/null 2>&1; then
            log "WARN" "Failed to send Telegram notification"
        fi
    fi
}
