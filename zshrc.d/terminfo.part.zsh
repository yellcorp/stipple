# Part of a fix for weird behavior when running bundled macOS CLI apps
# through recent versions of tmux. See terminfo-backport.py.

export TERMINFO_DIRS="$TERMINFO_DIRS":"$HOME"/.local/share/terminfo
