Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$RepoRaw = "https://raw.githubusercontent.com/felipescoutfx/darkwood-coop-launcher/main"
$ConfigDir = Join-Path $env:APPDATA "DarkwoodCoopLauncher"
$ConfigFile = Join-Path $ConfigDir "config.json"
New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null

function Load-Config {
    if (Test-Path $ConfigFile) {
        try { return Get-Content $ConfigFile -Raw | ConvertFrom-Json } catch {}
    }
    return [PSCustomObject]@{ PeerSteamId64 = "76561197998667577"; DarkwoodPath = "" }
}

function Save-Config($cfg) {
    $cfg | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8
}

function Find-DarkwoodPath {
    $candidates = @(
        "C:\Program Files (x86)\Steam\steamapps\common\Darkwood",
        "C:\Program Files\Steam\steamapps\common\Darkwood"
    )
    foreach ($c in $candidates) { if (Test-Path "$c\Darkwood.exe") { return $c } }

    # Procura em outras bibliotecas Steam via libraryfolders.vdf
    $lf = "C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf"
    if (Test-Path $lf) {
        $matches = Select-String -Path $lf -Pattern '"path"\s*"([^"]+)"' -AllMatches
        foreach ($m in $matches.Matches) {
            $p = $m.Groups[1].Value -replace '\\\\', '\'
            $cand = Join-Path $p "steamapps\common\Darkwood"
            if (Test-Path "$cand\Darkwood.exe") { return $cand }
        }
    }
    return ""
}

function Write-BepInExConfig($darkwoodPath, $peerId) {
    $cfgDir = Join-Path $darkwoodPath "BepInEx\config"
    New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
    $cfgPath = Join-Path $cfgDir "com.felipe.darkwoodcooponline.cfg"
    $content = @"
## Settings file was created by plugin Darkwood Co-op Online v0.1.0
## Plugin GUID: com.felipe.darkwoodcooponline

[Loopback]

# Setting type: Int32
# Default value: 7777
LocalPort = 7777

# Setting type: Int32
# Default value: 7778
RemotePort = 7778

[Steam]

# Setting type: String
# Default value: 0
PeerSteamId64 = $peerId

[Transport]

# Setting type: String
# Default value: Loopback
Mode = Steam
"@
    Set-Content -Path $cfgPath -Value $content -Encoding UTF8
}

# ---------------- UI ----------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Darkwood Co-op - Launcher"
$form.Size = New-Object System.Drawing.Size(520, 430)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$cfg = Load-Config
if ([string]::IsNullOrWhiteSpace($cfg.DarkwoodPath)) { $cfg.DarkwoodPath = Find-DarkwoodPath }

$y = 15

$lblPeer = New-Object System.Windows.Forms.Label
$lblPeer.Text = "SteamID64 do HOST (quem voce vai jogar com):"
$lblPeer.Location = New-Object System.Drawing.Point(15, $y)
$lblPeer.Size = New-Object System.Drawing.Size(480, 20)
$form.Controls.Add($lblPeer)
$y += 22

$txtPeer = New-Object System.Windows.Forms.TextBox
$txtPeer.Text = $cfg.PeerSteamId64
$txtPeer.Location = New-Object System.Drawing.Point(15, $y)
$txtPeer.Size = New-Object System.Drawing.Size(480, 24)
$form.Controls.Add($txtPeer)
$y += 34

$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Text = "Pasta do Darkwood:"
$lblPath.Location = New-Object System.Drawing.Point(15, $y)
$lblPath.Size = New-Object System.Drawing.Size(480, 20)
$form.Controls.Add($lblPath)
$y += 22

$txtPath = New-Object System.Windows.Forms.TextBox
$txtPath.Text = $cfg.DarkwoodPath
$txtPath.Location = New-Object System.Drawing.Point(15, $y)
$txtPath.Size = New-Object System.Drawing.Size(390, 24)
$form.Controls.Add($txtPath)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "..."
$browseY = $y - 1
$btnBrowse.Location = New-Object System.Drawing.Point(415, $browseY)
$btnBrowse.Size = New-Object System.Drawing.Size(80, 26)
$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dlg.ShowDialog() -eq "OK") { $txtPath.Text = $dlg.SelectedPath }
})
$form.Controls.Add($btnBrowse)
$y += 40

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Pronto."
$lblStatus.Location = New-Object System.Drawing.Point(15, $y)
$lblStatus.Size = New-Object System.Drawing.Size(480, 60)
$form.Controls.Add($lblStatus)
$y += 65

function Set-Status($msg) {
    $lblStatus.Text = $msg
    $form.Refresh()
}

function Get-DarkwoodPathOrWarn {
    $p = $txtPath.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($p) -or -not (Test-Path "$p\Darkwood.exe")) {
        [System.Windows.Forms.MessageBox]::Show("Pasta do Darkwood invalida. Escolha a pasta onde fica o Darkwood.exe.", "Erro") | Out-Null
        return $null
    }
    return $p
}

