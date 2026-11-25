#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${CARGO_TARGET_DIR:?set a separate absolute CARGO_TARGET_DIR}"
python3 emf-rs/fuzz/seeds.py --corpus "$CARGO_TARGET_DIR/fuzz-corpus"
cargo build --manifest-path emf-rs/Cargo.toml -p emf-core -p emf-ffi -p dib-model -p png-model --locked
# Cargo only materializes the unhashed rlib link for a crate's sole build
# unit, and artifact layouts differ across cargo versions; when the
# exported-library path is absent, restore it from the newest matching
# unit anywhere under the target directory so the rustc commands below
# keep referencing plain exported-library paths.
ensure_rlib() {
  name="$1"
  out="$CARGO_TARGET_DIR/debug/lib$name.rlib"
  if [ ! -f "$out" ]; then
    latest=$(find "$CARGO_TARGET_DIR" -name "lib$name-*.rlib" -type f 2>/dev/null | sort | tail -n 1)
    if [ -n "$latest" ]; then
      mkdir -p "$CARGO_TARGET_DIR/debug"
      cp "$latest" "$out"
    fi
  fi
}
ensure_rlib dib_model
ensure_rlib png_model

rustc --edition=2021 --crate-name emf_fuzz --crate-type rlib emf-rs/fuzz/src/lib.rs \
  -L "dependency=$CARGO_TARGET_DIR/debug" \
  -L "dependency=$CARGO_TARGET_DIR/debug/deps" \
  --extern "emf_core=$CARGO_TARGET_DIR/debug/libemf_core.rlib" \
  --extern "emf_ffi=$CARGO_TARGET_DIR/debug/libemf_ffi.rlib" \
  --extern "dib_model=$CARGO_TARGET_DIR/debug/libdib_model.rlib" \
  --extern "png_model=$CARGO_TARGET_DIR/debug/libpng_model.rlib" \
  -o "$CARGO_TARGET_DIR/libemf_fuzz.rlib"
rustc --edition=2021 emf-rs/fuzz/tests/corpus.rs \
  -L "dependency=$CARGO_TARGET_DIR/debug" \
  -L "dependency=$CARGO_TARGET_DIR/debug/deps" \
  --extern "emf_fuzz=$CARGO_TARGET_DIR/libemf_fuzz.rlib" \
  -o "$CARGO_TARGET_DIR/fuzz-corpus-check"
"$CARGO_TARGET_DIR/fuzz-corpus-check" "$CARGO_TARGET_DIR/fuzz-corpus/parse"
