# The gcloud cli "works best" with Python 3.7 for whatever reason(s). If
# pyenv is in use and a 3.7.x version is installed, this snippet configures
# gcloud to use that.

# This advice should probably be periodically re-checked:
# https://cloud.google.com/sdk/docs/install#mac
#
# As of version 395, this installer feature was present:
#
# """
# For Cloud SDK release version 352.0.0 and above, the main install script
# offers to install CPython's Python 3.7 on Intel-based Macs.
# """

# This snippet detects pyenv by checking for an env var called PYENV_ROOT,
# so make sure that is set before running this.

function () {
  if [[ -z "${CLOUDSDK_PYTHON}" && -n "${PYENV_ROOT}" ]]; then
    local best=-1
    local best_exe
    local pydir

    # Find the highest-versioned Python 3.7.x available.
    for pydir in "${PYENV_ROOT}"/versions/3.7.*; do
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
