#!/bin/bash
# 🎵 play-music.sh (FINAL STABLE)
# - yt-dlp -> top result ID
# - PWA mode (--app) for Chromium browsers
# - Kill ONLY YouTube Music PWA windows (class contains music.youtube)
# - Open directly on TARGET_WORKSPACE via hyprctl exec rule (no race)
# - Refocus original window reliably
# - 40+ browser support (same list)

set -uo pipefail

QUERY="${1:-}"
LOG_FILE="/tmp/play-music.log"
CONFIG_FILE="$HOME/.config/hypr/voice-assistant/music-player.conf"

# Defaults (can be overridden by config)
PREFERRED_PLAYER="youtube-music"
OPEN_IN_BACKGROUND="true"
TARGET_WORKSPACE="3"
TARGET_MONITOR=""
REFOCUS_DELAY="0.5"

# Load user config if exists
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

log() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"
}

sanitize_address() {
    # Extract first Hyprland address like 0xABC...
    echo "$1" | grep -Eo '0x[0-9a-fA-F]+' | head -1
}

find_browser() {
    local browsers=(
        # Brave
        "brave" "brave-beta" "brave-nightly"
        # Chrome
        "google-chrome-stable" "google-chrome-beta" "google-chrome-unstable" "google-chrome-canary" "google-chrome"
        # Chromium
        "chromium" "chromium-browser" "chromium-dev" "ungoogled-chromium"
        # Edge
        "microsoft-edge-stable" "microsoft-edge-beta" "microsoft-edge-dev" "microsoft-edge"
        # Vivaldi
        "vivaldi-stable" "vivaldi-snapshot" "vivaldi"
        # Opera
        "opera" "opera-beta" "opera-developer" "opera-gx"
        # Other Chromium
        "thorium-browser" "thorium" "yandex-browser" "yandex-browser-beta"
        "iridium-browser" "iridium" "slimjet" "iron" "srware-iron"
        "comodo-dragon" "coccoc-browser" "coccoc" "naver-whale" "whale"
        "arc" "sidekick" "maxthon" "epic" "epic-privacy-browser"
        # Firefox-based
        "firefox" "firefox-esr" "firefox-developer-edition" "firefox-nightly"
        "librewolf" "floorp" "waterfox" "waterfox-current" "waterfox-classic"
        "zen-browser" "zen" "palemoon" "basilisk" "icecat" "iceweasel"
        "mullvad-browser" "tor-browser"
        # Other
        "epiphany" "gnome-web" "falkon" "midori" "konqueror" "qutebrowser"
        "nyxt" "min" "luakit" "surf" "badwolf" "eolie" "tangram" "dillo" "netsurf"
    )

    for browser in "${browsers[@]}"; do
        if command -v "$browser" &>/dev/null; then
            echo "$browser"
            return 0
        fi
    done

    echo ""
}

