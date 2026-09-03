# zsh-suggest

Warp-style command suggestions for any terminal — **zero tokens, zero network, zero telemetry.**

One `.zsh` file. Ghost-text completions from your own shell history, prefix-filtered history
navigation, fuzzy search, and a proper completion menu. No AI, no API key, no subscription,
no daemon. Just zsh doing what zsh already can.

Works in **Orca, Ghostty, iTerm2, Alacritty, kitty, WezTerm, tmux, VS Code** — anywhere zsh runs.

```
$ git ch▊eckout -b feature/                    ← grey text is a suggestion from your history
                                                  press → to accept it
```

---

## Why

Modern AI terminals (Warp, and the AI layers people bolt onto others) put a language model in
front of your prompt. That is genuinely useful when you cannot remember a command — but it is
the wrong tool for the ~90% case, where you are retyping something you already ran last Tuesday.

Measured on the AI path, one "suggest me a command" round trip cost **~19,000 input tokens,
1.4 s, and about $0.008** — to produce `du -h ~/Downloads/* | sort -rh | head -5`. A command
already sitting in the history file.

This config covers that 90% with pure zsh:

| | AI suggestion | zsh-suggest |
|---|---|---|
| Latency | 1.4 – 9 s | **~0 ms** (local) |
| Cost per use | ~$0.008 | **$0** |
| Works offline | no | **yes** |
| Sends your commands off-box | yes | **never** |
| Knows *your* flags, hosts, paths | no | **yes — that's the whole point** |

It will not invent a command you have never run. That's the trade. Keep an AI tool around for
that case if you want one; this handles everything else instantly and for free.

---

## Features

### Inline ghost text
As you type, the rest of the most recent matching command appears in grey. `→` accepts the
whole thing, `Alt+→` takes one word. Falls back to completion-based suggestions when history
has no match.

### Prefix-filtered history on ↑ / ↓
Type `docker ` then press `↑` and you cycle **only** through your `docker` commands — not the
raw chronological list. This is the single highest-value binding in the file.

### Fuzzy everything (fzf)
`Ctrl+R` searches the entire history fuzzily. `Ctrl+T` inserts a file path, `Alt+C` jumps to a
directory.

### A completion menu that behaves
`Tab` opens an arrow-navigable, colourised menu. Matching is case-insensitive and mid-word:
`cd dow`+`Tab` → `Downloads`, `git com`+`Tab` → `commit`. Ships with `zsh-completions` on
`fpath` for a few hundred extra command definitions.

### Syntax highlighting
Commands that don't exist go red **before** you hit Enter. Unclosed quotes and bad paths are
visible while typing.

### History worth suggesting from
200k entries, deduplicated, written on execute (not on exit), and **shared live across every
tab, pane and split**. Open a new pane and it already knows what you typed in the other one —
which matters a lot in worktree-per-agent setups like Orca's.

---

## Requirements

- **zsh 5.3+** (macOS ships 5.9; `zsh --version` to check)
- `zsh-autosuggestions`, `zsh-syntax-highlighting` — required for ghost text and colouring
- `fzf` ≥ 0.48, `zsh-completions` — optional; the config degrades gracefully without them

Every dependency is probed at load time. Missing ones are skipped silently, so a partial
install still works.

---

## Install

### macOS (Homebrew)

```sh
brew install zsh-autosuggestions zsh-syntax-highlighting fzf zsh-completions

git clone https://github.com/folkjrk/zsh-suggest.git ~/.config/zsh-suggest
echo '[[ -r ~/.config/zsh-suggest/suggest.zsh ]] && source ~/.config/zsh-suggest/suggest.zsh' >> ~/.zshrc

exec zsh
```

Both Homebrew prefixes are detected — `/opt/homebrew` (Apple Silicon) and `/usr/local` (Intel).

If zsh warns about *"insecure directories"* on first run:

```sh
chmod go-w "$(brew --prefix)/share" "$(brew --prefix)/share/zsh" "$(brew --prefix)/share/zsh/site-functions"
```

### Debian / Ubuntu

```sh
sudo apt install zsh-autosuggestions zsh-syntax-highlighting fzf

git clone https://github.com/folkjrk/zsh-suggest.git ~/.config/zsh-suggest
echo '[[ -r ~/.config/zsh-suggest/suggest.zsh ]] && source ~/.config/zsh-suggest/suggest.zsh' >> ~/.zshrc

exec zsh
```

### Arch

```sh
sudo pacman -S zsh-autosuggestions zsh-syntax-highlighting fzf zsh-completions
```

then clone and source as above.

