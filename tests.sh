#!/usr/bin/env sh

set -e

make all

if [ -z "${CI+yes}" ]; then
    "${LOVE_BINARY:-love}" --fused tests ci=yes
else
    "${LOVE_BINARY:-love}" --fused tests ci=no
fi
