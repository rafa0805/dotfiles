# dotfiles

macOS / Ubuntu（WSL 含む）用の個人 dotfiles。zsh・git・tmux・lazygit・mise・starship の設定と、
Homebrew で入れる CLI ツール一式をまとめてセットアップする。

## 対応 OS と前提条件

| OS                    | フルセットアップ | `--link` のみ |
| --------------------- | ---------------- | ------------- |
| macOS                 | ○                | ○             |
| Ubuntu（WSL2 を含む） | ○                | ○             |
| その他の Linux など   | ×                | ○             |

OS は `uname -s` と `/etc/os-release` の `ID` で判定する（`ID=ubuntu` のみ Ubuntu 扱い）。

前提:

- `bash` と `curl` が使える
- Ubuntu では `sudo` が使える（apt でパッケージを入れるため）
- macOS では Xcode Command Line Tools を入れられる（未導入ならインストールダイアログが出る）
- `bootstrap.sh` を使う場合、リポジトリが公開されている（非公開だと clone できない）
- アイコン表示（starship・eza・lazygit など）には Nerd Font 対応のフォントを端末に設定しておく

## セットアップ

### 新しいマシン（git が無い状態から）

```sh
curl -fsSL https://raw.githubusercontent.com/rafa0805/dotfiles/main/bootstrap.sh | bash
```

`bootstrap.sh` は次の順に処理する。

1. git を用意する
   - macOS: Xcode Command Line Tools を入れる（インストール完了まで待つ）
   - Ubuntu: `apt-get install git`
2. `~/dotfiles` に clone する（既に git リポジトリがあれば `git pull --ff-only`、git 以外のディレクトリがあればエラー）
3. `install.sh` を実行する（引数はそのまま渡される）

| 環境変数        | 既定値                                     | 内容     |
| --------------- | ------------------------------------------ | -------- |
| `DOTFILES_REPO` | `https://github.com/rafa0805/dotfiles.git` | clone 元 |
| `DOTFILES_DIR`  | `~/dotfiles`                               | clone 先 |

### clone 済みの場合

```sh
./install.sh          # フルセットアップ
./install.sh --link   # シンボリックリンクだけ張る（sudo 不要・どの OS でも可）
```

`install.sh` は冪等なので、何度実行しても同じ結果になる。フルセットアップでは次の順に処理する。

1. OS 固有の準備（`installers/<os>.sh` の `os_setup`）
   - macOS: Xcode Command Line Tools（未導入ならインストールを始めて終了するので、完了後にもう一度 `./install.sh`）
   - Ubuntu: apt で `build-essential` `procps` `curl` `file` `git` `zsh`
2. Homebrew のインストール（未導入なら）と `brew bundle`（`Brewfile`）
3. `home/` 以下を `~` にシンボリックリンク
4. `mise install` でランタイムを入れる（`~/.config/mise/config.toml`）
5. Claude Code CLI のインストール（公式インストーラー。導入済みならスキップ）
6. tmux プラグインマネージャ（tpm）の clone / 更新とプラグインのインストール
7. ログインシェルを OS 標準の zsh（`/bin/zsh` または `/usr/bin/zsh`）に変更（`chsh` でパスワードを聞かれることがある）
8. OS 固有の設定（`os_defaults`。現状は空）

既存のファイルは上書きせず `~/.dotfiles_backup/<YYYYmmdd-HHMMSS>/` に退避する（既に正しいリンクなら何もしない）。
`home/` から消した・名前を変えたファイルの古いリンク（リンク先が `home/` 配下でリンク切れのもの）は自動で削除する（`--link` でも同じ）。

終わったら新しいターミナルを開く。

## git の認証（GitHub）

`bootstrap.sh` は HTTPS で clone するので、push するには認証の設定が必要。SSH を推奨する。

`~/.gitconfig` は dotfiles の `home/.gitconfig` へのシンボリックリンクなので、`git config --global` や `gh auth setup-git` はリポジトリ管理下のファイルを書き換えてしまう。マシン固有の認証設定は `~/.gitconfig.local` に書く。

### SSH（推奨）

1. 鍵を作る（既にあれば不要）

   ```sh
   ssh-keygen -t ed25519 -C "you@example.com"
   ```

