# shellcheck shell=bash

# ~/.gitconfig の [hook "betterleaks"]（config の hook）は git 2.54 以上でないと
# 黙って無視され、シークレットのスキャンが走らない。古ければ警告だけ出す。
# 見るのは PATH の git だけ。install_brew の後に呼ぶので brew の git になり、
# ログインシェル（.zprofile で brew shellenv）で使う git と一致する。
# /usr/bin/git（apt / Apple の git）は普段使わないうえに常に古く、
# 見ると毎回警告が出て意味がないので見ない。
check_git_hook_support() {
  local git_bin version major minor
  git_bin="$(command -v git 2>/dev/null)" || { warn "git が見つかりません"; return 0; }
  version="$("$git_bin" --version 2>/dev/null)" || return 0
  # 例: "git version 2.56.0" / "git version 2.39.5 (Apple Git-154)"
  [[ "$version" =~ ([0-9]+)\.([0-9]+) ]] || return 0
  major="${BASH_REMATCH[1]}"
  minor="${BASH_REMATCH[2]}"
  if (( major < 2 || (major == 2 && minor < 54) )); then
    warn "$git_bin は $major.$minor なので betterleaks のコミット前チェックが動きません（git 2.54 以上が必要）"
  fi
  return 0
}
