```markdown
# file_dump

Dump one or more **text-friendly** files into a single file while automatically
skipping common binary formats.

```bash
fdump                 # dump every tracked file in the current Git repo
fdump --range 10:15   # slice
fdump /etc --output etc.txt
```

---

## Installation

```bash
git clone https://github.com/<your-username>/file_dump.git
cd file_dump
chmod +x install.sh file_dump.sh
./install.sh
```

Installs to `~/.local/bin` and appends:

```bash
alias fdump='file_dump "$(git -C . rev-parse --show-toplevel 2>/dev/null || pwd)"'
```

to **~/.bashrc**. Reload with `source ~/.bashrc`.

---

## Excluding filetypes

`excluded_filetypes.txt` (installed next to the script) contains a broad list of
binary/media extensions – adjust as you like. The script compares extensions
case-insensitively.

---

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--range N:M` | Dump only files N through M (1-based, inclusive) | all |
| `--output FILE` | Output path | `file_dump.txt` |

If run inside a Git repository, **fdump** targets the repo root; otherwise, it
uses the current directory.

---

## Uninstall

```bash
rm ~/.local/bin/file_dump ~/.local/bin/excluded_filetypes.txt
sed -i '/added by file_dump installer/d;/alias fdump=/d' ~/.bashrc
```

MIT License
```
