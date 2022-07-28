# The following lines were added by compinstall

zstyle ':completion:*' expand prefix suffix
zstyle ':completion:*' file-sort name
zstyle ':completion:*' ignore-parents pwd
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list 'm:{[:lower:]}={[:upper:]}'
zstyle ':completion:*' max-errors 1
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' verbose true
zstyle :compinstall filename ~/.zsh.d/completion.zsh

autoload -Uz compinit
compinit
# End of lines added by compinstall
