#!/usr/bin/env bash
# Wrapper script to limit build cores for memory-intensive packages

export MAX_JOBS=8
export CMAKE_BUILD_PARALLEL_LEVEL=8
export MAKEFLAGS="-j8"

exec "$@"
