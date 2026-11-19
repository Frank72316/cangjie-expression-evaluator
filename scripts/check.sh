#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "$0")/.."
cjpm build
cjpm test

cd example
cjpm run
