#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") <directory> [--range N:M] [--output FILE]

  <directory>      Directory whose files will be dumped.
  --range N:M      Dump only the N-th through M-th files (1-based, alphabetical).
  --output FILE    Path of the output file (default: ./file_dump.txt).

Examples
  # Dump every file in ./assets to file_dump.txt
  $(basename "$0") ./assets

  # Dump the 5th-through-8th files (alphabetically) in ./src into partial.txt
  $(basename "$0") ./src --range 5:8 --output partial.txt
EOF
  exit 1
}

[[ $# -lt 1 ]] && usage

DIR="$1"
shift

RANGE_START=1
RANGE_END=0
OUTFILE="file_dump.txt"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --range)
      [[ $# -lt 2 ]] && usage
      IFS=: read -r RANGE_START RANGE_END <<<"$2"
      shift 2
      ;;
    --output)
      [[ $# -lt 2 ]] && usage
      OUTFILE="$2"
      shift 2
      ;;
    -*|--*)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

[[ -d "$DIR" ]] || { echo "Error: '$DIR' is not a directory." >&2; exit 2; }

mapfile -d '' FILES < <(find "$DIR" -maxdepth 1 -type f -printf '%f\0' | sort -z)

TOTAL=${#FILES[@]}
[[ $TOTAL -eq 0 ]] && { echo "No files found in '$DIR'." >&2; exit 0; }

(( RANGE_END == 0 || RANGE_END > TOTAL )) && RANGE_END=$TOTAL

if (( RANGE_START < 1 || RANGE_START > RANGE_END || RANGE_END > TOTAL )); then
  echo "Error: --range $RANGE_START:$RANGE_END is out of bounds (1-$TOTAL)." >&2
  exit 3
fi

SLICE=("${FILES[@]:$((RANGE_START-1)):$((RANGE_END-RANGE_START+1))}")

: > "$OUTFILE"

for fname in "${SLICE[@]}"; do
  full_path="$DIR/$fname"
  {
    printf '===== %s =====\n' "$fname"
    cat -- "$full_path"
    printf '\n\n'
  } >> "$OUTFILE"
done

echo "Wrote ${#SLICE[@]} file(s) to '$OUTFILE'."
