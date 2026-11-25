#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${CARGO_TARGET_DIR:?set a separate absolute CARGO_TARGET_DIR}"
python3 emf-rs/fuzz/seeds.py --corpus "$CARGO_TARGET_DIR/fuzz-corpus"
# The fuzz crate's own unit graph resolves every dependency and artifact
# layout cargo chooses; the stable corpus driver replays the materialized
# seeds through the shared entry points without raw rustc or manual
# extern lists.
CORPUS_DIR="$CARGO_TARGET_DIR/fuzz-corpus/parse" \
  cargo test --manifest-path emf-rs/fuzz/Cargo.toml --locked --test corpus
