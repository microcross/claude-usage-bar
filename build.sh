#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
mkdir -p UsageWidget.app/Contents/MacOS
cp .build/release/UsageWidget UsageWidget.app/Contents/MacOS/UsageWidget
echo "Built UsageWidget.app — run 'open UsageWidget.app' or double-click it in Finder."
