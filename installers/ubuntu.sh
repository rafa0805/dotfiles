# shellcheck shell=bash
# Ubuntu 固有の準備。install.sh から source され、os_setup が呼ばれる。
# ここには「Ubuntu でしか意味がない処理」だけを書く。

# Homebrew の前提 + ログインシェル用の zsh
APT_PACKAGES=(
  build-essential
  procps
  curl
  file
  git
  zsh
)

os_setup() {
  info "apt で土台のパッケージを入れます"
  sudo apt-get update -y
  sudo apt-get install -y "${APT_PACKAGES[@]}"
}

os_defaults() {
  :
}
