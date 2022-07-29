# stipple

Bunch of dot(file)s, mostly shell init scripts.

## How To Do It

1. Clone this repo onto your computer somewhere. `~/stipple` will do.
2. In your `.zshrc`, add the following line:
   ```
   . ~/stipple/zshrc.d/sourceall.zsh
   ```
3. Restart shell

## Keyboard / terminal notes

Or what I think I've learned after wading through a billion "help Home and
End don't work" Stackoverflows, Serverfaults, and Githubs. This is my
attempt at a solution that has some rationale behind it, rather than the
first thing that appears to work, of which there's a lot online.

### 1. `ncurses` on stock macOS is super old

This is a big one - fix it first! Otherwise it just confounds the rest of
the troubleshooting process.

This causes recent versions of `tmux` to be a chaotic mess as it declares
itself as `tmux-256color` which is not in stock macOS's 2008-era `terminfo`
database.  Running `python3 terminfo-backport.py` will take care of it. See
that file for more info and sources. In short, it uses new `ncurses` to export
the profile for `tmux-256color` to a location that old `ncurses` can read it.

### 2. `zsh`'s `vi` mode does not bind home, end or delete by default.

I think. This is probably fine for Real Ones but I'm not a Real One.

### 3. Nobody agrees on which bytes should be sent by the Home or End keys.

It seems to be broadly split among three categories, at least out of the
terminals I'm likely to encounter:

|                  | `khome`           | `kend`            | `home`        |
| ---------------- | ----------------- | ----------------- | ------------- |
| `xterm-256color` | `ESC` `O` `H`     | `ESC` `O` `F`     | `ESC` `[` `H` |
| `xterm-noapp`    | `ESC` `[` `H`     | `ESC` `[` `F`     |               |
| `tmux-256color`  | `ESC` `[` `1` `~` | `ESC` `[` `4` `~` |               |

Sources: [The original since 1998](https://invisible-island.net/ncurses/terminfo.src.html)
| [Apple's really old copy](https://opensource.apple.com/source/ncurses/ncurses-57/ncurses/misc/terminfo.src.auto.html)

Also some genealogy:

- `xterm-256color` inherits from…
  - `xterm-new`, which defines `khome` and `kend`, and inherits from…
    - `xterm-basic`, which defines `home`.
- `tmux-256color`
  - `tmux`
  - `screen`, which defines `khome` and `kend`.

What's the difference between `khome` and `home`? I don't know. I think
it's something like `khome` being the key code and `home` being the terminal
sequence that performs the action. Not sure.

[This discussion](https://github.com/romkatv/zsh4humans/issues/7#issuecomment-595233321)
buckets them into xterm application mode, xterm raw mode, and TTY. These
correspond with the above table in order. By default, iTerm, Visual Studio
Code terminal, and IntelliJ terminal all send `xterm-noapp` sequences.

- [Brief note about application mode](https://web.archive.org/web/20160407191115/http://homes.mpimf-heidelberg.mpg.de/~rohm/computing/mpimf/notes/terminal.html)
- [Pull request for some thing from 2012 discussing application mode](https://github.com/sorin-ionescu/prezto/pull/314)
  - One kicker:
    > However, values from [terminfo] are only reliable if the terminal is
    > in "application mode".
- [XTerm FAQ, a deep deep dive which somewhat explains how we got here](https://invisible-island.net/xterm/xterm.faq.html)
  - [About Home and End specifically](https://invisible-island.net/xterm/xterm.faq.html#xterm_pc_style)

In spite of all this, since macOS 10.15, `/etc/zshrc` pulls a bunch of key
mappings from `$terminfo`, which is populated by zsh's `terminfo` module. Is
that wrong? Going by the discussion cited above, it would seem so. And it's
supported by the observation that the likes of `vim` respond to Home and End
in all the above-mentioned terminals, `tmux` translates them correctly, but
they don't work with the bindings set up by `/etc/zshrc`. `bash` works too.

So I think the conclusion is to bind the `xterm+noapp` sequences. Congrats
to [this person](https://jdhao.github.io/2019/06/13/zsh_bind_keys/), they
got it right.

### 4. Don't configure your terminal to send TTY sequences.

It may look like `tmux` wants that, and it does, but the first thing
mentioned by [`tmux`'s FAQ](https://github.com/tmux/tmux/wiki/FAQ) is that
you should ensure `$TERM` is set correctly before starting it. It seems
strongly implied that there's some `terminfo` translation happening.

### 5. How to see what's going on

- See what the terminal is sending with:

  ```
  echo -n '^V{keypress}' | xxd
  ```

  For `^V`, literally press <kbd>Ctrl</kbd><kbd>V</kbd>. For `{keypress}`,
  press the actual key you want to investigate.

- See what `terminfo` thinks:

  ```
  tput {capname} | xxd
  ```

- Or get a list of them with

  ```
  infocmp -1
  ```

  The `-1` lists each key-value pair on its own line for grepping.

- Check current zsh key settings
  ```
  bindkey  # list all bindings in the current keymap
  bindkey `^V{keypress}`
  bindkey -l  # list all keymap names
  bindkey -M {keymap}  # list all bindings in a named keymap
  ```
