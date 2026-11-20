#!/usr/bin/env bash
# Checkmate original Intel 8080 ROM build — zmac v1.3; no Python.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
fail() { echo "ERROR: $*" >&2; exit 1; }
for cmd in dd sha1sum zip stat; do command -v "$cmd" >/dev/null 2>&1 || fail "Missing command: $cmd"; done
if [[ -n "${ZMAC:-}" ]]; then
    zmac_bin="$ZMAC"
elif [[ -x tools/zmac ]]; then
    zmac_bin=tools/zmac
else
    zmac_bin=zmac
fi
command -v "$zmac_bin" >/dev/null 2>&1 || fail 'zmac v1.3 not found (set ZMAC or use tools/zmac)'
[[ -f src/checkmate.asm ]] || fail 'Missing src/checkmate.asm'
[[ -f roms/original/checkmat.zip ]] || fail 'Missing reference roms/original/checkmat.zip'

rom_names=(checkmat.h checkmat.g checkmat.f checkmat.e)
rom_sha1=(
    f758599d6393398a6a8e6e7399dc1a3862604f65
    484ff9bfb95166ba09f34c753a7908a73de3cc7d
    39e0cf502735819a7e1d933e3686945fcfae21af
    453f95dd31968d439339c41e625481170437eb0f
)
echo 'Checkmate original ROM build'
echo '[1/4] Prepare output'
mkdir -p build roms
rm -f build/checkmate.bin build/checkmate.lst roms/checkmat.zip
for name in "${rom_names[@]}"; do rm -f "build/$name"; done

echo '[2/4] Assemble native Intel 8080 source (zmac v1.3)'
"$zmac_bin" -c -o build/checkmate.bin -x build/checkmate.lst src/checkmate.asm || fail 'Assembly failed'
[[ -s build/checkmate.bin ]] || fail 'Assembler did not produce a binary image'
size=$(stat -c %s build/checkmate.bin)
(( size == 4096 )) || fail "Binary image is $size bytes; expected 4096"

echo '[3/4] Split and verify four 1 KB ROMs'
for i in 0 1 2 3; do
    name=${rom_names[i]}
    dd if=build/checkmate.bin of="build/$name" bs=1024 skip="$i" count=1 status=none
    size=$(stat -c %s "build/$name")
    (( size == 1024 )) || fail "$name is $size bytes; expected 1024"
    actual=$(sha1sum "build/$name"); actual=${actual%% *}
    if [[ "$actual" != "${rom_sha1[i]}" ]]; then
        echo "ERROR: $name SHA1 mismatch: expected ${rom_sha1[i]}, got $actual" >&2
        if command -v unzip >/dev/null 2>&1 && command -v cmp >/dev/null 2>&1; then
            echo 'First byte differences (device offset decimal, byte values octal):' >&2
            cmp -l <(unzip -p roms/original/checkmat.zip "$name") "build/$name" |
                awk 'NR<=30 {printf "  %6d  %8s  %9s\n", $1-1, $2, $3} END {printf "  Total differing bytes: %d\n", NR}' >&2 || true
        fi
        fail "ROM verification failed; original archive and assembled device are preserved"
    fi
    echo "  $name  OK  $actual"
done
echo '[4/4] Package roms/checkmat.zip'
(cd build && zip -q -X ../roms/checkmat.zip "${rom_names[@]}") || fail 'ROM packaging failed'
[[ -s roms/checkmat.zip ]] || fail 'ROM ZIP not created'
echo 'Build complete: roms/checkmat.zip'