2. ssh-agent に鍵を登録する。`~/.ssh/config` は dotfiles では管理していないので各マシンで書く。

   ```
   Host github.com
     AddKeysToAgent yes
     UseKeychain yes              # macOS のみ（パスフレーズをキーチェーンに保存）
     IdentityFile ~/.ssh/id_ed25519
   ```

   macOS では `ssh-add --apple-use-keychain ~/.ssh/id_ed25519` で一度キーチェーンに登録する。Linux では `UseKeychain` の行を消す（未知のオプションでエラーになる）。

3. 公開鍵を GitHub に登録する。次のどれかで行う。
   - `gh auth login` で git のプロトコルに SSH を選ぶ（既存の鍵をアップロードするか、無ければ作成を提案される）
   - `gh ssh-key add ~/.ssh/id_ed25519.pub --title "<マシン名>"`（`admin:public_key` スコープが必要。足りなければ `gh auth refresh -h github.com -s admin:public_key`）
   - GitHub の Settings → SSH and GPG keys に `~/.ssh/id_ed25519.pub` の中身を貼る

4. 確認して、dotfiles の remote を SSH に切り替える

   ```sh
   ssh -T git@github.com    # "Hi <ユーザー名>! You've successfully authenticated" と出れば OK
   cd ~/dotfiles
   git remote set-url origin git@github.com:rafa0805/dotfiles.git
   ```

HTTPS の URL をすべて SSH に読み替えたい場合は `~/.gitconfig.local` に書く。

```
[url "git@github.com:"]
	insteadOf = https://github.com/
```

### HTTPS

`gh auth login` で git のプロトコルに HTTPS を選び、ブラウザで認証する。
「Authenticate Git with your GitHub credentials?」に Yes と答えると、`gh auth setup-git` と同じく `~/.gitconfig`（= dotfiles の `home/.gitconfig`）に brew の絶対パス入りの credential helper が書き込まれる。
OS ごとにパスが違う（`/opt/homebrew` / `/home/linuxbrew/.linuxbrew`）のでコミットしない。No と答えて、次を `~/.gitconfig.local` に書く。

```
[credential "https://github.com"]
	helper =
	helper = !gh auth git-credential
[credential "https://gist.github.com"]
	helper =
	helper = !gh auth git-credential
```

空の `helper =` は、それまでに設定された helper（osxkeychain など）をリセットして gh だけを使うためのもの。
既に `home/.gitconfig` に書き込まれてしまった場合は、そのブロックを `~/.gitconfig.local` に移す（`git -C ~/dotfiles diff` で確認できる）。

確認:

```sh
gh auth status
git config --show-origin --get-all credential.https://github.com.helper   # ~/.gitconfig.local から読まれていれば OK
```

## 構成

```
.
├── bootstrap.sh        # curl | bash 用の入口
├── install.sh          # メインインストーラー
├── Brewfile            # Homebrew で入れる CLI ツール
├── Makefile            # make brew-bundle
├── home/               # ~ にリンクされる設定ファイル
│   ├── .zshrc
│   ├── .zprofile
│   ├── .gitconfig
│   ├── .tmux.conf
│   └── .config/
│       ├── lazygit/config.yml
│       ├── mise/config.toml
│       └── starship.toml
├── installers/         # OS 固有の処理（macos.sh / ubuntu.sh）
└── lib/                # 共通の関数（common, homebrew, mise, claude, tmux）
```

## 主なツール

`Brewfile` で管理している（macOS / Ubuntu 共通）。各ツールの説明は `Brewfile` のコメントを参照。

| ツール    | 内容                                         |
| --------- | -------------------------------------------- |
| bat       | シンタックスハイライト付き cat               |
| eza       | 見やすい ls（アイコン・git 状態表示）        |
| fd        | 速くて使いやすい find                        |
| fzf       | あいまい検索                                 |
| gh        | GitHub CLI                                   |
| git       | バージョン管理                               |
| git-delta | git の差分を見やすく表示（`delta`）          |
| herdr     | ターミナルで動くエージェント用マルチプレクサ |
| jq        | JSON 処理                                    |
| lazygit   | git の TUI クライアント                      |
| mise      | 言語ランタイムのバージョン管理               |
| ripgrep   | 速い grep（`rg`）                            |
| smug      | tmux セッションを YAML で定義・起動          |
| starship  | シェルのプロンプト                           |
| tmux      | ターミナルマルチプレクサ                     |
| tree      | ディレクトリ構造をツリー表示                 |
| zoxide    | よく使うディレクトリへ素早く移動             |

