#!/usr/bin/env bash
set -euo pipefail

bd ready --limit 1 --json 2> /dev/null | jq --raw-output '.[0] // empty'
