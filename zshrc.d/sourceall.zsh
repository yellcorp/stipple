# This is wrapped in an anonymous function so the loop variable isn't left
# behind in the ensuing environment. Unnamed functions in zsh are
# immediately invoked.

function {
  # "${BASH_SOURCE[0]} equivalent in zsh?"
  # https://stackoverflow.com/questions/9901210/bash-source0-equivalent-in-zsh#answer-28336473
  #
  # Breakdown:
  #
  # BASH_SOURCE[0]
  #   the way it's done in bash; might as well make it compatible
  #
  # First :-
  #   fall back to second expression if first results in nothing
  #
  # (%)
  #   ZSH expansion flag - turn on prompt %-interpolations. This is
  #   required to unlock the %x token.
  #   > man zshexpn#Parameter Expansion Flags
  #
  # Second :-
  #   again the fallback separator, in this case, kind of an abuse of
  #   the :- notation. Recall that the text *before* the :- must be a
  #   variable name, with another expression following. When %x is
  #   parsed in the context of a variable name (even when the name is an
  #   empty string, like here), the operation is to strip a trailing x.
  #   https://stackoverflow.com/questions/9901210/bash-source0-equivalent-in-zsh#comment-101839321
  #
  #   """
  #   ${(%)%N} is like ${%N}, but subject to the (%) flag. ${%N} would
  #   attempt to expand the variable with an empty-string name (which
  #   isn't a real thing, but always successfully expands to nothing)
  #   and remove a trailing N. Using ${(%):-%N} attempts to expand that
  #   same empty-string variable, and then since that's empty, uses %N
  #   as a default value... which is then expanded like a prompt because
  #   of the (%) flag
  #   """
  #
  # %x
  #   The name of the file containing the source code currently being executed
  #   > man zshmisc#SIMPLE PROMPT ESCAPES

  local thisfile="${BASH_SOURCE[0]:-${(%):-%x}}"

  # Do an -f (file exists) check just to confirm the result of the above
  # keymash actually is a file

  if [[ -n "$thisfile" && -e "$thisfile" ]]; then
    local thisdir="$(dirname "$thisfile")"
    for init_script in "$thisdir"/*.part.zsh; do
      . "$init_script"
    done
  fi
}
