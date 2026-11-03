# 対話シェルで読まれる設定。プラグインマネージャなしの素の zsh。
# ツールが無い環境でもエラーにならないよう、外部コマンドは存在チェックしてから使う。

# ---------------------------------------------------------------- 履歴
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt share_history        # 複数ターミナルで履歴を共有
setopt hist_ignore_all_dups # 重複を残さない
setopt hist_ignore_space    # 先頭スペースのコマンドは残さない
setopt hist_reduce_blanks

# ---------------------------------------------------------------- 基本
setopt auto_cd              # ディレクトリ名だけで cd
setopt auto_pushd pushd_ignore_dups
setopt interactive_comments
setopt no_beep
bindkey -e                  # emacs キーバインド
bindkey \^U backward-kill-line # Ctrl+Uはカーソル以降を削除 (bash like)

# ---------------------------------------------------------------- 補完
if command -v brew >/dev/null 2>&1; then
  fpath=("$(brew --prefix)/share/zsh/site-functions" $fpath)
fi
autoload -Uz compinit && compinit -d "$HOME/.zcompdump"
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'  # 大文字小文字を区別しない
zstyle ':completion:*' menu select

# ---------------------------------------------------------------- プロンプト
# starship があれば使う（設定は ~/.config/starship.toml）。
# 無い環境では vcs_info による素のプロンプトにフォールバック。
# 例: ~/dotfiles (main) %
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
else
  autoload -Uz vcs_info
  zstyle ':vcs_info:git:*' formats ' (%b)'
  precmd() { vcs_info }
  setopt prompt_subst
  PROMPT='%F{cyan}%~%f%F{yellow}${vcs_info_msg_0_}%f %(?.%#.%F{red}%#%f) '
fi

# ---------------------------------------------------------------- エイリアス
# eza があれば ls / ll / lt に使う（元の ls は `command ls` か `\ls` で呼べる）。
# 無い環境では色付きの素の ls にフォールバック。
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons=auto --group-directories-first'
  alias ll='eza -lha --git --icons=auto --group-directories-first' # -a でドットファイルも表示（. と .. は出ない）
  alias lt='eza --tree --level=2 --icons=auto --group-directories-first'
else
  case "$OSTYPE" in
    darwin*) alias ls='ls -G' ;;
    *)       alias ls='ls --color=auto' ;;
  esac
  alias ll='ls -lhA'
fi
alias ..='cd ..'
alias g='git'
alias lg='lazygit'

command -v bat >/dev/null 2>&1 && alias cat='bat --paging=never --style=plain'

# ---------------------------------------------------------------- 関数
# diffを綺麗に表示（delta が無ければ diff -u のまま表示）
pdiff() {
  if (( $# != 2 )); then
    print -u2 "usage: pdiff <file1> <file2>"
    return 2
  fi
  if command -v delta >/dev/null 2>&1; then
    diff -u -- "$1" "$2" | delta
  else
    diff -u -- "$1" "$2"
  fi
}

# ---------------------------------------------------------------- mise
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# ---------------------------------------------------------------- fzf
# Ctrl-R: 履歴検索 / Ctrl-T: ファイル検索
if command -v fzf >/dev/null 2>&1; then
  # see: https://github.com/junegunn/fzf#setting-up-shell-integration
  source <(fzf --zsh) 2>/dev/null
fi

# ---------------------------------------------------------------- WSL
if command -v wslview >/dev/null 2>&1; then
  export BROWSER=wslview
fi

# ---------------------------------------------------------------- zoxide
# z <キーワード>: よく使うディレクトリへ移動 / zi: fzf で対話的に選んで移動
# zoxide は compinit やプロンプトのフック設定より後（設定の最後）で初期化する。
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# ---------------------------------------------------------------- マシン固有
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
