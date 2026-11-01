# shellcheck shell=bash
# macOS 固有の準備。install.sh から source され、os_setup が呼ばれる。
# ここには「macOS でしか意味がない処理」だけを書く。

os_setup() {
  # Xcode Command Line Tools（git・コンパイラを含む。Homebrew の前提）
  if ! xcode-select -p >/dev/null 2>&1; then
    info "Xcode Command Line Tools をインストールします（ダイアログが出ます）"
    xcode-select --install || true
    die "インストール完了後にもう一度 ./install.sh を実行してください"
  fi

  # zsh は macOS 標準（/bin/zsh）なので何もしない
}

# macOS の設定（defaults write）はここに足していく。例:
#   defaults write NSGlobalDomain KeyRepeat -int 2
#   defaults write com.apple.finder AppleShowAllFiles -bool true
os_defaults() {
  :
}
