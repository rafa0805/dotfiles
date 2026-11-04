# Windows ホストのセットアップ

Windows + WSL2 で作業する PC を新しく用意するときに、Windows 側を整えるスクリプト（`setup.ps1`）。
WSL の中（Ubuntu）のセットアップは、これまで通りリポジトリ直下の `bootstrap.sh` / `install.sh` で行う。

## やること

| 内容 | 方法 |
| --- | --- |
| アプリのインストール | winget（下の一覧） |
| CapsLock を左 Ctrl にする | レジストリの `Scancode Map`（再起動後に反映） |
| WSL2 のインストール | `wsl --install --no-distribution`（再起動が必要） |
| Ubuntu のインストール | `wsl --install -d Ubuntu --no-launch` |

winget で入れるアプリ（`setup.ps1` の `$Packages`）:

| アプリ | winget ID |
| --- | --- |
| Visual Studio Code | `Microsoft.VisualStudioCode` |
| PowerToys | `Microsoft.PowerToys` |
| Google Chrome | `Google.Chrome` |
| Bitwarden | `Bitwarden.Bitwarden` |
| Claude Desktop | `Anthropic.Claude` |
| Slack | `SlackTechnologies.Slack` |

何度実行しても同じ結果になる（冪等）。インストール済みのアプリ（winget 以外で入れたものも含む）や、設定済みの項目は飛ばす。

## 前提

- Windows 11（または WSL2 に対応した Windows 10）
- 管理者権限に昇格できるアカウント（UAC の確認でパスワードを入れられればよい）
- BIOS / UEFI で仮想化（Intel VT-x / AMD-V）が有効
- winget が使える（Windows 11 には最初から入っている。無ければ Microsoft Store で「アプリ インストーラー」を更新する）

## 使い方

### 新しい PC

PowerShell を**普段のユーザーで**開いて（管理者として実行しない）、次を実行する。

```powershell
iwr -useb https://raw.githubusercontent.com/rafa0805/dotfiles/main/windows/setup.ps1 -OutFile "$env:TEMP\setup.ps1"; powershell -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\setup.ps1"
```

途中で UAC の確認が出る（CapsLock の設定と WSL のインストール）。管理者として実行しないのは、Slack などユーザー単位で入るアプリが、昇格したアカウント側に入ってしまうことがあるため。

流れ:

1. 1回目: アプリ・CapsLock → Ctrl・WSL を入れる → **再起動**
2. 2回目: 同じコマンドをもう一度実行すると、Ubuntu を入れる
3. `wsl -d Ubuntu` で Ubuntu を起動し、ユーザー名とパスワードを作る
4. Ubuntu の中で dotfiles をセットアップする

   ```sh
   curl -fsSL https://raw.githubusercontent.com/rafa0805/dotfiles/main/bootstrap.sh | bash
   ```

### 何が起きるか確認だけしたい（dry-run）

`-DryRun` を付けると、何も変更せずにやることだけ表示する。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\setup.ps1" -DryRun
```

### WSL に clone 済みの dotfiles から実行する

アプリを追加したときなどは、WSL の中から Windows の PowerShell を呼んで実行できる。

```sh
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w ~/dotfiles/windows/setup.ps1)"
```

`wslpath -w` で `\\wsl.localhost\Ubuntu\...` 形式のパスにして渡す。`-DryRun` も同じように後ろに付けられる。

## 変更するには

### アプリを追加・削除する

`setup.ps1` の `$Packages` に winget の ID を書く。ID は `winget search <名前>` で調べ、`winget show --id <ID> -e` で確認する。
一覧から消しても、インストール済みのアプリはアンインストールされない（`winget uninstall --id <ID>` で手動で消す）。

### `setup.ps1` を編集するときの注意

**UTF-8（BOM 付き）で保存する。** Windows PowerShell 5.1 は BOM の無い `.ps1` を CP932 として読むので、日本語のコメントやメッセージが文字化けしたり、構文エラーになったりする。
BOM が消えていないかは `head -c 3 windows/setup.ps1 | xxd`（`efbbbf` なら OK）で確認できる。

Windows PowerShell 5.1（新しい PC に最初から入っているもの）で動くように書く。`&&` や `??`、三項演算子など PowerShell 7 の構文は使わない。

## CapsLock → Ctrl について

左 Ctrl はそのまま残る（Ctrl が2つになる）。JIS キーボードでは「英数 / CapsLock」キーが Ctrl になる。

既に別の `Scancode Map`（ほかのツールや手作業で設定したキー配置）がある場合は、上書きせずに警告を出す。

元に戻す（管理者の PowerShell で実行して再起動する）:

```powershell
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout" /v "Scancode Map" /f
```

## トラブルシュート

### 「winget が見つかりません」と出る

Microsoft Store で「アプリ インストーラー」を更新する。新しい PC では、最初のサインインからしばらくすると自動で使えるようになることもある。

### WSL や Ubuntu のインストールに失敗する

- BIOS / UEFI で仮想化が有効か確認する（タスク マネージャー → パフォーマンス → CPU の「仮想化」が「有効」）
- 1回目のあとに再起動したか確認する（再起動しないと Ubuntu は入れられない）

### CapsLock が Ctrl にならない

再起動するまで反映されない（サインアウトだけでは反映されない）。
