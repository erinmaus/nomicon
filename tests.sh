#!/usr/bin/env sh

make

if [ -z "${CI+yes}" ]; then
    "${LOVE_BINARY:-love}" --fused tests ci=yes
else
    "${LOVE_BINARY:-love}" --fused tests ci=no
fi
