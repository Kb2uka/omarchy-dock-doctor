#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
art="$PWD/.artifacts/feat_dock_doctor"
mkdir -p "$art"
harness="$(mktemp -d /tmp/dd-native-XXXXXX)"
weston_pid=""
cleanup() {
  if [[ -n "$weston_pid" ]]; then kill "$weston_pid" 2>/dev/null || true; wait "$weston_pid" 2>/dev/null || true; fi
  rm -rf "$harness"
}
trap cleanup EXIT
mkdir -p "$harness/dock" "$harness/runtime" "$harness/state"
chmod 700 "$harness/runtime" "$harness/state"
cp ./*.qml ./*.js ./dock-doctor.py "$harness/dock/"
cp -r dock_doctor "$harness/dock/"
cp -r /usr/share/omarchy/shell/Ui /usr/share/omarchy/shell/Commons "$harness/"
cat > "$harness/shell.qml" <<'QML'
import QtQuick
import Quickshell
import "dock" as Dock
ShellRoot {
  Dock.Panel { id: plugin }
  Timer { interval: 500; running: true; onTriggered: plugin.open() }
  Timer { interval: 1100; running: true; onTriggered: plugin.close() }
  Timer { interval: 1400; running: true; onTriggered: plugin.open() }
  Timer { interval: 1800; running: true; onTriggered: Qt.quit() }
}
QML
if [[ "${DOCK_NATIVE_CASE:-}" == "multimonitor" ]]; then
  cp tests/ui/native-multimonitor.qml "$harness/shell.qml"
fi
export XDG_RUNTIME_DIR="$harness/runtime"
export XDG_STATE_HOME="$harness/state"
export WAYLAND_DISPLAY=dd-wayland
"${WESTON_BIN:-weston}" --backend="${WESTON_BACKEND:-headless}" --shell="${WESTON_SHELL:-kiosk-shell.so}" --renderer=pixman --width=1500 --height=1000 \
  --socket="$WAYLAND_DISPLAY" --idle-time=0 --no-config > "$art/weston.log" 2>&1 &
weston_pid=$!
for attempt in {1..50}; do
  [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]] && break
  kill -0 "$weston_pid" 2>/dev/null || { cat "$art/weston.log"; exit 1; }
  sleep 0.1
done
QT_QPA_PLATFORM=wayland python3 tests/ui/native-run.py "$harness" "$art/native-parse.log"
cat "$art/native-parse.log"
rg -q 'Configuration Loaded' "$art/native-parse.log"
! rg -q 'ERROR|ReferenceError|TypeError|is not a type|Cannot assign' "$art/native-parse.log"

if [[ -z "${DOCK_NATIVE_CASE:-}" ]]; then
  cp tests/ui/native-multimonitor.qml "$harness/shell.qml"
  QT_QPA_PLATFORM=wayland python3 tests/ui/native-run.py "$harness" "$art/native-multimonitor.log"
  cat "$art/native-multimonitor.log"
  rg -q 'All widgets removed and recreated successfully' "$art/native-multimonitor.log"
  rg -q 'Both widgets recovered fresh live observations after observer exit' "$art/native-multimonitor.log"
  ! rg -q 'ERROR|ReferenceError|TypeError|is not a type|Cannot assign' "$art/native-multimonitor.log"
fi
