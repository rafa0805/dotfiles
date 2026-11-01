#!/usr/bin/env bash
# 新しいマシン用の入口。git が無い状態から 1 行でセットアップする:
#
#   curl -fsSL https://raw.githubusercontent.com/rafa0805/dotfiles/main/bootstrap.sh | bash
#
# 1. git が無ければ入れる  2. ~/dotfiles に clone（あれば pull）  3. install.sh を実行
#
# 前提:
# - bash が使える
# - curl が使える
# - sudo が使える（Linux の場合）
# - DOTFILES_REPO のリポジトリが公開されている（非公開だと clone できない）
# - DOTFILES_REPO のリポジトリに install.sh がある（無いとエラーになる）
#
# 環境変数で上書きできる:
#   DOTFILES_REPO  clone 元（既定は下の URL）
#   DOTFILES_DIR   clone 先（既定は ~/dotfiles）
set -euo pipefail

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/rafa0805/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

ensure_git() {
  case "$(uname -s)" in
    Darwin)
      # /usr/bin/git は CLT 未導入だとインストール画面を出すだけのダミーなので、
      # git の有無ではなく CLT が入っているかで判定する
      xcode-select -p >/dev/null 2>&1 && return
      info "Xcode Command Line Tools をインストールします（ダイアログで「インストール」を押してください）"
      xcode-select --install >/dev/null 2>&1 || true
      until xcode-select -p >/dev/null 2>&1; do sleep 5; done
      info "Xcode Command Line Tools のインストールが終わりました" ;;
    Linux)
      command -v git >/dev/null 2>&1 && return
      command -v apt-get >/dev/null 2>&1 || die "apt-get がありません（Ubuntu のみ対応）"
      info "git をインストールします"
      sudo apt-get update -y
      sudo apt-get install -y git ;;
    *) die "未対応の OS です: $(uname -s)" ;;
  esac
}

fetch_dotfiles() {
  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    info "$DOTFILES_DIR を更新します"
    git -C "$DOTFILES_DIR" pull --ff-only
  elif [[ -e "$DOTFILES_DIR" ]]; then
    die "$DOTFILES_DIR が既にあります（git リポジトリではありません）"
  else
    info "$DOTFILES_REPO を $DOTFILES_DIR に clone します"
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  fi
}

main() {
  ensure_git
  fetch_dotfiles
  # curl | bash だと標準入力がスクリプト本体なので、端末につなぎ直して実行する
  # （/dev/tty は存在しても端末が無いと開けないので、実際に開けるかで判定する）
  if { : </dev/tty; } 2>/dev/null; then
    "$DOTFILES_DIR/install.sh" "$@" </dev/tty
  else
    "$DOTFILES_DIR/install.sh" "$@"
  fi
}

# 関数で包んでから最後に呼ぶ: ダウンロードが途中で切れても中途半端に実行されない
main "$@"
