#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
ffi_dir="$repo_root/crates/emf-ffi"
target_dir="$repo_root/target"
cc=${CC:-cc}

cargo build --manifest-path "$repo_root/Cargo.toml" --target-dir "$target_dir" -p emf-ffi

case "$(uname -s)" in
    Darwin)
        library="$target_dir/debug/libemf_ffi.dylib"
        "$cc" -std=c11 -Wall -Wextra -Werror -I "$ffi_dir/include" \
            "$ffi_dir/tests/abi.c" "$library" -Wl,-rpath,"$(dirname "$library")" \
            -o "$target_dir/debug/emf-ffi-c-smoke"
        "$cc" -std=c11 -Wall -Wextra -Werror -I "$ffi_dir/include" \
            "$ffi_dir/tests/wmf_snapshot.c" "$library" -Wl,-rpath,"$(dirname "$library")" \
            -o "$target_dir/debug/emf-ffi-wmf-snapshot-smoke"
        ;;
    Linux)
        library="$target_dir/debug/libemf_ffi.so"
        "$cc" -std=c11 -Wall -Wextra -Werror -I "$ffi_dir/include" \
            "$ffi_dir/tests/abi.c" -L "$(dirname "$library")" -lemf_ffi \
            -Wl,-rpath,"$(dirname "$library")" -o "$target_dir/debug/emf-ffi-c-smoke"
        "$cc" -std=c11 -Wall -Wextra -Werror -I "$ffi_dir/include" \
            "$ffi_dir/tests/wmf_snapshot.c" -L "$(dirname "$library")" -lemf_ffi \
            -Wl,-rpath,"$(dirname "$library")" -o "$target_dir/debug/emf-ffi-wmf-snapshot-smoke"
        ;;
    *)
        echo "unsupported host for C ABI smoke: $(uname -s)" >&2
        exit 2
        ;;
esac

"$target_dir/debug/emf-ffi-c-smoke"
"$target_dir/debug/emf-ffi-wmf-snapshot-smoke"
