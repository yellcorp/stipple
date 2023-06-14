"""
Copies terminfo data from newer ncurses to older ncurses.

This fixes tmux behavior when tmux is linked against a recent version of
ncurses, but runs applications linked against older versions of ncurses.
This situation can arise when tmux is installed from either MacPorts or
Homebrew, and is used to run stock zsh (or any other text mode application
bundled with macOS).

Symptoms of this bug include backspace moving the cursor to the right,
though appearing to 'logically' delete characters, and seeing the message
"WARNING: terminal is not fully functional"

This script is basically a cautious automation of this post:
- https://gpanders.com/blog/the-definitive-guide-to-using-tmux-256color-on-macos/
Or the solution to this issue:
- https://github.com/tmux/tmux/issues/2262

This script is idempotent; it can be run more than once with no practical
effect.
"""

import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

PACKAGE_NAME = b"ncurses"
NCURSES_VERSION_PREFIX = b"ncurses "
NCURSES_STOCK_EXPECTED_VERSION = NCURSES_VERSION_PREFIX + b"5.7.20081102"

INFOCMP_FALLBACK = b"infocmp"
INFOCMP_SUFFIX = b"/bin/infocmp"

STOCK_TIC = b"/usr/bin/tic"

TERMINFO_NAME = b"tmux-256color"


def get_user_terminfo_dir():
    return os.path.expanduser(os.path.join("~", ".local", "share", "terminfo"))


def package_files_macports(package_name: bytes):
    # MacPorts does not set an exit code if a package is not installed,
    # but it does print a header line, so validate it
    expected_header = b"Port " + package_name + b" contains:"

    try:
        report = subprocess.run(
            [b"port", b"contents", package_name],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            check=True,
        )
    except (subprocess.SubprocessError, OSError):
        return

    lines = report.stdout.splitlines(keepends=False)
    if len(lines) > 1:
        if lines.pop(0) == expected_header:
            for line in lines:
                if line.startswith(b"  "):
                    yield line[2:]


def package_files_homebrew(package_name: bytes):
    brew_env = dict(os.environb)
    brew_env.pop(b"HOMEBREW_COLOR", None)
    brew_env[b"HOMEBREW_NO_COLOR"] = b"1"
    try:
        report = subprocess.run(
            [b"brew", b"ls", b"--verbose", package_name],
            env=brew_env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            check=True,
        )
    except (subprocess.SubprocessError, OSError):
        return

    yield from report.stdout.splitlines(keepends=False)


def find_infocmp():
    candidates = []

    for pm_list in (
        package_files_macports(PACKAGE_NAME),
        package_files_homebrew(PACKAGE_NAME),
    ):
        for file in pm_list:
            if file.endswith(INFOCMP_SUFFIX):
                candidates.append(file)

    if len(candidates) == 0:
        candidates.append(INFOCMP_FALLBACK)

    best_exe = None
    best_version = None
    best_version_key = None
    for exe in candidates:
        try:
            r = subprocess.run(
                [exe, b"-V"],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                check=True,
            )
            version_str = r.stdout.rstrip()
            if version_str.startswith(NCURSES_VERSION_PREFIX):
                version_n = version_str[len(NCURSES_VERSION_PREFIX) :]
                print(f"found {exe!r} {version_n!r}")
                version_key = tuple(
                    int(n) for n in version_n.decode("ascii").split(".")
                )
                if best_version_key is None or version_key > best_version_key:
                    best_exe = exe
                    best_version = version_n
                    best_version_key = version_key
        except (subprocess.SubprocessError, OSError):
            continue

    if best_exe is None:
        print("No infocmp found")
    else:
        print(f"selecting {best_exe!r} {best_version!r}")
    return best_exe


def clamp_terminfo_number(key_value: bytes):
    key, h, int_str = key_value.partition(b"#")
    if h != b"#":
        return key_value

    try:
        if int_str.startswith(b"0x") or int_str.startswith(b"0X"):
            int_value = int(int_str[2:], 16)
        elif int_str.startswith(b"0"):
            int_value = int(int_str, 8)
        else:
            int_value = int(int_str, 10)
    except ValueError:
        return key_value

    if int_value > 32767:
        return key + b"#32767"

    return key_value


TERMINFO_INTEGER_PATTERN = re.compile(
    rb"""
        \b
        pairs\#
        (?:
            0[Xx][0-9A-Fa-f]+
            | 0[0-7]+
            | [1-9][0-9]*
        )
    """,
    re.VERBOSE,
)


def patch_shorts(terminfo_src: bytes):
    return TERMINFO_INTEGER_PATTERN.sub(
        lambda m: clamp_terminfo_number(m[0]), terminfo_src
    )


def dir_in_path(dir_, path_list):
    if path_list is None:
        return False
    if isinstance(path_list, str):
        paths = path_list.split(os.pathsep)
        if isinstance(dir_, bytes):
            dir_ = os.fsdecode(dir_)
    elif isinstance(path_list, bytes):
        paths = path_list.split(os.fsencode(os.pathsep))
        if isinstance(dir_, str):
            dir_ = os.fsencode(dir_)
    else:
        raise TypeError("path_list must be str or bytes")
    return dir_ in paths


def main():
    stock_tic_version = subprocess.run(
        [STOCK_TIC, b"-V"], stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, check=True
    ).stdout.rstrip()

    if stock_tic_version != NCURSES_STOCK_EXPECTED_VERSION:
        print(f"The version of tic at {STOCK_TIC} has an unexpected version")
        print("string. This script might need updating!")
        print(f"  Expected: {NCURSES_STOCK_EXPECTED_VERSION!r}")
        print(f"       Got: {stock_tic_version!r}")
        return 1

    infocmp = find_infocmp()
    if infocmp is None:
        print("Couldn't find an infocmp executable")
        return 1

    print(f"Exporting {TERMINFO_NAME}")
    infocmp_result = subprocess.run(
        [infocmp, b"-x", TERMINFO_NAME],
        check=True,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
    )

    # It's not enough to just export the terminfo data, we also have to patch
    # it because there's some wraparound/sign bug which interprets 0x10000 as
    # zero. Good fun!
    term_src = patch_shorts(infocmp_result.stdout)
    if term_src == infocmp_result.stdout:
        print("Warning: no patch was applied to terminfo source")

    out_dir = get_user_terminfo_dir()
    print(f"Output dir is {out_dir}")
    os.makedirs(out_dir, exist_ok=True)

    tempdir = tempfile.mkdtemp()
    try:
        src_file = os.path.join(tempdir, os.fsdecode(TERMINFO_NAME + b".src"))
        with open(src_file, "wb") as writer:
            writer.write(term_src)
        print(f"Compiling terminfo source with {STOCK_TIC} ({stock_tic_version})")
        subprocess.run(
            [STOCK_TIC, b"-x", b"-o", os.fsencode(out_dir), os.fsencode(src_file)],
            check=True,
            stdin=subprocess.DEVNULL,
        )
    finally:
        shutil.rmtree(tempdir)

    print("Complete")

    if not dir_in_path(out_dir, os.environb.get(b"TERMINFO_DIRS")):
        # Note - the advice printed here is already being followed if
        # sourceall.zsh is being sourced from .zshrc. However you will need
        # to start a new shell terminal for it to start having an effect.
        print()
        print("Could not find the user terminfo directory in TERMINFO_DIRS")
        print(f"  {out_dir}")
        print()
        print("Ensure your shell startup script contains the following line:")
        print("```")
        print('export TERMINFO_DIRS="$TERMINFO_DIRS":{}'.format(shlex.quote(out_dir)))
        print("```")
        print("Then restart your shell.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
