# The recommended Python version varies with gcloud version. Find the
# latest advice here:
#
#   https://cloud.google.com/sdk/docs/install#mac

function {
  # Only do anything if gcloud's special var is not already set
  if [[ -z "${CLOUDSDK_PYTHON}" ]]; then
    local gcloud_venv="${HOME}/gcloud/venv"
    local gcloud_python="${gcloud_venv}/bin/python3"

    if [[ -x "${gcloud_python}" ]]; then
      # This script used to scour pyenv for a suitable Python interpreter,
      # but then I switched to just creating a venv for gcloud in a
      # well-known directory.
      #
      # The tidiest way I can think of at the moment is to create a dir in
      # $HOME to house both the google-cloud-sdk dir and its venv as
      # siblings:
      #
      # $HOME/
      # - gcloud/
      #   - google-cloud-sdk/
      #   - venv/
      #
      # Make the necessary venv with
      # ${PYTHON} -v venv ~/gcloud/venv
      #
      # Where ${PYTHON} is the Python interpreter you want to use with
      # gcloud.
      #
      # If some subcomponent of gcloud wants you to install some Python
      # package:
      #
      # ~/gcloud/venv/bin/pip3 install [packages...]

      export CLOUDSDK_PYTHON="${gcloud_python}"
      # TODO: do we need CLOUDSDK_PYTHON_SITEPACKAGES ?
    fi
  fi
}
