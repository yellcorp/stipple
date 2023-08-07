# The following link says
# - Supported versions are 3.5-3.9
# - The installer for Cloud SDK versions > 352.0.0 offer to install Python 3.7
# https://cloud.google.com/sdk/docs/install#mac
#
# However starting in version 433.0.0, the following notice appears:
# "Note: Support for Python 3.5-3.7 will be deprecated on August 8th, 2023."
# The CLI also emits this message when running.
#
# Presumably, the ideal Python version to run is 3.9.
#
# This snippet detects pyenv by checking for an env var called PYENV_ROOT,
# so make sure that is set before running this.

function () {
  if [[ -z "${CLOUDSDK_PYTHON}" && -n "${PYENV_ROOT}" ]]; then
    local best=-1
    local best_exe
    local pydir

    # Find the highest-versioned Python 3.9.x available.
    #
    # (N) is a 'Glob Qualifier' - it sets the NULL_GLOB option for the
    # pattern. Otherwise an error will be output if nothing matches
    # see man zshexpn#Glob Qualifiers
    #     man zshoptions#NULL_GLOB

    for pydir in "${PYENV_ROOT}"/versions/3.9.*(N); do
      # Use zsh :e to isolate the filename 'extension' - i.e. everything
      # after the last dot, which is the patch level number in this context.
      if (( ${pydir:e} > ${best} )) && [[ -x "${pydir}/bin/python3" ]]; then
        best=${pydir:e}
        best_exe="${pydir}/bin/python3"
      fi
    done

    if [[ -n "${best_exe}" ]]; then
      export CLOUDSDK_PYTHON="${best_exe}"
    fi
  fi
}
