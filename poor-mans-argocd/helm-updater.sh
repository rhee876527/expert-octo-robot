#!/bin/bash
REPO_URL="https://github.com/rhee876527/expert-octo-robot.git"
PERSISTENT_DIR="$HOME/.helm-tracker"
REPO_DIR="$PERSISTENT_DIR/repo"
TRACKING_FILE="$PERSISTENT_DIR/tracking_commit"
CHARTS_DIR="app-charts"
BRANCH="main"

# Ensure persistent directory exists
mkdir -p "$PERSISTENT_DIR"

function clone_or_fetch() {
    if [[ -d "$REPO_DIR/.git" ]]; then
        # Repo exists, fetch latest changes quietly
        git -C "$REPO_DIR" fetch --prune origin >/dev/null 2>&1
        # Get current HEAD before reset
        PREV_HEAD=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || echo "none")
        git -C "$REPO_DIR" reset --hard origin/$BRANCH >/dev/null 2>&1
        # Get new HEAD after reset
        NEW_HEAD=$(git -C "$REPO_DIR" rev-parse HEAD)
        # Compare and show HEAD message only if it changed
        if [[ "$PREV_HEAD" != "$NEW_HEAD" && "$PREV_HEAD" != "none" ]]; then
            echo "HEAD is now at $NEW_HEAD ($(git -C "$REPO_DIR" log -1 --oneline $NEW_HEAD))"
        fi
    else
        # Fresh clone (ensure full history is available)
        rm -rf "$REPO_DIR"  # In case of partial/incomplete clones
        git clone "$REPO_URL" "$REPO_DIR" >/dev/null 2>&1
        # Show HEAD for fresh clone
        NEW_HEAD=$(git -C "$REPO_DIR" rev-parse HEAD)
        echo "HEAD is now at $NEW_HEAD ($(git -C "$REPO_DIR" log -1 --oneline $NEW_HEAD))"
    fi
}

function start_tracking() {
    cd "$REPO_DIR"
    git reset --hard origin/$BRANCH
    git rev-parse HEAD > "$TRACKING_FILE"
    echo "Tracking started from commit: $(cat "$TRACKING_FILE")"
}

function detect_changes() {
    cd "$REPO_DIR"

    if [[ ! -f "$TRACKING_FILE" ]]; then
        echo "🚨 First-time setup detected!"
        echo "Run: $0 --start-tracking"
        exit 1
    fi

    LAST_TRACKED_COMMIT=$(cat "$TRACKING_FILE")

    # Compare last tracked commit with the latest remote main branch
    CHANGED_FILES=$(git diff --name-only "$LAST_TRACKED_COMMIT" origin/main -- "$CHARTS_DIR" || true)

    if [[ -n "$CHANGED_FILES" ]]; then
        echo "Detected changes in Helm charts:"
        echo "$CHANGED_FILES"
        return 0
    else
        return 1
    fi
}

function upgrade_charts() {
    CHARTS_TO_UPGRADE=($(echo "$CHANGED_FILES" | cut -d'/' -f2 | sort -u))

    for chart_name in "${CHARTS_TO_UPGRADE[@]}"; do
        chart_dir="$CHARTS_DIR/$chart_name"

        echo "Upgrading chart: $chart_name (from $chart_dir)"
        helm upgrade "$chart_name" "$chart_dir"
    done
    git rev-parse HEAD > "$TRACKING_FILE"
    echo "Upgrade complete. Tracking updated."
}

# Arguments
if [[ $# -gt 0 ]]; then
    case "$1" in
        --start-tracking)
            clone_or_fetch
            start_tracking
            exit 0
            ;;
        --dry-run)
            clone_or_fetch
            detect_changes
            exit 0
            ;;
        *)
            echo "Usage: $0 [--start-tracking | --dry-run]"
            exit 1
            ;;
    esac
fi

# Normal Run
clone_or_fetch
if detect_changes; then
    upgrade_charts
fi
