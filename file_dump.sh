#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [--path DIR] [<directory>] [--git-root] [--no-exclude] [--range N:M] [--include PATTERNS] [--output FILE]

  --path DIR          Directory whose files will be dumped (recursively). Takes precedence over positional <directory>.
  <directory>         Optional positional directory. Ignored if --path is provided.
  --git-root          Use the current Git repo root as the target, ignoring --path/positional.
  --no-exclude        Do not apply any exclusion rules.
  --range N:M         Dump only the N-th through M-th files (1-based, alphabetical).
  --include PATTERNS  Comma-separated shell globs to include (e.g. '*.yml,*.yaml'). Only matching files are included.
  --output FILE       Path of the output file (default: ./file_dump.txt).

If no --path or positional directory is given, defaults to the current working directory (PWD).

Exclusions come from 'excluded_filetypes.txt' searched in order:
  1) Directory of this script
  2) <directory>/excluded_filetypes.txt
  3) \$XDG_CONFIG_HOME/file_dump/excluded_filetypes.txt
  4) \$HOME/.config/file_dump/excluded_filetypes.txt
If none are found, a built-in default exclusion list is used.

Examples
  $(basename "$0") --path ./services --include '*.yml,*.yaml' --output compose.txt
  $(basename "$0") ./src --range 5:8 --output partial.txt
  $(basename "$0") --git-root --include '*.yml,*.yaml' --output all_compose.txt
  $(basename "$0") --no-exclude                     # dump everything text-like in PWD
  $(basename "$0")                                   # dumps PWD
EOF
  exit 1
}

SCRIPT_INVOCATION="${BASH_SOURCE[0]:-$0}"
SCRIPT_PATH="$(command -v "$SCRIPT_INVOCATION" || true)"
if [[ -z "$SCRIPT_PATH" ]]; then
  SCRIPT_PATH="$SCRIPT_INVOCATION"
fi
SCRIPT_DIR="$(dirname "$(readlink -f "$SCRIPT_PATH")")"

RANGE_START=1
RANGE_END=0
OUTFILE="file_dump.txt"
USE_GIT_ROOT=0
NO_EXCLUDE=0
declare -a INCLUDE_GLOBS=()

DIR=""
PATH_ARG=""