mise で入れるランタイム（`home/.config/mise/config.toml`）: node（LTS）、pnpm、python、`npm:@helpfeel/cosense-cli`

## 主な設定

### zsh（`home/.zshrc` / `home/.zprofile`）

プラグインマネージャなしの素の zsh。外部コマンドは存在チェックしてから使うので、ツールが無い環境でもエラーにならない。

- 履歴: 10 万件、複数ターミナルで共有、重複・先頭スペース付きコマンドは残さない
- `auto_cd`（ディレクトリ名だけで移動）、`auto_pushd`
- emacs キーバインド。`Ctrl-U` はカーソルより前を削除（bash と同じ）
- 補完: 大文字小文字を区別しない、メニュー選択。Homebrew の補完も読む
- `.zprofile` で Homebrew の `shellenv` を読み、`~/.local/bin` を PATH に追加
- WSL で `wslview` があれば `BROWSER=wslview`

エイリアスと関数:

| 名前            | 内容                                                         |
| --------------- | ------------------------------------------------------------ |
| `cat`           | `bat --paging=never --style=plain`（bat がある場合のみ）     |
| `ls`            | `eza --icons=auto --group-directories-first`（eza が無ければ色付き ls） |
| `ll`            | `eza -lha --git`（詳細・ドットファイル込み・git 状態。eza が無ければ `ls -lhA`） |
| `lt`            | `eza --tree --level=2`（eza がある場合のみ）                 |
| `..`            | `cd ..`                                                      |
| `g`             | `git`                                                        |
| `lg`            | `lazygit`                                                    |
| `pdiff a b`     | `diff -u a b` を delta で見やすく表示                        |
| `z foo`         | zoxide: `foo` を含むよく使うディレクトリへ移動               |
| `zi`            | zoxide: 候補を fzf で対話的に選んで移動                      |

`ls` は eza に置き換わるため `ls -t` など一部のフラグは意味が異なる。元の ls は `command ls` か `\ls` で呼べる。

`z` / `zi` は zoxide がある場合のみ定義される。zoxide は移動したディレクトリを頻度と最近度で記録し、
`z foo bar` のように複数キーワードで絞り込める。`cd` 自体を置き換えたい場合は
`.zshrc` の初期化を `zoxide init zsh --cmd cd` に変える（`cd` / `cdi` になる）。

fzf のキー（`fzf --zsh` のシェル統合）:

| キー     | 内容                                   |
| -------- | -------------------------------------- |
| `Ctrl-R` | コマンド履歴をあいまい検索             |
| `Ctrl-T` | ファイルを検索してコマンドラインに挿入 |
| `Alt-C`  | ディレクトリを検索して移動             |

### プロンプト

starship があれば starship を使う（設定は `home/.config/starship.toml` → `~/.config/starship.toml`）。
設定は starship のデフォルトのまま（アイコン表示に Nerd Font が必要）。

```
dotfiles on  main [!?⇡] via  v22.11.0 took 3s
❯
```

starship が無い環境では素の zsh プロンプト（`~/dotfiles (main) %`）にフォールバックする。

### git（`home/.gitconfig`）

- エイリアス: `st`=status, `df`=diff, `co`=commit, `br`=branch, `ps`=push, `pl`=pull, `ck`=checkout
- pager と `add -p` の差分表示に delta を使う（`navigate`、dark テーマ）
- `pull.ff = only`（fast-forward できないときは失敗する）、`rebase.autostash = true`
- `init.defaultBranch = main`、`merge.conflictStyle = zdiff3`、エディタは `vi`
- `~/.gitconfig.local` を include する（マシンごとの user.email などはここに書く）

### tmux（`home/.tmux.conf`）

- prefix は `Ctrl-s`
- `prefix r` で設定を再読み込み
- `prefix h/j/k/l` でペイン移動（vim 風）
- マウス操作を有効化
- テーマは catppuccin（mocha / rounded）。ステータスラインにアプリ・CPU・セッション・稼働時間・バッテリーを表示
- プラグイン（tpm 管理）: tmux-sensible, catppuccin/tmux（v2.1.3）, tmux-cpu, tmux-battery

