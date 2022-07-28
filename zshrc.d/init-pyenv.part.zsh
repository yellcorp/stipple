# If your copy of .pyenv is a Git repo, upgrade like so:
#   cd ~/.pyenv/
#   git fetch
#   git checkout $LATEST_TAG_NAME
#   ./src/configure
#   make -C src

# To uninstall,
#   rm -r ~/.pyenv/

# The following comes from the recommendation here:
#   https://github.com/pyenv/pyenv#set-up-your-shell-environment-for-pyenv

if [[ -z "$PYENV_ROOT" && -d "$HOME/.pyenv" ]]; then
  export PYENV_ROOT="$HOME/.pyenv"
fi

if [[ -n "$PYENV_ROOT" && -d "$PYENV_ROOT" ]]; then
  command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
fi
