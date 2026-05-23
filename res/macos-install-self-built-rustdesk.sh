#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  cat >&2 <<EOF
Usage:
  $0 /path/to/RustDesk.app
  $0 /path/to/rustdesk.dmg
  $0 /path/to/artifact.zip

Installs a self-built RustDesk app into /Applications, backs up the existing
app, clears stale macOS TCC permissions, and restarts the RustDesk service.
EOF
  exit 2
fi

SOURCE_PATH="$1"
APP_PATH="${2:-/Applications/RustDesk.app}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rustdesk-install.XXXXXX")"
MOUNT_POINT=""

cleanup() {
  if [[ -n "${MOUNT_POINT}" ]]; then
    hdiutil detach "${MOUNT_POINT}" >/dev/null 2>&1 || true
  fi
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

find_app_in_dir() {
  find "$1" -maxdepth 2 -name "RustDesk.app" -type d -print -quit
}

case "${SOURCE_PATH}" in
  *.zip)
    unzip -q "${SOURCE_PATH}" -d "${WORK_DIR}/zip"
    DMG_PATH="$(find "${WORK_DIR}/zip" -maxdepth 2 -name "*.dmg" -type f -print -quit)"
    if [[ -z "${DMG_PATH}" ]]; then
      APP_SOURCE="$(find_app_in_dir "${WORK_DIR}/zip")"
    fi
    ;;
  *.dmg)
    DMG_PATH="${SOURCE_PATH}"
    ;;
  *.app)
    APP_SOURCE="${SOURCE_PATH}"
    ;;
  *)
    echo "Unsupported source: ${SOURCE_PATH}" >&2
    exit 2
    ;;
esac

if [[ -n "${DMG_PATH:-}" ]]; then
  MOUNT_POINT="$(hdiutil attach "${DMG_PATH}" -nobrowse | awk '/\\/Volumes\\// {print $3; exit}')"
  APP_SOURCE="$(find_app_in_dir "${MOUNT_POINT}")"
fi

if [[ -z "${APP_SOURCE:-}" || ! -d "${APP_SOURCE}" ]]; then
  echo "Could not find RustDesk.app in ${SOURCE_PATH}" >&2
  exit 1
fi

echo "Stopping RustDesk before install..."
pkill -x RustDesk 2>/dev/null || true

if [[ -d "${APP_PATH}" ]]; then
  BACKUP_PATH="${APP_PATH}.backup-$(date +%Y%m%d-%H%M%S)"
  echo "Backing up ${APP_PATH} to ${BACKUP_PATH}..."
  mv "${APP_PATH}" "${BACKUP_PATH}"
fi

echo "Installing ${APP_SOURCE} to ${APP_PATH}..."
cp -R "${APP_SOURCE}" "${APP_PATH}"
xattr -dr com.apple.quarantine "${APP_PATH}" 2>/dev/null || true

"${SCRIPT_DIR}/macos-reset-rustdesk-permissions.sh" com.carriez.rustdesk "${APP_PATH}"

echo "Installed RustDesk:"
"${APP_PATH}/Contents/MacOS/RustDesk" --version 2>/dev/null || true
