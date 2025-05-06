#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") <directory> [--range N:M] [--output FILE]

  <directory>      Directory whose files will be dumped (recursively).
  --range N:M      Dump only the N-th through M-th files (1-based, alphabetical).
  --output FILE    Path of the output file (default: ./file_dump.txt).

Exclusions come from: \$(dirname "\$0")/excluded_filetypes.txt
  • Lines ending with "/" are treated as *directory names* to skip anywhere
    in the tree (e.g. ".git/", "node_modules/").
  • Other lines (starting with ".") are file-extension filters (e.g. ".pdf").

Examples
  $(basename "$0") ./assets
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


declare -a EXCL_EXT=() EXCL_DIR=()
add_rules() {
  local file=$1
  [[ -f "$file" ]] || return
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    if [[ "$line" == */ ]]; then
      EXCL_DIR+=("${line%/}")
    else
      EXCL_EXT+=("$line")
    fi
  done <"$file"
}
add_rules "$(dirname "$(readlink -f "$0")")/excluded_filetypes.txt"
add_rules "$DIR/excluded_filetypes.txt"

# Collect relative paths (full tree)
mapfile -d '' FILES < <(find "$DIR" -type f -printf '%P\0' | sort -z)

# filter exclusions
filtered=()
for f in "${FILES[@]}"; do
  skip=0

  # directory-name filters
  for d in "${EXCL_DIR[@]}"; do
    if [[ "$f" == "$d/"* || "$f" == */"$d/"* ]]; then skip=1; break; fi
  done
  ((skip)) && continue

  # extension filters
  ext=".${f##*.}"; ext="${ext,,}"
  for e in "${EXCL_EXT[@]}"; do
    [[ "$ext" == "$e" ]] && { skip=1; break; }
  done
  ((skip)) || filtered+=("$f")
done
FILES=("${filtered[@]}")

TOTAL=${#FILES[@]}
[[ $TOTAL -eq 0 ]] && { echo "No eligible files found in '$DIR'." >&2; exit 0; }

(( RANGE_END == 0 || RANGE_END > TOTAL )) && RANGE_END=$TOTAL
(( RANGE_START < 1 || RANGE_START > RANGE_END || RANGE_END > TOTAL )) && {
  echo "Error: --range $RANGE_START:$RANGE_END is out of bounds (1-$TOTAL)." >&2; exit 3; }

SLICE=("${FILES[@]:$((RANGE_START-1)):$((RANGE_END-RANGE_START+1))}")

: >"$OUTFILE"

# Optional: tree dump at top if available
if command -v tree >/dev/null; then
  {
    echo "# Directory structure:"
    tree -a "$DIR"
    echo -e "\n"
  } >>"$OUTFILE"
fi

for fname in "${SLICE[@]}"; do
  {
    printf '===== %s =====\n' "$fname"
    cat -- "$DIR/$fname"
    printf '\n\n'
  } >>"$OUTFILE"
done

echo "Wrote ${#SLICE[@]} file(s) to '$OUTFILE'."
