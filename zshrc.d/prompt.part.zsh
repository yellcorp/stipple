# Builds a zsh prompt
#
# - There is the facility for defining unique colors per host/user
#   combination through setting certain variables. To have any effect,
#   said variables must be set before this script is sourced.
#
#   - $YC_PROMPT_BG sets the background color when connected over SSH
#     *and* using iTerm. It is a CSS-style 3- or 6- digit hex color,
#     without a leading hash.
#
#   - $YC_PROMPT_HOST sets the foreground color for displaying the host
#     name. It is *similar* but not identical to a CSS 3-digit color.
#     The difference is each digit in this value must be 0-5, where 5
#     represents the maximum brightness for a color component. This
#     reflects the granularity of the xterm256 color palette.

# iTerm notes:
#
# There are two methods to switch the background color in iTerm. Most
# discussion online will recommend the use of the 'Automatic profile
# switching' feature. This is found under Preferences > Profiles >
# Advanced.
#
# Advantages:
# - Can control any aspect of the profile per host, not just screen
#   color
# - Can switch profiles based on username, path and job as well
# - Switches profiles back when they no longer apply
#
# Disadvantages:
# - Separate iTerm profiles must be maintained, differing only in their
#   background color. This can be streamlined to some extent by using
#   'dynamic' profiles[1], which amount to placing a JSON representation
#   of only the preferences that differ in a special folder in
#   ~/Library.
# - Requires shell integration to be installed, which doesn't work over
#   tmux.
#   - Update: it *does* work, sort of, it is just off by default.
#     Enable it with:
#       export ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX=1
#     It is off by default because it works best with tmux -CC rather than
#     in normal mode. Might be worth adding to `tmuxmain` script.
#
# This script takes another approach, using an iTerm-specific terminal
# control sequence to set the background color[2].
#
# Advantages:
# - Works with tmux integration (the big one)
# - Can set the color preferences on the remote machine, rather than
#   maintaining a local preference file for each remote host and then
#   replicating them all across other potential client machines.
#
# Disadvantages:
# - No automatic cleanup - the last background color remains in effect,
#   even if (say) an ssh session is interrupted. For this reason, if
#   background color changing is done at all, it must be done everywhere
#   a prompt appears
# - Cannot 'unset' the background color and return to inheriting the
#   profile default (that I know of). This script assumes the default is
#   #000000, which precludes 'light' themes.
#
# [1] https://iterm2.com/documentation-dynamic-profiles.html
# [2] https://iterm2.com/documentation-escape-codes.html

_yc_build_prompt () {
  local wd_color=yellow
  local error_color=red

  local set_bg_seq
  if [[ "$LC_TERMINAL" = "iTerm2" ]]; then
    if [[ -n "$SSH_CONNECTION" ]]; then
      set_bg_seq=$(_ycbp_iterm_bg $YC_PROMPT_BG)
    fi
    if [[ -z "$set_bg_seq" ]]; then
      set_bg_seq=$(_ycbp_iterm_bg 000)
    fi
  fi

  # turn fg string into an xterm256 index
  local host_fg=$(_ycbp_xt_rgb $YC_PROMPT_HOST)
  # turn fg index into an sgr seq
  local host_style=$(_ycbp_xt_fg $host_fg)
  local host="$(_ycbp_sgr "$host_style" "%n@%m")"

  local wd="$(_ycbp_bold "$(_ycbp_fgcolor "$wd_color" "%~")")"

  local error_status="$(_ycbp_fgcolor $error_color %?) "
  local if_error_status="$(_ycbp_if "0?" "" "$error_status")"
  local glyph="$(_ycbp_bold '%#')"

  echo "${set_bg_seq}${host} ${wd}\n${if_error_status}${glyph} "
}

_ycbp_bold () {
  echo "%B$1%b"
}

_ycbp_fgcolor () {
  # Used for color names/indices that zsh's %F understands - otherwise use
  # _ycbp_sgr
  #
  # Arguments:
  #   $1 - The color name to use. If empty, the string will not be wrapped.
  #   $2 - The string to format.
  if [[ -n "$1" ]]; then
    echo "%F{$1}$2%f"
  else
    echo "$2"
  fi
}

_ycbp_if () {
  # Builds a prompt ternary - i.e. %(cond.iftrue.iffalse). This actually uses ^
  # as the separator, so don't include that in the true or false strings
  #
  # Arguments:
  #   $1 - The query
  #   $2 - The string to use when the query is true
  #   $3 - The string to use when the query is false
  echo "%($1^$2^$3)"
}

_ycbp_sgr () {
  # Places a string between an SGR terminal sequence and an SGR reset.
  #
  # Arguments:
  #   $1 - The SGR parameters to use. This should be the part between - but not
  #        including - ESC[ and m. If empty, the string will not be wrapped.
  #   $2 - The string to format.
  if [[ -n "$1" ]]; then
    printf '%%{\x1b[%sm%%}%s%%{\x1b[m%%}' "$1" "$2"
  else
    printf '%s' "$2"
  fi
}

_ycbp_iterm_bg () {
  # Generates an iTerm control sequence that sets the background color. It is
  # wrapped in a tmux guard if $TMUX is set.
  if [[ "$1" =~ ^([0-9A-Fa-f]{3}){1,2}$ ]]; then
    # the raw sequence that iTerm understands
    local seq=$( printf '\x1b]1337;SetColors=bg=srgb:%s\x07' "$1" )
    # wrap it in the zsh prompt guard ( %{ ... %} ) and also a tmux guard if
    # necessary
    printf '%%{%s%%}' "$( _ycbp_if_tmux_guard "$seq" )"
  fi
}

_ycbp_if_tmux_guard () {
  # Wraps the provided string with a tmux guard wrapper IF $TMUX is set.
  # Otherwise, returns the provided string unmodified.
  if [ -n "$TMUX" ]; then
    _ycbp_tmux_guard "$1"
  else
    printf '%s' "$1"
  fi
}

_ycbp_tmux_guard () {
  # To smuggle proprietary sequences out of tmux, they need to be wrapped
  # with:
  # before: ESC 'P' 'tmux;' ESC
  # after: ESC BACKSLASH
  printf '\x1bPtmux;\x1b%s\x1b\x5c' "$1"
}

_ycbp_xt_gray () {
  # Calculates the xterm256 color index for a gray level from 0 to 25,
  # inclusive.

  if (( $1 == 0 )); then echo 16
  elif (( 0 < $1 && $1 < 25 )); then echo $(( $1 + 231 ))
  elif (( $1 == 25 )); then echo 231
  fi
}

_ycbp_xt_rgb () {
  # Calculates the xterm256 color index for the given RGB values, each ranging
  # from 0 to 5 inclusive.
  #
  # Arguments:
  #   $1 - A three-character string, with each character being a digit in the
  #        range '0'-'5' inclusive.
  local rgb="$1"
  if [[ "$rgb" =~ [0-5]{3} ]]; then
    local R=$rgb[1]  # character indices are 1-based in zsh!
    local G=$rgb[2]
    local B=$rgb[3]
    echo $((36 * $R + 6 * $G + $B + 16))
  fi
}

_ycbp_xt_fg () {
  # Produces an SGR sequence that sets the foreground color to the specified
  # xterm256 color index.
  [[ -n "$1" ]] && echo "38;5;$1"
}

_ycbp_xt_bg () {
  # Produces an SGR sequence that sets the background color to the specified
  # xterm256 color index.
  [[ -n "$1" ]] && echo "48;5;$1"
}

export PROMPT="$(_yc_build_prompt)"
