cd "$(dirname "$0")" &&  \
cd zshrc.d  &&  \

# pulled from their install script here
#  https://iterm2.com/shell_integration/install_shell_integration.sh
curl -SsL https://iterm2.com/shell_integration/zsh > iterm2_shell_integration.part.zsh
