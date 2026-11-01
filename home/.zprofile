# Homebrew（入っていなければ何もしない）
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  if [[ -x "$_brew" ]]; then
    eval "$("$_brew" shellenv)"
    break
  fi
done
unset _brew

# 自分用のスクリプト置き場
path=("$HOME/.local/bin" $path)
typeset -U path   # PATH の重複を除く

# マシン固有の設定（git 管理しない）
[[ -r "$HOME/.zprofile.local" ]] && source "$HOME/.zprofile.local"