# 1) Instalar BepInEx + Mod
$btn1 = New-Object System.Windows.Forms.Button
$btn1.Text = "1) Instalar BepInEx + Mod (primeira vez)"
$btn1.Location = New-Object System.Drawing.Point(15, $y)
$btn1.Size = New-Object System.Drawing.Size(480, 34)
$btn1.Add_Click({
    $path = Get-DarkwoodPathOrWarn
    if (-not $path) { return }
    try {
        Set-Status "Baixando BepInEx..."
        $zip = Join-Path $env:TEMP "bepinex-bundle.zip"
        Invoke-WebRequest -Uri "$RepoRaw/bepinex-bundle.zip" -OutFile $zip
        Set-Status "Extraindo BepInEx..."
        Expand-Archive -Path $zip -DestinationPath $path -Force
        Set-Status "Baixando mod..."
        Invoke-WebRequest -Uri "$RepoRaw/mod/DarkwoodCoopOnline.dll" -OutFile (Join-Path $path "BepInEx\plugins\DarkwoodCoopOnline.dll")
        Write-BepInExConfig -darkwoodPath $path -peerId $txtPeer.Text.Trim()
        Set-Status "Instalado! Agora clique em 'Baixar save inicial' e depois 'Jogar'."
    } catch {
        Set-Status "Erro: $($_.Exception.Message)"
    }
})
$form.Controls.Add($btn1)
$y += 40

# 2) Baixar save inicial
$btn2 = New-Object System.Windows.Forms.Button
$btn2.Text = "2) Baixar save inicial (SOBRESCREVE seu save atual!)"
$btn2.Location = New-Object System.Drawing.Point(15, $y)
$btn2.Size = New-Object System.Drawing.Size(480, 34)
$btn2.Add_Click({
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Isso vai SUBSTITUIR seu save local do Darkwood pelo save compartilhado. Continuar?",
        "Confirmar", "YesNo", "Warning")
    if ($confirm -ne "Yes") { return }
    try {
        Set-Status "Baixando save..."
        $zip = Join-Path $env:TEMP "save-initial.zip"
        Invoke-WebRequest -Uri "$RepoRaw/save-initial.zip" -OutFile $zip
        $saveRoot = Join-Path $env:USERPROFILE "AppData\LocalLow\Acid Wizard Studio\Darkwood"
        New-Item -ItemType Directory -Force -Path $saveRoot | Out-Null
        Set-Status "Extraindo save..."
        Expand-Archive -Path $zip -DestinationPath $saveRoot -Force
        Set-Status "Save instalado."
    } catch {
        Set-Status "Erro: $($_.Exception.Message)"
    }
})
$form.Controls.Add($btn2)
$y += 40

# 3) Sincronizar mod
$btn3 = New-Object System.Windows.Forms.Button
$btn3.Text = "3) Sincronizar mod (baixar versao mais nova)"
$btn3.Location = New-Object System.Drawing.Point(15, $y)
$btn3.Size = New-Object System.Drawing.Size(480, 34)
$btn3.Add_Click({
    $path = Get-DarkwoodPathOrWarn
    if (-not $path) { return }
    try {
        Set-Status "Baixando ultima versao do mod..."
        Invoke-WebRequest -Uri "$RepoRaw/mod/DarkwoodCoopOnline.dll" -OutFile (Join-Path $path "BepInEx\plugins\DarkwoodCoopOnline.dll")
        Write-BepInExConfig -darkwoodPath $path -peerId $txtPeer.Text.Trim()
        Set-Status "Mod atualizado."
    } catch {
        Set-Status "Erro: $($_.Exception.Message)"
    }
})
$form.Controls.Add($btn3)
$y += 40

# 4) Jogar
$btn4 = New-Object System.Windows.Forms.Button
$btn4.Text = "4) Jogar (abre o Darkwood pela Steam)"
$btn4.Location = New-Object System.Drawing.Point(15, $y)
$btn4.Size = New-Object System.Drawing.Size(480, 34)
$btn4.Add_Click({
    $cfg.PeerSteamId64 = $txtPeer.Text.Trim()
    $cfg.DarkwoodPath = $txtPath.Text.Trim()
    Save-Config $cfg
    Start-Process "steam://rungameid/274520"
    Set-Status "Abrindo Steam... quando o jogo carregar o save, aperte F8 (cliente) ou F7 (host)."
})
$form.Controls.Add($btn4)
$y += 46

$lblHelp = New-Object System.Windows.Forms.Label
$lblHelp.Text = "Depois que o jogo abrir e o save carregar: aperte F8 (voce = cliente) `r`ndentro do jogo. F10 encerra a sessao."
$lblHelp.Location = New-Object System.Drawing.Point(15, $y)
$lblHelp.Size = New-Object System.Drawing.Size(480, 40)
$form.Controls.Add($lblHelp)

$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
