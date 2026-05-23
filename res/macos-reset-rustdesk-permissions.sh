#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="${1:-com.carriez.rustdesk}"
APP_PATH="${2:-/Applications/RustDesk.app}"

echo "Stopping RustDesk..."
pkill -x RustDesk 2>/dev/null || true

echo "Resetting macOS privacy permissions for ${BUNDLE_ID}..."
tccutil reset ScreenCapture "${BUNDLE_ID}" || true
tccutil reset Accessibility "${BUNDLE_ID}" || true

if [[ -d "${APP_PATH}" ]]; then
  echo "Starting ${APP_PATH}..."
  open -a "${APP_PATH}"
else
  echo "App not found at ${APP_PATH}. Start RustDesk manually after installing it."
fi

cat <<EOF

Next steps:
1. Open System Settings > Privacy & Security > Screen & System Audio Recording.
2. Enable RustDesk, then quit and reopen RustDesk if macOS asks.
3. Open System Settings > Privacy & Security > Accessibility.
4. Enable RustDesk, then quit and reopen RustDesk again.

This is needed after replacing RustDesk with an ad-hoc signed or self-built
macOS app, because TCC may keep entries tied to the old code signature.
EOF
