#!/usr/bin/env bash
# dotfiles メインインストーラー（macOS / Ubuntu）
#
#   ./install.sh            OS 別の準備 + Homebrew + Brewfile + リンク + zsh 化
#   ./install.sh --link     シンボリックリンクだけ張る（sudo 不要・どの OS でも可）
#
# 何度実行しても同じ結果になる（冪等）。
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR
# shellcheck source=lib/common.sh
source "$DOTFILES_DIR/lib/common.sh"

# macos / ubuntu / unsupported を返す。返り値が installers/<名前>.sh に対応する。
detect_os() {
  case "$(uname -s)" in
    Darwin) echo macos ;;
    Linux)
      local id
      id="$(. /etc/os-release 2>/dev/null && echo "${ID:-}")"
      case "$id" in
        ubuntu) echo ubuntu ;;
        *)      echo unsupported ;;
      esac ;;
    *) echo unsupported ;;
  esac
}

# home/ 以下のファイルを ~ に同じ相対パスでリンクする。
# 既存のファイルは ~/.dotfiles_backup/<日時>/ に退避する。
link_files() {
  local backup src rel dest
  backup="$HOME/.dotfiles_backup/$(date +%Y%m%d-%H%M%S)"
  while IFS= read -r -d '' src; do
    rel="${src#"$DOTFILES_DIR/home/"}"
    dest="$HOME/$rel"
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
      continue
    fi
    if [[ -e "$dest" || -L "$dest" ]]; then
      mkdir -p "$backup/$(dirname "$rel")"
      mv "$dest" "$backup/$rel"
      warn "既存の ~/$rel を $backup に退避しました"
    fi
    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
    info "link ~/$rel"
  done < <(find "$DOTFILES_DIR/home" -type f -print0)
  prune_dangling_links
}

# home/ から消した・名前を変えたファイルの、~ に残ったリンク切れを消す。
# 対象は「リンク切れ」かつ「リンク先が $DOTFILES_DIR/home/ 配下」のシンボリックリンクだけ。
# ~ 全体を深く走査すると遅い（node_modules や WSL の /mnt など）ので、
# ~ 直下と、home/ に今あるディレクトリに対応する ~ 側のディレクトリだけを
# それぞれ深さ 1 で見る。home/ からディレクトリごと消した場合、その中のリンクは
# 拾えない（手動で消す）が、マニフェストを持つより単純で壊れにくいのでこの方式にする。
# GNU / BSD 両方で動くよう find -xtype や readlink -f は使わない。
prune_dangling_links() {
  local dir link target
  while IFS= read -r -d '' dir; do
    dir="$HOME${dir#"$DOTFILES_DIR/home"}"
    [[ -d "$dir" && ! -L "$dir" ]] || continue
    while IFS= read -r -d '' link; do
      [[ -e "$link" ]] && continue
      target="$(readlink "$link")" || continue
      [[ "$target" == "$DOTFILES_DIR/home/"* ]] || continue
      rm "$link"
      info "リンク切れの ~${link#"$HOME"} を削除しました"
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -type l -print0)
  done < <(find "$DOTFILES_DIR/home" -type d -print0)
}

# OS 標準の zsh を使う（brew の zsh だと brew が壊れたときにログインできなくなるため）
set_login_shell() {
  local zsh_path
  for zsh_path in /bin/zsh /usr/bin/zsh; do
    [[ -x "$zsh_path" ]] && break
  done
  [[ -x "$zsh_path" ]] || { warn "OS 標準の zsh が見つかりません"; return; }
  if [[ "$(basename "${SHELL:-}")" != zsh ]]; then
    info "ログインシェルを $zsh_path に変更します"
    chsh -s "$zsh_path" || warn "chsh に失敗しました。手動で: chsh -s $zsh_path"
  fi
}

main() {
  if [[ "${1:-}" == "--link" ]]; then
    link_files
    info "リンクだけ張りました"
    return
  fi

  local os installer
  os="$(detect_os)"
  installer="$DOTFILES_DIR/installers/$os.sh"
  [[ -f "$installer" ]] || die "未対応の OS です（$os）。リンクだけなら ./install.sh --link"
  info "OS: $os"

  # OS 固有
  # shellcheck source=/dev/null
  source "$installer"
  os_setup

  # 共通
  source "$DOTFILES_DIR/lib/homebrew.sh"
  install_brew
  brew_bundle

  # 設定ファイルのシンボリックリンクを張る
  link_files

  # mise でランタイムを入れる
  source "$DOTFILES_DIR/lib/mise.sh"
  mise_install

  # claude code cliをインストール (公式推奨のインストーラー使用)
  source "$DOTFILES_DIR/lib/claude.sh"
  install_claude_code

  # tmuxプラグインをインストール
  source "$DOTFILES_DIR/lib/tmux.sh"
  install_tmux_plugin

  # ログインシェルを変更
  set_login_shell

  # OS 固有の設定（リンク後）
  os_defaults

  info "完了。新しいターミナルを開いてください"
}

main "$@"
