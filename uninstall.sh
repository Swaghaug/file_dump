rm ~/.local/bin/file_dump
rm -f ~/.local/bin/excluded_filetypes.txt
rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/file_dump/excluded_filetypes.txt"
sed -i '/added by file_dump installer/d;/alias fdump=/d' ~/.bashrc
echo "✔ Uninstallation complete."