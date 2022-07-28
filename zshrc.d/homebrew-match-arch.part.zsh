function ()
{
  # If there is a copy of Homebrew installed for both arm and intel,
  # this aliases `brew` to the binary that matches the running
  # architecture. Otherwise $PATH will be prioritizing whoever's
  # installer ran most recently.

  local brew_intel=/usr/local/Homebrew/bin/brew
  local brew_arm=/opt/homebrew/bin/brew

  if [[ -x "$brew_intel" && -x "$brew_arm" ]]; then
    case "$(/usr/bin/arch)" in
      i386|x86_64|x86_64h)
        alias brew="$brew_intel"
        ;;
      *)
        alias brew="$brew_arm"
        ;;
    esac
  fi
}
