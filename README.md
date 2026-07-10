# Codex-Usage

A minimalist macOS floating-ball widget for OpenAI Codex usage.

## Features
- Always-on-top floating ball showing Codex 5-hour and weekly usage remaining.
- Shows countdown to the nearest reset.
- Drag to reposition; position is remembered.
- Auto-refreshes every 60 seconds.
- Status bar menu to show, refresh, open settings, or quit when the ball is closed.

## Requirements
- macOS 14+
- Codex CLI installed and authenticated (`codex login`)

## Build

```bash
swift build
```

## Run

```bash
./Scripts/build_app.sh
./Scripts/install.sh
open /Applications/Codex-Usage.app
```

`build_app.sh` creates `Codex-Usage.app` in the project root. `install.sh` copies it to `/Applications` so it appears in Launchpad and Spotlight.

## Data Source

Reads from the local Codex CLI via JSON-RPC (`codex app-server`). No API keys or browser cookies required.
