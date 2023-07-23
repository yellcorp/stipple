_yc_nvm_lazy_load () {
  unset -f nvm node npm npx
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
}

nvm () {
  _yc_nvm_lazy_load
  nvm $@
}

node () {
  _yc_nvm_lazy_load
  node $@
}

npm () {
  _yc_nvm_lazy_load
  npm $@
}

npx () {
  _yc_nvm_lazy_load
  npx $@
}
