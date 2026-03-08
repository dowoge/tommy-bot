#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DEPS_DIR="$SCRIPT_DIR/deps"
LIT_BIN="$SCRIPT_DIR/exes/lit"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

ensure_git_repo() {
    REPO_URL=$1
    TARGET_DIR=$2

    if [ -d "$TARGET_DIR/.git" ]; then
        echo "Updating $TARGET_DIR..."
        git -C "$TARGET_DIR" pull --ff-only || {
            echo "Failed to update $TARGET_DIR" >&2
            exit 1
        }
        return 0
    fi

    if [ -e "$TARGET_DIR" ]; then
        echo "Removing invalid existing directory: $TARGET_DIR"
        rm -rf "$TARGET_DIR"
    fi

    echo "Cloning $REPO_URL into $TARGET_DIR..."
    git clone "$REPO_URL" "$TARGET_DIR" || {
        echo "Failed to clone $REPO_URL" >&2
        exit 1
    }
}

echo "tommy-bot dependency installer"

require_command git

if [ ! -d "$DEPS_DIR" ]; then
    echo "Creating deps directory..."
    mkdir -p "$DEPS_DIR"
fi

if [ ! -x "$LIT_BIN" ]; then
    echo "Missing lit executable: $LIT_BIN" >&2
    echo "Make sure exes/lit exists and is executable." >&2
    exit 1
fi

echo "Installing/updating discordia with lit..."
"$LIT_BIN" install SinisterRectus/discordia || {
    echo "Failed to install discordia" >&2
    exit 1
}

ensure_git_repo "https://github.com/dowoge/discordia-slash.git" "$DEPS_DIR/discordia-slash"
ensure_git_repo "https://github.com/dowoge/discordia-interactions.git" "$DEPS_DIR/discordia-interactions"

echo "Dependencies are ready"