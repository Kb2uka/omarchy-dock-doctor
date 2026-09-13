#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p .artifacts/feat_dock_doctor
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  "${QML_TEST_RUNNER:-/usr/lib/qt6/bin/qmltestrunner}" -input tests/ui \
  -o .artifacts/feat_dock_doctor/qml-tests.txt,txt
cat .artifacts/feat_dock_doctor/qml-tests.txt

for width in 1200 1536 1000; do test -s ".artifacts/feat_dock_doctor/interface-$width.png"; done
