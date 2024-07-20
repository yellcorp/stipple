"""
Builds a zsh prompt.

Composed of a zillion little helper functions that perform the
necessary wrapping and escaping and substitution - I figure that's
better and more understandable than handcrafting a train of keymash.

There is the ability to set unique colors per host/user combination
through passing arguments to this script. In practice, this script is
called with the value of the following shell variables with the
assumption they have been set before this script has been called.

- $YC_PROMPT_BG (bgcolor) sets the background color when connected
  over SSH *and* using iTerm. It is a CSS-style 3- or 6- digit hex
  color, without a leading hash.

- $YC_PROMPT_HOST (hostcolor) sets the foreground color used for the
  host name. It is *similar* but not identical to a CSS 3-digit color.
  The difference is each digit in this value must be 0-5, where 5
  represents the maximum brightness for a color component. This
  reflects the granularity of the xterm256 color palette.
"""

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
# - Separate iTerm profiles must be maintained, differing only in
#   their background color. This can be streamlined to some extent by
#   using 'dynamic' profiles[1], which amount to placing a JSON
#   representation of only the preferences that differ in a special
#   folder in ~/Library.
# - Requires shell integration to be installed, which doesn't work
#   over tmux.
#   - Update: it *does* work, sort of, it is just off by default.
#     Enable it with:
#       export ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX=1
#     It is off by default because it works best with tmux -CC rather
#     than in normal mode. Might be worth adding to `tmuxmain` script.
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
# - No automatic cleanup - the last background color remains in
#   effect, even if (say) an ssh session is interrupted. For this
#   reason, if background color changing is done at all, it must be
#   done everywhere a prompt appears
# - Cannot 'unset' the background color and return to inheriting the
#   profile default (that I know of). This script assumes the default
#   is #000000, which precludes 'light' themes.
#
# [1] https://iterm2.com/documentation-dynamic-profiles.html
# [2] https://iterm2.com/documentation-escape-codes.html

import functools
import os
import re
import sys
import warnings
from collections.abc import Callable, Generator
from typing import Optional

try:
    # This is Python 3.10+
    from typing import ParamSpec
except ImportError:
    # But we want to be runnable with MacOS stock 3.9 too
    class ParamSpec:
        def __init__(self, *args, **kwargs):
            pass


BEL = "\x07"
TAB = "\t"
ESC = "\x1b"
BSLASH = "\\"

_Params = ParamSpec("_Params")


def join(fn: Callable[_Params, list[str]]) -> Callable[_Params, str]:
    """
    Decorator that wraps a function that returns an iterable of
    strings. It concatenates the wrapped function's return value into
    a single string.

    There are two rationales: The first is that this script
    manipulates other formatting languages in which '{' and '%'
    feature frequently, so either choice of f-strings or %-formatting
    is likely to need escaping, which is a specific instance of the
    next point:

    The second is that sequences of punctuation and placeholders can
    be confusing to read - returning a list, or issuing a number of
    yields, allows the tokens to be broken up with whitespace,
    newlines, or assigned to variables.

    :param fn: The function to wrap. It can take any arguments, but
               must return some iterable of str.

    :return:   A new function that takes the same arguments as `fn`,
               but returns a single string.
    """

    @functools.wraps(fn)
    def wrapper(*args, **kwargs):
        return "".join(str(frag) for frag in fn(*args, **kwargs))

    return wrapper


def is_iterm() -> bool:
    return os.environ.get("LC_TERMINAL") == "iTerm2"


def is_ssh() -> bool:
    return len(os.environ.get("SSH_CONNECTION", "")) > 0


def is_tmux() -> bool:
    return os.environ.get("TERM_PROGRAM") == "tmux"


@join
def tmux_guard(seq: str) -> Generator[str]:
    """
    Wraps a string in a tmux guard sequence that tells tmux to pass it
    through rather than interpreting it.

    :param seq: The string to wrap.
    :return:    The wrapped string.
    """

    # lead sequence
    yield from [
        ESC,
        "P",
        "tmux;",
        ESC,
    ]

    yield seq

    # trail sequence
    yield from [
        ESC,
        BSLASH,
    ]


def if_tmux_guard(seq: str) -> str:
    """
    Wraps a string in a tmux guard sequence IF tmux is in use.
    Otherwise the string is returned verbatim.

    :param seq: The string to potentially wrap.
    :return:    The wrapped string if tmux is detected, otherwise the
                original string.
    """
    return tmux_guard(seq) if is_tmux() else seq


