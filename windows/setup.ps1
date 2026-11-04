<#
Windows ホストのセットアップ（アプリ・CapsLock → Ctrl・WSL2 + Ubuntu）

  新しい PC（PowerShell で実行）:
    iwr -useb https://raw.githubusercontent.com/rafa0805/dotfiles/main/windows/setup.ps1 -OutFile "$env:TEMP\setup.ps1"; powershell -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\setup.ps1"

  dry-run（何も変更せず、やることだけ表示する）:
    powershell -NoProfile -ExecutionPolicy Bypass -File setup.ps1 -DryRun

何度実行しても同じ結果になる（冪等）。WSL を入れたときは再起動が必要なので、
再起動後にもう一度実行すると Ubuntu のインストールに進む。

普段のユーザーで実行する（管理者で実行しない）。管理者権限が要る処理だけ UAC の確認が出る。
管理者で実行すると、Slack などユーザー単位で入るアプリが別アカウントに入ることがあるため。

Windows PowerShell 5.1 は BOM なしの UTF-8 を CP932 として読むので、このファイルは UTF-8（BOM 付き）で保存する。
#>
[CmdletBinding()]
param(
  [switch]$DryRun
)

Set-StrictMode -Version 2.0

# winget で入れるアプリ。ID は `winget search <名前>` で調べる
$Packages = @(
  'Microsoft.VisualStudioCode'
  'Microsoft.PowerToys'
  'Google.Chrome'
  'Bitwarden.Bitwarden'
  'Anthropic.Claude'
  'SlackTechnologies.Slack'
)

$Distro = 'Ubuntu'
$BootstrapUrl = 'https://raw.githubusercontent.com/rafa0805/dotfiles/main/bootstrap.sh'

# CapsLock（スキャンコード 0x3A）を左 Ctrl（0x1D）にする Scancode Map。
# [バージョン 4 バイト][フラグ 4 バイト][エントリ数 + 終端 = 2][1D 00 3A 00: 3A を 1D として扱う][終端 4 バイト]
# OS レベルの設定なので、どのアプリでも（管理者のウィンドウやログイン画面でも）効く。反映には再起動が必要
$KeyboardLayoutKey = 'HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout'
$ScancodeMap = [byte[]](0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0x1D, 0, 0x3A, 0, 0, 0, 0, 0)

$script:Failed = @()
$script:RebootForWsl = $false
$script:RebootForKeys = $false

function Info([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }
function Warn([string]$Message) { Write-Host "WARN: $Message" -ForegroundColor Yellow }

function Test-Admin {
  $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-Packages {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Warn 'winget が見つかりません。Microsoft Store で「アプリ インストーラー」を更新してから再実行してください'
    $script:Failed += 'winget'
    return
  }
  foreach ($id in $Packages) {
    # winget 以外の方法で入れたアプリも、インストール済みとして見つかる
    winget list --id $id --exact --accept-source-agreements *> $null
    if ($LASTEXITCODE -eq 0) {
      Info "$id はインストール済みです"
      continue
    }
    if ($DryRun) {
      Info "[dry-run] winget install $id"
      continue
    }
    Info "$id をインストールします"
    winget install --id $id --exact --source winget --accept-source-agreements --accept-package-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
      Warn "$id のインストールに失敗しました（exit $LASTEXITCODE）"
      $script:Failed += $id
    }
  }
}

