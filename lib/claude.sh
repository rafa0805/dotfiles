# shellcheck shell=bash

install_claude_code() {
  if command -v claude >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/claude" ]]; then
    return
  fi
  info "Claude Code をインストールします"
  curl -fsSL https://claude.ai/install.sh | bash
}
