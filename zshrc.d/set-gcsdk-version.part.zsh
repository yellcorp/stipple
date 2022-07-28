# The gcloud cli "works best" with Python 3.7 for whatever reason(s). If
# pyenv is in use and a 3.7.x version is installed, this snippet configures
# gcloud to use that.

# This detects pyenv by checking for an env var called PYENV_ROOT so make
# sure that is set before running this.

function () {
  local gcsdk_py_version=3.7.13
  local gcsdk_py_bin="${PYENV_ROOT}/versions/${gcsdk_py_version}/bin/python3"

  if [[  \
    -z "${CLOUDSDK_PYTHON}" &&  \
    -n "${PYENV_ROOT}" &&  \
    -x "${gcsdk_py_bin}"  \
  ]]; then
    export CLOUDSDK_PYTHON="${gcsdk_py_bin}"
  fi
}
