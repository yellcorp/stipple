function {
  local python="/usr/bin/python3"

  # See sourceall.zsh for explanation
  local thisfile="${BASH_SOURCE[0]:-${(%):-%x}}"

  if [[ -n "$thisfile" && -e "$thisfile" ]]; then
    local thisdir="$(dirname "$thisfile")"
    local parentdir="$(dirname "$thisdir")"
    export PROMPT="$("$python" "$parentdir"/prompt.py bgcolor=$YC_PROMPT_BG hostcolor=$YC_PROMPT_HOST)"
  fi
}
