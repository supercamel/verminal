#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "usage: $0 BUILD_DIR SOURCE_DIR PREFIX [LIBDIR]" >&2
  exit 2
fi

build_dir="$1"
source_dir="$2"
prefix="$3"
libdir="${4:-}"

meson_args=()
if [[ -n "${SQGI_LINUX_MESON_CROSS_FILE:-}" ]]; then
  meson_args+=(--cross-file "${SQGI_LINUX_MESON_CROSS_FILE}")
fi

setup_args=("${build_dir}" "${source_dir}" "${meson_args[@]}" --prefix "${prefix}")
if [[ -n "${libdir}" ]]; then
  setup_args+=(--libdir "${libdir}")
fi

meson setup "${setup_args[@]}" --wipe || meson setup "${setup_args[@]}"