### No package manager

```sh
mkdir -p ~/.zsh
git clone https://github.com/zsh-users/zsh-autosuggestions     ~/.zsh/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting
```

`~/.zsh/<name>/<name>.zsh` is one of the paths probed, so this is picked up with no edits.

> **Load order matters.** Source `suggest.zsh` at the **end** of `~/.zshrc`, after any framework
> (oh-my-zsh, prezto) and after your prompt. Syntax highlighting must be the last thing to hook
> ZLE or it will not colour anything.

---

## Usage

| Key | Does |
|---|---|
| `→` | accept the whole ghost-text suggestion |
| `Ctrl+Space` | same — for when `→` is taken by something else |
| `Alt+→` | accept one word of the suggestion |
| `↑` / `↓` | history search filtered by the prefix already typed |
| `Ctrl+P` / `Ctrl+N` | same, for emacs hands |
| `Ctrl+R` | fuzzy search all history |
| `Ctrl+T` | fuzzy-pick a file, insert its path |
| `Alt+C` | fuzzy-pick a directory and `cd` into it |
| `Tab` | completion menu — arrows to navigate, Enter to pick |
| `Ctrl+U` | clear the line |

### Keeping secrets out of history

Start any command with a **leading space** and it is never written to the history file:

```sh
$  export API_KEY=sk-...      # note the extra space — not recorded, not suggested later
```

### Getting good suggestions

Suggestions are drawn from history, so quality builds over days, not minutes. A fresh install
feels empty; after a week of normal work it will finish most of what you type. Nothing to train
or configure.

---

## Performance

Measured on macOS, zsh 5.9, cold shell, 5 runs:

| | Time |
|---|---|
| Total shell startup | **~50 ms** |
| `suggest.zsh` share of that | **~36 ms** |

Component breakdown:

| Component | Cost |
|---|---|
| `fzf` init | 2 ms *(cached; 19 ms uncached)* |
| `compinit` | 9 ms *(cached; ~200 ms uncached)* |
| syntax highlighting | 5 ms |
| autosuggestions | 1 ms |
| history + zstyle setup | ~19 ms |

Two caches do the heavy lifting:

- **`compinit`** runs its full security scan once a day; other startups use `-C` to skip it.
- **`fzf --zsh`** output is cached to `~/.cache/zsh/fzf-init.zsh` and regenerated only when the
  `fzf` binary is newer than the cache. Saves ~17 ms per shell.

Both caches are self-healing — delete them and they rebuild on next start.

At runtime the only per-keystroke work is the autosuggestion lookup, capped by
`ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=60` so long lines don't cause lag.

---

## Configuration

Everything is plain variables — override **after** sourcing, in `~/.zshrc`:

```sh
source ~/.config/zsh-suggest/suggest.zsh

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'   # brighter ghost text on dark themes
HISTSIZE=50000                             # smaller history
export FZF_DEFAULT_OPTS='--height 80%'     # taller fzf window
```

**Turn off a section:** the file is six clearly numbered blocks. Delete or comment one out;
nothing depends on anything else except syntax highlighting needing to stay last.

**Suggest from history only** (skip the completion fallback, marginally faster):

```sh
ZSH_AUTOSUGGEST_STRATEGY=(history)
```

---

## Troubleshooting

**No ghost text.** The plugin wasn't found. Check the probe:
```sh
ls /opt/homebrew/share/zsh-autosuggestions /usr/local/share/zsh-autosuggestions 2>/dev/null
```

**Nothing is coloured.** Something else hooked ZLE after this file. Move the `source` line to
the very end of `~/.zshrc`.

**`Ctrl+Space` does nothing.** Some terminals don't send it. `→` always works; or rebind:
```sh
bindkey '^E' autosuggest-accept
```

**`↑` stopped going through all history.** Working as designed — it now filters by what's on
the line. Clear the line first (`Ctrl+U`), or use `Ctrl+R`.

**Slow startup.** Time it: `for i in 1 2 3; do /usr/bin/time -p zsh -ic exit; done`. If it's
well over 100 ms, something else in `.zshrc` is the cause — nvm and rbenv are the usual
suspects.

---

## Uninstall

```sh
# remove the source line from ~/.zshrc, then:
rm -rf ~/.config/zsh-suggest ~/.cache/zsh
exec zsh
```

Your history file is untouched.

---

## Credits

Thin configuration layer over
[zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions),
[zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting),
[zsh-completions](https://github.com/zsh-users/zsh-completions) and
[fzf](https://github.com/junegunn/fzf). All credit to those projects.

## License

MIT
