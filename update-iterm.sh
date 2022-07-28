# pulled from their install script here
#  https://iterm2.com/shell_integration/install_shell_integration.sh

cd "$(dirname "$0")"/zshrc.d &&  \
[ -f iterm2_shell_integration.part.zsh ] &&  \
curl -SsL https://iterm2.com/shell_integration/zsh > iterm2_shell_integration.part.zsh
