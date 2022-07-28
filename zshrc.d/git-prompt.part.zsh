autoload -Uz vcs_info
precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )

zstyle ':vcs_info:*' enable git hg svn
zstyle ':vcs_info:*' check-for-changes true

# some non-ascii symbols throw off the RPROMPT alignment in pre-catalina
# versions of zsh, so you have to test them. these diamonds seem to be ok
zstyle ':vcs_info:*' unstagedstr '◇'
zstyle ':vcs_info:*' stagedstr '◆'

zstyle ':vcs_info:git:*' formats '%u%c %F{black}%K{cyan} %b %k%f'
zstyle ':vcs_info:git:*' actionformats '%F{black}%K{red} %a %k%K{cyan} %b %k%f'

setopt prompt_subst
RPROMPT=\$vcs_info_msg_0_