### lazygit（`home/.config/lazygit/config.yml`）

- アイコン表示を有効化（`gui.showIcons: true`。Nerd Font が必要）
- 差分の表示に delta を使う（`git.diffRenderers`）。`|` キーで次の表示に切り替えられる
  - delta（行番号付き。デフォルト）
  - delta の左右分割表示（`--side-by-side`）。ペインが狭いと読みにくいので必要なときだけ使う
  - git 標準の差分表示
- 端末の背景色に合わせて `--dark` / `--light` を自動で切り替える（`--{{colorScheme}}`）
- `--paging=never` で delta から less を起動させない（`~/.gitconfig` の `delta.navigate` は less 前提のため lazygit では効かない）

## 更新方法

```sh
cd ~/dotfiles
git pull
./install.sh          # すべて反映（冪等なので再実行して問題ない）
```

個別に反映する場合:

| やりたいこと                   | コマンド                                       |
| ------------------------------ | ---------------------------------------------- |
| Brewfile のツールを反映        | `make brew-bundle`                             |
| 新しい設定ファイルをリンク     | `./install.sh --link`                          |
| mise のランタイムを反映        | `mise install`                                 |
| tmux の設定を再読み込み        | tmux 内で `prefix r`                           |
| tmux プラグインを入れる / 更新 | tmux 内で `prefix I` / `prefix U`              |
| zsh の設定を反映               | `exec zsh`（または新しいターミナルを開く）     |

`home/` 以下はシンボリックリンクなので、既存ファイルの編集は `git pull` だけで反映される（シェルや tmux の再読み込みは必要）。

### ツールを追加するには

`Brewfile` に `brew "<名前>"` を追記して `make brew-bundle` を実行する。

### 設定ファイルを追加するには

`home/` 以下に `~` からの相対パスと同じ場所へファイルを置き、`./install.sh --link` を実行する。

## マシン固有の設定

git 管理したくない設定は次のファイルに書く（`*.local` は `.gitignore` 済み）。

| ファイル             | 読み込み元                     |
| -------------------- | ------------------------------ |
| `~/.zshrc.local`     | `.zshrc` の最後                |
| `~/.zprofile.local`  | `.zprofile` の最後             |
| `~/.gitconfig.local` | `.gitconfig` の `[include]`    |

## トラブルシュート

### バックアップから元のファイルに戻したい

リンク時に退避したファイルは `~/.dotfiles_backup/<日時>/` に `~` からの相対パスのまま置かれている。

```sh
ls ~/.dotfiles_backup/                       # 日時ごとのディレクトリを確認
rm ~/.zshrc                                  # dotfiles へのシンボリックリンクを消す
mv ~/.dotfiles_backup/20250101-120000/.zshrc ~/.zshrc
```

### macOS で「インストール完了後にもう一度 ./install.sh を実行してください」と出て止まる

Xcode Command Line Tools のインストールが始まった状態。ダイアログでインストールを終えてから `./install.sh` を再実行する。

### 「未対応の OS です」と出る

Ubuntu 以外の Linux などではフルセットアップできない。設定ファイルのリンクだけなら `./install.sh --link` を使う（ツールは各自で入れる）。

### ログインシェルが zsh にならない

`chsh` に失敗した場合は警告が出るので、手動で実行する。

```sh
chsh -s /bin/zsh   # OS 標準の zsh を指定する（Ubuntu では /usr/bin/zsh）
```

brew の zsh ではなく OS 標準の zsh を使うのは、brew が壊れたときにログインできなくなるのを避けるため。

### `brew` や Homebrew で入れたコマンドが見つからない

`.zprofile` で Homebrew の環境を読み込むので、ログインシェルとして起動し直す（新しいターミナルを開く、または `exec zsh -l`）。

### アイコンが文字化けする（□ や ? になる）

端末のフォントを Nerd Font 対応のものに変更する。

### tmux の見た目やプラグインが反映されない

tpm が入っていない可能性がある。`./install.sh` を再実行するか、tmux 内で `prefix I` を押す。
