# shellcheck shell=bash

# ~/.config/mise/config.toml に書いたランタイムを入れる。リンクを張った後に呼ぶこと。
mise_install() {
  command -v mise >/dev/null 2>&1 || { warn "mise が見つかりません（Brewfile を確認）"; return; }
  info "mise でランタイムを入れます"
  mise install --yes
}
