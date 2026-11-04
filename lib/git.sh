# shellcheck shell=bash

# ~/.gitconfig の [hook "betterleaks"]（config の hook）は git 2.54 以上でないと
# 黙って無視され、シークレットのスキャンが走らない。古い git があれば警告だけ出す。
# PATH の git（通常は brew）に加え、GUI ツールなどが使うことのある /usr/bin/git も見る。
check_git_hook_support() {
  local git_bin version major minor seen=""
  for git_bin in "$(command -v git 2>/dev/null)" /usr/bin/git; do
    [[ -x "$git_bin" && " $seen " != *" $git_bin "* ]] || continue
    seen="$seen $git_bin"
    version="$("$git_bin" --version 2>/dev/null)" || continue
    # 例: "git version 2.56.0" / "git version 2.39.5 (Apple Git-154)"
    [[ "$version" =~ ([0-9]+)\.([0-9]+) ]] || continue
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    if (( major < 2 || (major == 2 && minor < 54) )); then
      warn "$git_bin は $major.$minor なので betterleaks のコミット前チェックが動きません（git 2.54 以上が必要）"
    fi
  done
  return 0
}