is_chromium_based() {
    local browser="$1"
    case "$browser" in
        brave*|google-chrome*|chromium*|microsoft-edge*|vivaldi*|opera*|thorium*|yandex*|iridium*|slimjet|iron|srware-iron|comodo-dragon|coccoc*|whale|naver-whale|arc|sidekick|maxthon|epic*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

get_current_window() {
    hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty' 2>/dev/null || echo ""
}

get_current_workspace() {
    hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty' 2>/dev/null || echo ""
}

close_yt_music_pwa_windows() {
    # ONLY close windows whose class contains music.youtube (PWA class like brave-music.youtube.com__watch-Default)
    local addresses
    addresses=$(hyprctl clients -j 2>/dev/null | jq -r '
        .[] | select(.class | test("music\\.youtube"; "i")) | .address
    ' 2>/dev/null) || addresses=""

    if [[ -z "$addresses" ]]; then
        log "No YouTube Music PWA windows found"
        return 0
    fi

    local count=0
    for addr in $addresses; do
        log "Closing YT Music PWA window: $addr"
        # IMPORTANT: silence stdout ("ok") so it never pollutes captured output
        hyprctl dispatch closewindow "address:$addr" >/dev/null 2>&1 || true
        count=$((count + 1))
    done

    log "Closed $count YT Music PWA window(s)"
    sleep 0.5
}

yt_music_url_from_query() {
    local q="$1"

    # yt-dlp top-result ID (your original strategy)
    local id=""
    id=$(yt-dlp --get-id "ytsearch1:${q}" 2>/dev/null | head -1) || id=""

    if [[ -n "$id" ]]; then
        log "Found video ID: $id"
        echo "https://music.youtube.com/watch?v=${id}&autoplay=1"
        return 0
    fi

    # fallback search
    local enc=""
    enc=$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$q" 2>/dev/null) || enc="$q"
    log "yt-dlp returned empty ID, fallback to search"
    echo "https://music.youtube.com/search?q=${enc}"
}

launch_in_workspace_silent() {
    # Launch command on a workspace without stealing focus (Hyprland feature)
    local workspace="$1"
    local cmd="$2"

    if [[ -n "$workspace" ]]; then
        # IMPORTANT: silence stdout ("ok")
        hyprctl dispatch exec "[workspace ${workspace} silent]" "$cmd" >/dev/null 2>&1 || return 1
        return 0
    fi

    # No workspace requested -> normal background exec
    nohup bash -lc "$cmd" >/dev/null 2>&1 &
    disown 2>/dev/null || true
    return 0
}

find_latest_yt_music_window() {
    # Try multiple times to find the newest YT Music PWA window address
    local addr=""
    for _ in 1 2 3 4 5 6 7 8; do
        addr=$(hyprctl clients -j 2>/dev/null | jq -r '
            .[] | select(.class | test("music\\.youtube"; "i")) | .address
        ' 2>/dev/null | head -1) || addr=""
        addr=$(sanitize_address "$addr")
        if [[ -n "$addr" ]]; then
            echo "$addr"
            return 0
        fi
        sleep 0.4
    done
    echo ""
}

ensure_on_workspace() {
    local addr="$1"
    local target_ws="$2"

    if [[ -z "$addr" || -z "$target_ws" ]]; then
        return 0
    fi

    # Verify/move with retries
    for attempt in 1 2 3 4; do
        # Move silently; silence stdout
        hyprctl dispatch movetoworkspacesilent "${target_ws},address:${addr}" >/dev/null 2>&1 || true
        sleep 0.25

        local current_ws=""
        current_ws=$(hyprctl clients -j 2>/dev/null | jq -r --arg addr "$addr" '
            .[] | select(.address == $addr) | (.workspace.id|tostring)
        ' 2>/dev/null) || current_ws=""

        if [[ "$current_ws" == "$target_ws" ]]; then
            log "Verified: window $addr is on workspace $target_ws"
            return 0
        fi

        log "Move verify attempt ${attempt} failed (current_ws='${current_ws}'), retrying..."
    done

    log "WARNING: Could not verify window moved to workspace $target_ws"
    return 0
}

refocus_original() {
    local orig_addr="$1"
    local orig_ws="$2"

    if [[ -z "$orig_addr" || "$orig_addr" == "null" ]]; then
        return 0
    fi

    sleep "$REFOCUS_DELAY"

    if [[ -n "$orig_ws" && "$orig_ws" != "null" ]]; then
        hyprctl dispatch workspace "$orig_ws" >/dev/null 2>&1 || true
        sleep 0.05
    fi

    hyprctl dispatch focuswindow "address:${orig_addr}" >/dev/null 2>&1 || true
    log "Refocused to original window: $orig_addr (ws $orig_ws)"
}

play_youtube_music() {
    local q="$1"

    log "YouTube Music request: '$q'"

    close_yt_music_pwa_windows

    local url=""
    url=$(yt_music_url_from_query "$q")
    log "Final URL: $url"

    local browser=""
    browser=$(find_browser)
    if [[ -z "$browser" ]]; then
        log "ERROR: No browser found"
        return 1
    fi

    local cmd=""
    if is_chromium_based "$browser"; then
        cmd="${browser} --app=\"${url}\""
    else
        cmd="${browser} \"${url}\""
    fi

    # Launch directly on target workspace (prevents the “opens in focus ws sometimes” race)
    launch_in_workspace_silent "$TARGET_WORKSPACE" "$cmd" || true

    # Find window address after launch
    local new_addr=""
    new_addr=$(find_latest_yt_music_window)
    if [[ -z "$new_addr" ]]; then
        log "WARNING: Could not find YT Music window after launch"
        echo ""
        return 0
    fi

    # Extra safety: ensure it is actually on target workspace
    ensure_on_workspace "$new_addr" "$TARGET_WORKSPACE"

    printf '%s' "$new_addr"
}

main() {
    log "═══════════════════════════════════════════════════════════"
    log "New request: $QUERY"
    log "Config: PLAYER=$PREFERRED_PLAYER, BG=$OPEN_IN_BACKGROUND, WS=$TARGET_WORKSPACE"

    if [[ -z "$QUERY" ]]; then
        echo "Usage: $0 \"Song name\""
        exit 1
    fi

    local orig_window=""
    local orig_ws=""

    if [[ "$OPEN_IN_BACKGROUND" == "true" ]]; then
        orig_window=$(get_current_window)
        orig_ws=$(get_current_workspace)
        log "Original: window=$orig_window, workspace=$orig_ws"
    fi

    notify-send -t 1500 "🎵 Playing" "$QUERY" >/dev/null 2>&1 || true

    local new_window=""
    case "$PREFERRED_PLAYER" in
        youtube-music|auto|"")
            new_window=$(play_youtube_music "$QUERY")
            ;;
        *)
            # For now keep stable: youtube-music path only
            new_window=$(play_youtube_music "$QUERY")
            ;;
    esac

    new_window=$(sanitize_address "$new_window")
    log "New window address: $new_window"

    if [[ "$OPEN_IN_BACKGROUND" == "true" ]]; then
        refocus_original "$orig_window" "$orig_ws"
    fi

    log "SUCCESS"
    log "═══════════════════════════════════════════════════════════"
}

main "$@"
