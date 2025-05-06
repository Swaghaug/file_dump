# file_dump

Dump one or more files (alphabetical order) into a single text file – handy for
quick diffs, reviews, or email pastes.

```bash
fdump                 # dump every tracked file in the current Git repo
fdump --range 10:15   # restrict to a slice
fdump /etc --output etc.txt
```

---

## Installation

```bash
git clone https://github.com/<your-username>/file_dump.git
cd file_dump
chmod +x install.sh file_dump.sh
./install.sh          # copies the script to ~/.local/bin by default
```

The installer appends an alias to **~/.bashrc**:

```bash
alias fdump='file_dump "$(git -C . rev-parse --show-toplevel 2>/dev/null || pwd)"'
```

Open a new shell or run `source ~/.bashrc` to activate it.

---

## Usage

```bash
# full repository dump (default output: ./file_dump.txt)
fdump

# dump just the 3rd–7th files in the current directory
fdump . --range 3:7 --output subset.txt

# dump every file in /var/log
fdump /var/log
```

Options:

- **--range N:M** – slice (1-based, inclusive)
- **--output FILE** – set output path (default: `file_dump.txt`)

If you call `fdump` inside a Git repository, the alias automatically points the
script at the repo’s root; outside Git it uses the current directory.

---

## Uninstall

```bash
rm ~/.local/bin/file_dump
sed -i '/added by file_dump installer/d;/alias fdump=/d' ~/.bashrc
```

---

## License

MIT
