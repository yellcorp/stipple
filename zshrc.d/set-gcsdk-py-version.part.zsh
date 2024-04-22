# The recommended Python version varies with gcloud version. Find the latest
# advice here:
#
#   https://cloud.google.com/sdk/docs/install#mac
#
# This snippet checks for a dedicated Python venv for use with `gcloud` at a
# well-known location, then falls back to an older strategy of searching
# pyenv installed versions. Ideally all computers I use should be migrated
# to the newer, simpler venv approach, but the old snippet is there while I
# switch over.

function {
  # Only do anything if gcloud's special var is not already set
  if [[ -z "${CLOUDSDK_PYTHON}" ]]; then
    local gcloud_venv="${HOME}/gcloud/venv"
    local gcloud_python="${gcloud_venv}/bin/python3"

    if [[ -x "${gcloud_python}" ]]; then
      # Newer, simpler strat: just make a venv and stick it in a well-known
      # location. It requires a slightly ugly dir arrangement, installing
      # gcloud into
      #
      #   ~/gcloud/google-cloud-sdk
      #
      # but the simplification is worth it.
      #
      # Make the necessary venv with
      # ${PYTHON} -v venv ~/gcloud/venv
      #
      # If some subcomponent of gcloud wants you to install some Python
      # package:
      #
      # ~/gcloud/venv/bin/pip3 install [packages...]

      export CLOUDSDK_PYTHON="${gcloud_python}"
      # TODO: do we need CLOUDSDK_PYTHON_SITEPACKAGES ?

    elif [[ -n "${PYENV_ROOT}" ]]; then
      # Older overwrought way which I thought was clever at the time. Grovel
      # pyenv, if available, for an ideal Python version.

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

        # Make sure `gcloud compute ssh` can see numpy if you follow the nag
        # to install it
        export CLOUDSDK_PYTHON_SITEPACKAGES=1
      fi
    fi
  fi
}
