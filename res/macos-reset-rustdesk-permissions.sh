#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="${1:-com.carriez.rustdesk}"
APP_PATH="${2:-/Applications/RustDesk.app}"
PREF_DIR="${HOME}/Library/Preferences/com.carriez.RustDesk"
SERVICE_LABEL="com.carriez.RustDesk_service"
AGENT_LABEL="com.carriez.RustDesk_server"
AGENT_PLIST="/Library/LaunchAgents/${AGENT_LABEL}.plist"

shell_quote() {
  printf "'%s'" "${1//\'/\'\\\'\'}"
}

apple_script_quote() {
  local value="${1//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "${value}"
}

echo "Stopping RustDesk..."
pkill -x RustDesk 2>/dev/null || true

if [[ -f "${AGENT_PLIST}" ]] || pgrep -f "${APP_PATH}/Contents/MacOS/(RustDesk|service)" >/dev/null 2>&1; then
  echo "Stopping RustDesk launch agents and root service/processes..."
  quoted_app_path="$(shell_quote "${APP_PATH}")"
  quoted_agent_plist="$(shell_quote "${AGENT_PLIST}")"
  user_uids="$(dscl . -list /Users UniqueID | awk '$2 >= 500 && $2 < 1000 {print $2}' | tr '\n' ' ')"
  admin_command=""
  for uid in ${user_uids}; do
    admin_command="${admin_command} launchctl bootout gui/${uid} ${quoted_agent_plist} 2>/dev/null || true;"
  done
  admin_command="${admin_command} pkill -f ${quoted_app_path}/Contents/MacOS/RustDesk 2>/dev/null || true; pkill -f ${quoted_app_path}/Contents/MacOS/service 2>/dev/null || true"
  osascript -e "do shell script $(apple_script_quote "${admin_command}") with administrator privileges"
fi

if [[ -d "${PREF_DIR}" ]] && find "${PREF_DIR}" \! -user "$(id -un)" -print -quit | grep -q .; then
  echo "Repairing RustDesk preference ownership for $(id -un)..."
  quoted_pref_dir="$(shell_quote "${PREF_DIR}")"
  quoted_user="$(shell_quote "$(id -un)")"
  osascript -e "do shell script $(apple_script_quote "chown -R ${quoted_user}:staff ${quoted_pref_dir}") with administrator privileges"
fi

echo "Resetting macOS privacy permissions for ${BUNDLE_ID}..."
tccutil reset ScreenCapture "${BUNDLE_ID}" || true
tccutil reset Accessibility "${BUNDLE_ID}" || true
tccutil reset ListenEvent "${BUNDLE_ID}" || true

if [[ -d "${APP_PATH}" ]]; then
  echo "Starting ${APP_PATH}..."
  open -a "${APP_PATH}"
  if launchctl print "system/${SERVICE_LABEL}" >/dev/null 2>&1; then
    echo "Restarting RustDesk system service..."
    osascript -e "do shell script $(apple_script_quote "launchctl kickstart -k system/${SERVICE_LABEL}") with administrator privileges"
  fi
else
  echo "App not found at ${APP_PATH}. Start RustDesk manually after installing it."
fi

cat <<EOF

Next steps:
1. Open System Settings > Privacy & Security > Screen & System Audio Recording.
2. Enable RustDesk, then quit and reopen RustDesk if macOS asks.
3. Open System Settings > Privacy & Security > Accessibility.
4. Enable RustDesk.
5. Open System Settings > Privacy & Security > Input Monitoring.
6. Enable RustDesk, then quit and reopen RustDesk again.

This is needed after replacing RustDesk with an ad-hoc signed or self-built
macOS app, because TCC may keep entries tied to the old code signature.
The script also repairs RustDesk preferences if a root-launched service wrote
files into the current user's preferences directory, and clears root-owned
RustDesk processes left behind by the previous install.
EOF