@join
def zp_guard(seq: str) -> list[str]:
    """
    Wraps a string in a zsh prompt guard sequence, being %{ … %}

    https://zsh.sourceforge.io/Doc/Release/Prompt-Expansion.html#Visual-effects

    :param seq: The string to wrap.
    :return:    The wrapped string.
    """
    return [
        "%{",
        seq,
        "%}",
    ]


@join
def iterm_bg(hexcolor: str) -> list[str]:
    """
    Returns an iTerm escape sequence that sets the pane's background
    color.

    https://iterm2.com/documentation-escape-codes.html

    :param hexcolor: A 3 or 6 character hex string representing the
                     color. This is similar to web color notation, but
                     without the leading '#'.
    :return:         The iTerm escape sequence.
    """

    if re.match(r"^([0-9a-f]{3}){1,2}$", hexcolor, flags=re.IGNORECASE) is None:
        warnings.warn(f"iterm_bg: invalid color: {hexcolor!r}")
        return []

    return [
        ESC,
        "]1337;",
        "SetColors=bg=srgb:",
        hexcolor,
        BEL,
    ]


def zp_tmux_iterm_bg(hexcolor: str) -> str:
    """
    Returns an iTerm background color sequence, wrapped in a tmux
    guard if needed, then in turn wrapped in a zsh prompt guard.

    :param hexcolor: A 3 or 6 character hex string representing the
                     color. This is similar to web color notation, but
                     without the leading '#'.
    :return:         The wrapped iTerm escape sequence.
    """
    return zp_guard(if_tmux_guard(iterm_bg(hexcolor)))


def xt_rgb_index(r: int, g: int, b: int) -> int:
    """
    Returns the xterm256 color index for a given r,g,b coordinate.

    Each parameter must be an integer in the range 0-5 inclusive. 0
    represents the absence of a color component, 5 represents its
    maximum value.

    :param r: The red component.
    :param g: The green component.
    :param b: The blue component.
    :return:  The color palette index.
    """
    return 36 * r + 6 * g + b + 16


# The ramp spanning indices 232-255 do not include 000 or FFF; they
# stop just short, so borrow those from the color cube at 16-231.
# Don't use the CGA colors at 0-15 as terminal apps let you redefine
# those.
_XTERM_GRAY_MAP = [16] + list(range(232, 256)) + [231]
assert len(_XTERM_GRAY_MAP) == 26


def xt_gray_index(level: int) -> int:
    """
    Returns the xterm256 color index for the given gray level.

    The parameter must be in the range 0-25 inclusive, with 0 being
    black and 25 being white.

    :param level: The gray level.
    :return:      The color palette index.
    """

    # This function isn't actually used at the time of writing but
    # it's here if you need it.

    return _XTERM_GRAY_MAP[level]


def xt_parse_rgbstr(rgb_str: str) -> Optional[int]:
    """
    Returns the xterm256 color index for a 3-digit RGB string.

    The parameter should be a 3-character string, with each character
    being a digit in the range '0'-'5' inclusive. '0' represents a
    complete absence of a color component, while '5' represents its
    maximum value.

    If the input string is empty, None will be returned.

    If the input is invalid, a warning will be issued and None will be
    returned.

    :param rgb_str: The color string.
    :return:        The color palette index.
    """

    if not rgb_str:
        return None

    if re.match(r"^[0-5]{3}$", rgb_str) is None:
        warnings.warn(f"xt_rgbstr_index: invalid color: {rgb_str!r}")
        return None

    r, g, b = [int(ch) for ch in rgb_str]
    return xt_rgb_index(r, g, b)


def xt_fg(palette_index: Optional[int]) -> str:
    """
    Returns an SGR sequence that sets the foreground color to the
    specified xterm256 color index.

    The returned sequence does not include the leading ESC[ or the
    trailing m, so multiple sequences can be composed.

    None is accepted for ease of function composition. In this case the
    returned string will be "" (empty).

    :param palette_index: The xterm256 color index.
    :return:              The SGR sequence.
    """
    return "" if palette_index is None else f"38;5;{palette_index}"


def xt_bg(palette_index: Optional[int]) -> str:
    """
    Returns an SGR sequence that sets the background color to the
    specified xterm256 color index.

    The returned sequence does not include the leading ESC[ or the
    trailing m, so multiple sequences can be composed.

    None is accepted for ease of function composition. In this case the
    returned string will be "" (empty).

    :param palette_index: The xterm256 color index.
    :return:              The SGR sequence.
    """
    return "" if palette_index is None else f"48;5;{palette_index}"


