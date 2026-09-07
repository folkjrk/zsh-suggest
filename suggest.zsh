# ─────────────────────────────────────────────────────────────
# suggestions — ZERO tokens, ZERO network. Pure zsh.
#
#   type            ghost text from history · accept with → or Ctrl+Space
#   ↑ / ↓           search history filtered by what you already typed
#   Ctrl+R          fuzzy search the whole history
#   Ctrl+T          fuzzy find a file · Alt+C fuzzy cd
#   Tab             completion menu, arrow-key selectable, case-insensitive
# ─────────────────────────────────────────────────────────────

# ── 0. Safety — never source a file that someone else could have written ──
# zsh already refuses to load completions from group/world-writable directories
# (that is the "compinit: insecure directories" warning). Sourcing a plugin runs
# arbitrary code in every new shell, so it deserves at least the same check.
# Homebrew prefixes are owned by the admin group and have been shipped
# group-writable in the past, which is exactly the case this guards against.
zmodload -F zsh/stat b:zstat

# True when the path is missing, or when it (or a directory on the way to it)
# is group- or world-writable. Fails closed: anything we cannot stat is unsafe.
_suggest_unsafe() {
  local p
  local -a st
  for p in $1 ${1:h} ${${1:A}:h}; do
    # -A avoids the subshell a $(zstat ...) would fork on every startup
    zstat -A st +mode $p 2>/dev/null || return 0
    # 8#22 = octal 022 (group/other write). zsh does not read a leading 0 as octal.
    (( st[1] & 8#22 )) && return 0
  done
  return 1
}

# source, but only from a trusted location
_suggest_source() {
  if _suggest_unsafe $1; then
    print -u2 "suggest: refusing to source $1 (group/world-writable)"
    print -u2 "suggest: fix with: chmod go-w ${1:h}"
    return 1
  fi
  source $1
}

# ── 1. Locate plugins across Homebrew (Intel/ARM), Linux distros, manual clones ──
# Prints the first readable candidate. Static paths only — no `brew --prefix`
# subprocess, which would add ~100ms to every shell start.
_suggest_find() {
  local name=$1 p
  for p in \
    /opt/homebrew/share/$name/$name.zsh \
    /usr/local/share/$name/$name.zsh \
    /usr/share/zsh/plugins/$name/$name.zsh \
    /usr/share/$name/$name.zsh \
    ${ZDOTDIR:-$HOME}/.zsh/$name/$name.zsh
  do
    [[ -r $p ]] && { print -r -- $p; return 0 }
  done
  return 1
}

# ── 2. History — suggestions are only as good as what's recorded ──
HISTFILE=${HISTFILE:-$HOME/.zsh_history}
HISTSIZE=200000
SAVEHIST=200000
setopt SHARE_HISTORY          # every tab/pane sees the same history instantly
setopt INC_APPEND_HISTORY     # write on execute, not on shell exit
setopt EXTENDED_HISTORY       # record timestamp and duration
setopt HIST_IGNORE_ALL_DUPS   # keep only the most recent copy of a repeated command
setopt HIST_IGNORE_SPACE      # a leading space keeps it out of history (tokens, passwords)
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY            # history expansion loads the line for review, doesn't run it

# ── 3. Completion — Tab opens a selectable menu ──
for _d in /opt/homebrew/share/zsh-completions /usr/local/share/zsh-completions; do
  # skipping unsafe dirs here keeps compinit from refusing the whole fpath later
  [[ -d $_d ]] && ! _suggest_unsafe $_d && fpath=($_d $fpath)
done
unset _d
autoload -Uz compinit
zmodload zsh/datetime
# Rebuild the completion dump once a day; skip the scan otherwise (-C) for fast startup
_zdump="${ZDOTDIR:-$HOME}/.zcompdump"
if [[ -f $_zdump ]] && (( $(zstat +mtime $_zdump) > EPOCHSECONDS - 86400 )); then
  compinit -C -d "$_zdump"
else
  compinit -d "$_zdump"
fi
unset _zdump

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' menu select                      # navigate matches with arrows
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}%d%f'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.cache/zsh/compcache"
setopt AUTO_MENU ALWAYS_TO_END COMPLETE_IN_WORD
unsetopt MENU_COMPLETE

# ── 4. Inline ghost text from history — the core Warp autosuggest behaviour ──
if _autosuggest=$(_suggest_find zsh-autosuggestions); then
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
  ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=60      # don't recompute on very long lines
  # Only bind the widgets if the plugin actually loaded, otherwise bindkey
  # would fail on a widget that does not exist.
  if _suggest_source $_autosuggest; then
    bindkey '^ '  autosuggest-accept      # Ctrl+Space accepts the whole line (→ works too)
    bindkey '^@'  autosuggest-accept      # same key, other terminal encoding
    bindkey '^[f' forward-word            # Alt+→ accepts one word at a time
  fi
fi
unset _autosuggest

# ── 5. ↑/↓ search history by the prefix already on the line ──
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search    # ↑
bindkey '^[[B' down-line-or-beginning-search  # ↓
bindkey '^P'   up-line-or-beginning-search
bindkey '^N'   down-line-or-beginning-search

# ── 6. fzf — Ctrl+R history, Ctrl+T files, Alt+C cd ──
if command -v fzf >/dev/null; then
  export FZF_DEFAULT_OPTS='--height 45% --layout=reverse --border --info=inline'
  export FZF_CTRL_R_OPTS='--reverse --prompt="history ❯ "'
  # `fzf --zsh` needs fzf >= 0.48; older builds ship key-bindings.zsh instead.
  # Cache its output — spawning fzf on every shell start costs ~19ms, sourcing
  # the cached file costs ~2ms. Regenerated whenever the fzf binary is newer.
  _fzf_cache="$HOME/.cache/zsh/fzf-init.zsh"
  if fzf --zsh >/dev/null 2>&1; then
    if [[ ! -s $_fzf_cache || $commands[fzf] -nt $_fzf_cache ]]; then
      # Write to a temp file and rename, so an interrupted run can never leave a
      # half-written cache behind for this (or a concurrently starting) shell to
      # source. A plain `>` truncates first and is not atomic.
      if mkdir -p "${_fzf_cache:h}" 2>/dev/null; then
        _tmp=$_fzf_cache.$$
        if fzf --zsh > $_tmp 2>/dev/null && [[ -s $_tmp ]]; then
          mv -f $_tmp $_fzf_cache
        else
          rm -f $_tmp
        fi
        unset _tmp
      fi
    fi
    [[ -s $_fzf_cache ]] && _suggest_source "$_fzf_cache"
  else
    for _d in /opt/homebrew/opt/fzf/shell /usr/local/opt/fzf/shell /usr/share/fzf /usr/share/doc/fzf/examples; do
      [[ -r $_d/key-bindings.zsh ]] && { _suggest_source $_d/key-bindings.zsh; _suggest_source $_d/completion.zsh 2>/dev/null; break }
    done
    unset _d
  fi
  unset _fzf_cache
fi

# ── 7. Syntax highlighting — must be sourced last ──
if _highlight=$(_suggest_find zsh-syntax-highlighting); then
  _suggest_source $_highlight
fi
unset _highlight
