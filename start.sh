#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SESSION_NAME="tommy-bot"
LUVIT_BIN="$SCRIPT_DIR/exes/luvit"
MAIN_FILE="$SCRIPT_DIR/src/main.lua"
INSTALL_SCRIPT="$SCRIPT_DIR/install_discordia.sh"

cd "$SCRIPT_DIR"

if ! command -v git >/dev/null 2>&1; then
    echo "git is not installed"
    exit 1
fi

if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux is not installed"
    exit 1
fi

if [ ! -x "$LUVIT_BIN" ]; then
    echo "luvit binary is missing or not executable: $LUVIT_BIN"
    exit 1
fi

if [ ! -f "$MAIN_FILE" ]; then
    echo "main file is missing: $MAIN_FILE"
    exit 1
fi

NEEDS_INSTALL=0
if [ ! -d "$SCRIPT_DIR/deps/discordia" ]; then
    NEEDS_INSTALL=1
fi
if [ ! -d "$SCRIPT_DIR/deps/discordia-slash" ]; then
    NEEDS_INSTALL=1
fi
if [ ! -d "$SCRIPT_DIR/deps/discordia-interactions" ]; then
    NEEDS_INSTALL=1
fi

if [ "$NEEDS_INSTALL" -eq 1 ]; then
    echo "dependencies missing, running installer..."

    if [ ! -f "$INSTALL_SCRIPT" ]; then
        echo "dependency installer is missing: $INSTALL_SCRIPT"
        exit 1
    fi

    sh "$INSTALL_SCRIPT"
fi

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux respawn-pane -k -t "$SESSION_NAME":0.0 "$LUVIT_BIN $MAIN_FILE"
else
    tmux new-session -d -s "$SESSION_NAME" "$LUVIT_BIN $MAIN_FILE"
fi

tmux list-sessions | grep "^$SESSION_NAME:"