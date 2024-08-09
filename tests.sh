#!/usr/bin/env sh

set -e

make all

if [ -f "./.vscode/.env" ]; then
    set -a && source ./.vscode/.env && set +a
fi

if [ -z "${CI+yes}" ]; then
    "${LOVE_BINARY:-love}" --fused tests ci=yes
else
    "${LOVE_BINARY:-love}" --fused tests ci=no
fi
