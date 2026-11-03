# shellcheck shell=bash

# tpm の clone / 更新とプラグインのインストール。
# 失敗してもインストール全体は止めず、警告だけ出して続行する。
install_tmux_plugin() {
  if ! command -v tmux >/dev/null 2>&1; then
    info "tmuxコマンドがないのでtpmプラグインのインストールをスキップ"
    return 0
  fi

  info "tpmプラグインをインストール"
  local TPM_REPO_DIR="$HOME/.tmux/plugins/tpm"
  if [ -d "$TPM_REPO_DIR" ]; then
    if ! git -C "$TPM_REPO_DIR" pull --ff-only; then
      warn "tpm の更新に失敗したので既存の tpm のまま続行（$TPM_REPO_DIR を確認）"
    fi
  else
    if ! git clone https://github.com/tmux-plugins/tpm "$TPM_REPO_DIR"; then
      warn "tpm の clone に失敗したのでプラグインのインストールをスキップ（./install.sh を再実行してください）"
      return 0
    fi
  fi

  if ! "$TPM_REPO_DIR/bin/install_plugins"; then
    warn "tmux プラグインのインストールに失敗（手動で tmux 内で prefix I を押してください）"
  fi
  return 0
}
