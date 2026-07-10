#!/bin/bash
set -e

APP_NAME="Codex-Usage"
SOURCE_APP="./${APP_NAME}.app"
TARGET_APP="/Applications/${APP_NAME}.app"

if [ ! -d "$SOURCE_APP" ]; then
    echo "${SOURCE_APP} not found. Build it first with:"
    echo "  ./Scripts/build_app.sh"
    exit 1
fi

echo "Installing ${APP_NAME}.app to /Applications..."
rm -rf "$TARGET_APP"
cp -R "$SOURCE_APP" "$TARGET_APP"

echo "Done. You can now launch ${APP_NAME} from Launchpad or Spotlight."
