#!/usr/bin/env bash
# Runs the KindleUI unit tests, then builds and tests the example apps.
set -euo pipefail
cd "$(dirname "$0")"

echo "### KindleUI tests"
swift test

echo "### KindleShowcase & KindleWiki (Examples/) build + tests"
(cd Examples && swift test && swift build)