if (( $# > 0 )) && [[ ! "${1:-}" =~ ^- ]]; then
  DIR="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      [[ $# -lt 2 ]] && usage
      PATH_ARG="$2"
      shift 2
      ;;
    --git-root)
      USE_GIT_ROOT=1
      shift
      ;;
    --no-exclude)
      NO_EXCLUDE=1
      shift
      ;;
    --range)
      [[ $# -lt 2 ]] && usage
      IFS=: read -r RANGE_START RANGE_END <<<"$2"
      shift 2
      ;;
    --include)
      [[ $# -lt 2 ]] && usage
      IFS=',' read -r -a parts <<<"$2"
      for p in "${parts[@]}"; do
        [[ -n "$p" ]] && INCLUDE_GLOBS+=("$p")
      done
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

if (( USE_GIT_ROOT == 1 )); then
  if git_root="$(git -C . rev-parse --show-toplevel 2>/dev/null)"; then
    DIR="$git_root"
  else
    echo "Error: --git-root used outside a git repository." >&2
    exit 2
  fi
else
  if [[ -n "$PATH_ARG" ]]; then
    DIR="$PATH_ARG"
  elif [[ -z "$DIR" ]]; then
    DIR="$(pwd)"
  fi
fi

[[ -d "$DIR" ]] || { echo "Error: '$DIR' is not a directory." >&2; exit 2; }

declare -a EXCL_EXT=() EXCL_DIR=()
add_rules() {
  local file=$1
  [[ -f "$file" ]] || return
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ "$line" == */ ]]; then
      EXCL_DIR+=("${line%/}")
    else
      EXCL_EXT+=("${line,,}")
    fi
  done <"$file"
}

add_builtin_default_rules() {
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    if [[ "$line" == */ ]]; then
      EXCL_DIR+=("${line%/}")
    else
      EXCL_EXT+=("${line,,}")
    fi
  done <<'DEFAULT_RULES'
.git/
.svn/
.hg/
.idea/
.vscode/
node_modules/
dist/
build/
target/
obj/
bin/
.gitignore
.gitattributes
.gitmodules
.pt
.bin
.weights
.ckpt
.onnx
.tflite
.pdf
.doc
.docx
.ppt
.pptx
.xls
.xlsx
.odt
.ods
.odp
.rtf
.jpg
.jpeg
.png
.gif
.bmp
.tif
.tiff
.webp
.ico
.psd
.ai
.eps
.mp3
.wav
.flac
.ogg
.m4a
.mp4
.mkv
.mov
.avi
.wmv
.flv
.swf
.zip
.tar
.tgz
.tbz2
.gz
.bz2
.xz
.7z
.rar
.iso
.exe
.dll
.so
.dylib
.a
.o
.lib
.obj
.class
.jar
.wasm
.pdb
.dsym
.pyc
.pyo
.pyd
.whl
.egg
.egg-info
.pyz
.pycache
.lock
.rlib
.rmeta
.crate
.d
.ll
.nupkg
.snupkg
.node
.bundle.js
.min.js
.map
.br
DEFAULT_RULES
}

if (( NO_EXCLUDE == 0 )); then
  rules_loaded=0
  add_rules "$SCRIPT_DIR/excluded_filetypes.txt" && rules_loaded=1 || true
  add_rules "$DIR/excluded_filetypes.txt" && rules_loaded=1 || true
  if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
    add_rules "$XDG_CONFIG_HOME/file_dump/excluded_filetypes.txt" && rules_loaded=1 || true
  fi
  add_rules "$HOME/.config/file_dump/excluded_filetypes.txt" && rules_loaded=1 || true
  if (( rules_loaded == 0 )); then
    add_builtin_default_rules
  fi
else
  EXCL_EXT=()
  EXCL_DIR=()
fi

mapfile -d '' FILES < <(find "$DIR" -type f -printf '%P\0' | sort -z)

filtered=()
for f in "${FILES[@]}"; do
  skip=0

  if (( NO_EXCLUDE == 0 )); then
    for d in "${EXCL_DIR[@]}"; do
      if [[ "$f" == "$d/"* || "$f" == */"$d/"* || "$f" == "$d" ]]; then
        skip=1; break
      fi
    done
    ((skip)) && continue

    ext=".${f##*.}"; ext="${ext,,}"
    for e in "${EXCL_EXT[@]}"; do
      if [[ "$ext" == "$e" ]]; then skip=1; break; fi
    done
    ((skip)) && continue
  fi

  if (( ${#INCLUDE_GLOBS[@]} > 0 )); then
    inc=0
    for pat in "${INCLUDE_GLOBS[@]}"; do
      if [[ "$f" == $pat ]]; then inc=1; break; fi
    done
    ((inc)) || continue
  fi

  filtered+=("$f")
done
FILES=("${filtered[@]}")

TOTAL=${#FILES[@]}
if [[ $TOTAL -eq 0 ]]; then
  echo "No eligible files found in '$DIR'. Wrote nothing to '$OUTFILE'." >&2
  exit 0
fi

(( RANGE_END == 0 || RANGE_END > TOTAL )) && RANGE_END=$TOTAL
(( RANGE_START < 1 || RANGE_START > RANGE_END || RANGE_END > TOTAL )) && {
  echo "Error: --range $RANGE_START:$RANGE_END is out of bounds (1-$TOTAL)." >&2; exit 3; }

SLICE=("${FILES[@]:$((RANGE_START-1)):$((RANGE_END-RANGE_START+1))}")

: >"$OUTFILE"

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

echo "Wrote ${#SLICE[@]} file(s) from '$DIR' to '$OUTFILE'."