@join
def zp_sgr(params: str, text: str) -> list[str]:
    """
    Places a string between an SGR terminal sequence and an SGR reset.
    The SGR sequence and the reset are both wrapped with zsh prompt
    guards.

    :param params: The SGR commands to include. This should be the
                   part between - but not including - ESC[ and m. If
                   empty, the string will not be wrapped.
    :param text:   The text to include between the SGR and reset.
    :return:       The zsh prompt-guarded sequence.
    """
    if params:
        return [
            zp_guard(f"\x1b[{params}m"),
            text,
            zp_guard("\x1b[m"),
        ]

    return [text]


@join
def zp_bold(text: str) -> list[str]:
    """
    Wraps a string with a zsh prompt bold-start and bold-end sequence.
    """
    return ["%B", text, "%b"]


@join
def zp_fgcolor(color: str, text: str) -> list[str]:
    """
    Wraps a string with a zsh prompt foreground color set and reset
    sequence.

    This is explicitly for color arguments supported by zsh's %F
    expansion - otherwise use zp_sgr with an SGR sequence.

    :param color: The color string in zsh %F format.
    :param text:  The text to wrap.
    :return:      The wrapped text.
    """
    if color:
        return [
            "%F{",
            color,
            "}",
            text,
            "%f",
        ]

    return [text]


@join
def zp_if(condition: str, if_true: str, if_false: str) -> list[str]:
    """
    Builds a zsh prompt ternary - that is %(cond.iftrue.iffalse).

    This actually uses tabs as separators instead of periods.

    https://zsh.sourceforge.io/Doc/Release/Prompt-Expansion.html#Conditional-Substrings-in-Prompts

    :param condition: The condition to test. See the linked reference.
    :param if_true:   The prompt to use if the condition is true.
    :param if_false:  The prompt to use if the condition is false.
    :return:          The zsh prompt ternary.
    """
    return [
        "%(",
        condition,
        TAB,
        if_true,
        TAB,
        if_false,
        ")",
    ]


def parse_argv(argv: list[str]) -> dict[str, str]:
    userprefs = {
        "bgcolor": "",
        "hostcolor": "",
    }

    for arg in argv[1:]:
        key, eq, value = arg.partition("=")
        if not key or not eq:
            warnings.warn(f"Ignoring bad parameter {arg!r}")
        elif key in userprefs:
            if userprefs[key]:
                warnings.warn(f"Duplicate parameter {key!r}")
            else:
                userprefs[key] = value
        else:
            warnings.warn(f"Ignoring unknown parameter {key!r}")

    return userprefs


@join
def build_prompt(bgcolor: str = "", hostcolor: str = "") -> Generator[str]:
    # Set background color sequence

    set_bg_seq = ""
    if is_iterm():
        bgcolor_use = bgcolor if (bgcolor and is_ssh()) else "000"
        set_bg_seq = zp_tmux_iterm_bg(bgcolor_use)

    yield set_bg_seq

    # Line 1: host and workdir

    workdir_color = "yellow"

    # turn fg string into an xterm256 index
    host_fg_index = xt_parse_rgbstr(hostcolor)
    # turn fg index into an sgr seq
    host_style = xt_fg(host_fg_index)
    host = zp_sgr(host_style, "%n@%m")

    workdir = zp_bold(zp_fgcolor(workdir_color, "%~"))

    yield from [
        host,
        " ",
        workdir,
        "\n",
    ]

    # Line 2: error status (if nonzero) and prompt character

    error_color = "red"
    error_status = zp_fgcolor(error_color, "%?") + " "
    cond_error_status = zp_if("0?", "", error_status)

    glyph = zp_bold("%#")

    yield from [
        cond_error_status,
        glyph,
        " ",
    ]


def main():
    userprefs = parse_argv(sys.argv)
    prompt = build_prompt(**userprefs)

    # use like
    #   PROMPT="$(python3 prompt.py bgcolor=$YC_PROMPT_BG hostcolor=$YC_PROMPT_HOST)"
    #
    # remember that the YC_* vars are set in .zshrc but not exported,
    # so they're not available in subprocesses.
    print(prompt)


if __name__ == "__main__":
    main()