function Set-CapsLockToCtrl {
  $prop = Get-ItemProperty -Path "Registry::$KeyboardLayoutKey" -Name 'Scancode Map' -ErrorAction SilentlyContinue
  if ($prop) {
    $current = [byte[]]$prop.'Scancode Map'
    if (($current -join ',') -eq ($ScancodeMap -join ',')) {
      Info 'CapsLock は Ctrl に設定済みです'
    } else {
      # ほかのツールや手作業で設定したキー配置を消さないよう、上書きしない
      Warn '別のキー配置（Scancode Map）が既にあるので、CapsLock → Ctrl は設定しませんでした'
      $script:Failed += 'CapsLock → Ctrl'
    }
    return
  }
  if ($DryRun) {
    Info '[dry-run] CapsLock を Ctrl にする（Scancode Map を書き込む）'
    return
  }

  Info 'CapsLock を Ctrl にします（UAC の確認が出ます）'
  $hex = ($ScancodeMap | ForEach-Object { $_.ToString('x2') }) -join ''
  $regArgs = "add `"$KeyboardLayoutKey`" /v `"Scancode Map`" /t REG_BINARY /d $hex /f"
  try {
    if (Test-Admin) {
      $proc = Start-Process reg.exe -ArgumentList $regArgs -Wait -PassThru -WindowStyle Hidden
    } else {
      $proc = Start-Process reg.exe -ArgumentList $regArgs -Wait -PassThru -WindowStyle Hidden -Verb RunAs
    }
  } catch {
    Warn "Scancode Map を書き込めませんでした（UAC で拒否された可能性があります）: $_"
    $script:Failed += 'CapsLock → Ctrl'
    return
  }
  if ($proc.ExitCode -ne 0) {
    Warn "Scancode Map の書き込みに失敗しました（exit $($proc.ExitCode)）"
    $script:Failed += 'CapsLock → Ctrl'
    return
  }
  $script:RebootForKeys = $true
}

function Install-Wsl {
  if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    Warn 'wsl.exe が見つかりません（WSL2 に対応していない Windows の可能性があります）'
    $script:Failed += 'WSL'
    return
  }
  # Windows に最初から入っている wsl.exe は --version を知らないので失敗する。
  # 成功すれば、新しい WSL（Microsoft Store 版）が入っている
  wsl.exe --version *> $null
  if ($LASTEXITCODE -eq 0) {
    Info 'WSL はインストール済みです'
    return
  }
  if ($DryRun) {
    Info '[dry-run] wsl --install --no-distribution'
    return
  }
  Info 'WSL をインストールします（UAC の確認が出ます）'
  wsl.exe --install --no-distribution
  if ($LASTEXITCODE -ne 0) {
    Warn "WSL のインストールに失敗しました（exit $LASTEXITCODE）"
    $script:Failed += 'WSL'
    return
  }
  # 仮想マシン プラットフォームを有効にしたので、再起動するまで Ubuntu は入れられない
  $script:RebootForWsl = $true
}

function Install-Ubuntu {
  if ($script:RebootForWsl) { return }
  if ($script:Failed -contains 'WSL') { return }
  # WSL の出力は既定で UTF-16 なので、PowerShell で文字列として扱えるよう UTF-8 にする
  $env:WSL_UTF8 = '1'
  $distros = @(wsl.exe --list --quiet 2>$null | ForEach-Object { $_.Trim() })
  if ($distros -contains $Distro) {
    Info "$Distro はインストール済みです"
    return
  }
  if ($DryRun) {
    Info "[dry-run] wsl --install -d $Distro --no-launch"
    return
  }
  # --no-launch: ここで起動するとユーザー作成のあとシェルに入ってしまうので、起動は別に行う
  Info "$Distro をインストールします"
  wsl.exe --install -d $Distro --no-launch
  if ($LASTEXITCODE -ne 0) {
    Warn "$Distro のインストールに失敗しました（exit $LASTEXITCODE）"
    $script:Failed += $Distro
  }
}

function Main {
  if ($DryRun) { Info 'dry-run: 何も変更しません' }

  Install-Packages
  Set-CapsLockToCtrl
  Install-Wsl
  Install-Ubuntu

  Write-Host ''
  if ($script:Failed.Count -gt 0) {
    Warn "失敗・スキップしたもの: $($script:Failed -join ', ')"
  }
  if ($script:RebootForKeys) { Info 'CapsLock → Ctrl は再起動後に反映されます' }
  if ($script:RebootForWsl) {
    Info '再起動してから、もう一度このスクリプトを実行してください（Ubuntu のインストールに進みます）'
  } elseif (-not $DryRun -and $script:Failed.Count -eq 0) {
    Info '次のステップ:'
    Write-Host "  1. wsl -d $Distro を実行し、Ubuntu のユーザー名とパスワードを作る"
    Write-Host "  2. Ubuntu の中で: curl -fsSL $BootstrapUrl | bash"
  }

  if ($script:Failed.Count -gt 0) { exit 1 }
}

Main
