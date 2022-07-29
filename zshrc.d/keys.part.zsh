# Note that by default, the terminal pane in IntelliJ and family intercept
# `esc` and use it to switch focus to the editor. You'll want to change
# that in
# Preferences > Keymap > Plugins > Terminal > Switch focus to editor

bindkey -v

function () {
  for keymap_name in emacs viins vicmd; do
    if [[ "$TERM" = xterm* ]]; then
      # See README.md for rationale. These are `xterm-noapp` sequences.
      bindkey -M $keymap_name $'\033[H' beginning-of-line
      bindkey -M $keymap_name $'\033[F' end-of-line
    fi
    bindkey -M $keymap_name "$key[Delete]" delete-char
    bindkey -M $keymap_name "$key[Home]" beginning-of-line
    bindkey -M $keymap_name "$key[End]" end-of-line
  done
}
