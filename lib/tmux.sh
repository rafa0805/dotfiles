# shellcheck shell=bash

install_tmux_plugin() {
  if command -v tmux >/dev/null 2>&1; then
     info "tpmプラグインをインストール"
    TPM_REPO_DIR=$HOME/.tmux/plugins/tpm
    if [ -d "$TPM_REPO_DIR" ]; then
      git -C "$TPM_REPO_DIR" pull origin master
    else
      git clone https://github.com/tmux-plugins/tpm "$TPM_REPO_DIR"
    fi

    "$TPM_REPO_DIR/bin/install_plugins"

  else
     info "tmuxコマンドがないのでtmpプラグインのインストールをスキップ"
  fi
}
