# shellcheck shell=bash

brew_bin() {
  local p
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    [[ -x "$p" ]] && { echo "$p"; return; }
  done
  command -v brew 2>/dev/null || true
}

install_brew() {
  if [[ -z "$(brew_bin)" ]]; then
    info "Homebrew をインストールします"
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$("$(brew_bin)" shellenv)"
}

brew_bundle() {
  info "Brewfile のツールを入れます"
  brew bundle --file="$DOTFILES_DIR/Brewfile"
}
