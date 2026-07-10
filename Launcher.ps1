Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepoRaw = "https://raw.githubusercontent.com/felipescoutfx/darkwood-coop-launcher/main"
$ConfigDir = Join-Path $env:APPDATA "DarkwoodCoopLauncher"
$ConfigFile = Join-Path $ConfigDir "config.json"
$SaveFetcherDir = Join-Path $ConfigDir "SaveFetcher"
New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null

# ---------- Auto-atualizacao do PROPRIO launcher (pedido do usuario, jul/2026) ----------
# Distribuido como .exe unico (compilado com PS2EXE) - sem bat, sem janela de console/
# PowerShell visivel (assusta usuario leigo). Antes de mostrar a janela principal, confere
# se ha uma versao mais nova publicada (launcher_version.txt no repo) e, se houver, baixa o
# .exe novo, troca o arquivo por um processo auxiliar OCULTO (o processo atual nao pode
# sobrescrever o proprio .exe em uso) e reabre sozinho. Falha de rede aqui NUNCA bloqueia o
# uso - so segue com a versao atual.
$LauncherVersion = "2026-07-10.1"

function Try-SelfUpdate {
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $exeName = [System.IO.Path]::GetFileNameWithoutExtension($exePath)
    # Rodando via "powershell.exe Launcher.ps1" direto (dev) em vez do .exe compilado -
    # nao ha o que auto-atualizar (nao existe .exe pra trocar).
    if ($exeName -ieq "powershell" -or $exeName -ieq "pwsh") { return }

    try {
        $latest = (Invoke-WebRequest -Uri "$RepoRaw/launcher_version.txt" -UseBasicParsing -TimeoutSec 5).Content.Trim()
    } catch { return }
    if (-not $latest -or $latest -eq $LauncherVersion) { return }

    try {
        $newExePath = "$exePath.new"
        Invoke-WebRequest -Uri "$RepoRaw/DarkwoodCoopLauncher.exe" -OutFile $newExePath -UseBasicParsing

        # cmd oculto: espera este processo soltar o arquivo, troca, reabre. Nada visivel.
        $helperArgs = "/c timeout /t 1 /nobreak >nul & move /y `"$newExePath`" `"$exePath`" >nul & start `"`" `"$exePath`""
        Start-Process -FilePath "cmd.exe" -ArgumentList $helperArgs -WindowStyle Hidden
        exit
    } catch {
        if (Test-Path "$exePath.new") { Remove-Item "$exePath.new" -Force -ErrorAction SilentlyContinue }
    }
}
Try-SelfUpdate

function Load-Config {
    if (Test-Path $ConfigFile) {
        try { return Get-Content $ConfigFile -Raw | ConvertFrom-Json } catch {}
    }
    return [PSCustomObject]@{ PeerSteamId64 = ""; DarkwoodPath = ""; InstalledModVersion = "" }
}
function Save-Config($cfg) { $cfg | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8 }

function Find-DarkwoodPath {
    $candidates = @(
        "C:\Program Files (x86)\Steam\steamapps\common\Darkwood",
        "C:\Program Files\Steam\steamapps\common\Darkwood"
    )
    foreach ($c in $candidates) { if (Test-Path "$c\Darkwood.exe") { return $c } }
    $lf = "C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf"
    if (Test-Path $lf) {
        $m = Select-String -Path $lf -Pattern '"path"\s*"([^"]+)"' -AllMatches
        foreach ($x in $m.Matches) {
            $p = $x.Groups[1].Value -replace '\\\\', '\'
            $cand = Join-Path $p "steamapps\common\Darkwood"
            if (Test-Path "$cand\Darkwood.exe") { return $cand }
        }
    }
    return ""
}

function Ensure-SaveFetcher {
    $exe = Join-Path $SaveFetcherDir "SaveFetcher.exe"
    if (Test-Path $exe) { return $exe }
    New-Item -ItemType Directory -Force -Path $SaveFetcherDir | Out-Null
    $zip = Join-Path $env:TEMP "savefetcher-bundle.zip"
    Invoke-WebRequest -Uri "$RepoRaw/savefetcher-bundle.zip" -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $SaveFetcherDir -Force
    return $exe
}

function Write-BepInExConfig($darkwoodPath, $peerId) {
    $cfgDir = Join-Path $darkwoodPath "BepInEx\config"
    New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
    $cfgPath = Join-Path $cfgDir "com.felipe.darkwoodcooponline.cfg"
    if ([string]::IsNullOrWhiteSpace($peerId)) { $peerId = "0" }
    $content = @"
## Settings file was created by plugin Darkwood Co-op Online v0.1.0
## Plugin GUID: com.felipe.darkwoodcooponline

[Loopback]
LocalPort = 7777
RemotePort = 7778

[Steam]
PeerSteamId64 = $peerId

[Transport]
Mode = Steam
"@
    Set-Content -Path $cfgPath -Value $content -Encoding UTF8
}

# Retorna a versao mais nova do mod publicada no repo (ou "" se nao conseguir).
function Get-LatestModVersion {
    try { return (Invoke-WebRequest -Uri "$RepoRaw/mod_version.txt" -UseBasicParsing).Content.Trim() }
    catch { return "" }
}

# Sobe o texto pro 0x0.st e retorna a URL curta (ou $null em falha).
function Send-LogToPaste($filePath) {
    if (-not (Test-Path $filePath)) { return $null }
    $content = Get-Content -Raw -Path $filePath
    # Limita ao final (ultimos ~2 MB) se for enorme - o problema costuma estar no fim.
    $max = 2000000
    if ($content.Length -gt $max) { $content = "...(log truncado, mostrando o final)...`r`n" + $content.Substring($content.Length - $max) }
    $boundary = [System.Guid]::NewGuid().ToString()
    $LF = "`r`n"
    $body = "--$boundary$LF" +
            "Content-Disposition: form-data; name=`"file`"; filename=`"LogOutput.log`"$LF" +
            "Content-Type: text/plain$LF$LF" +
            $content + $LF +
            "--$boundary--$LF"
    $resp = Invoke-RestMethod -Uri "https://0x0.st" -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $body -UserAgent "DarkwoodCoopLauncher"
    return ("$resp").Trim()
}

# ---------------- UI ----------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Darkwood Co-op - Launcher"
$form.Size = New-Object System.Drawing.Size(540, 560)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$cfg = Load-Config
if ([string]::IsNullOrWhiteSpace($cfg.DarkwoodPath)) { $cfg.DarkwoodPath = Find-DarkwoodPath }
if (-not ($cfg.PSObject.Properties.Name -contains "InstalledModVersion")) {
    $cfg | Add-Member -NotePropertyName InstalledModVersion -NotePropertyValue "" -Force
}

# Campo comum: pasta do jogo (fica no topo, fora das abas)
$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Text = "Pasta do Darkwood:"
$lblPath.Location = New-Object System.Drawing.Point(12, 10)
$lblPath.Size = New-Object System.Drawing.Size(500, 18)
$form.Controls.Add($lblPath)

$txtPath = New-Object System.Windows.Forms.TextBox
$txtPath.Text = $cfg.DarkwoodPath
$txtPath.Location = New-Object System.Drawing.Point(12, 30)
$txtPath.Size = New-Object System.Drawing.Size(410, 24)
$form.Controls.Add($txtPath)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "..."
$btnBrowse.Location = New-Object System.Drawing.Point(430, 29)
$btnBrowse.Size = New-Object System.Drawing.Size(80, 26)
$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dlg.ShowDialog() -eq "OK") { $txtPath.Text = $dlg.SelectedPath }
})
$form.Controls.Add($btnBrowse)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Pronto."
$lblStatus.Location = New-Object System.Drawing.Point(12, 62)
$lblStatus.Size = New-Object System.Drawing.Size(500, 34)
$form.Controls.Add($lblStatus)
function Set-Status($msg) { $lblStatus.Text = $msg; $form.Refresh() }

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(12, 100)
$tabs.Size = New-Object System.Drawing.Size(500, 410)
$form.Controls.Add($tabs)

$tabMain = New-Object System.Windows.Forms.TabPage
$tabMain.Text = "Principal"
$tabAdv = New-Object System.Windows.Forms.TabPage
$tabAdv.Text = "Avancado"
$tabs.Controls.Add($tabMain)
$tabs.Controls.Add($tabAdv)

function Get-DarkwoodPathOrWarn {
    $p = $txtPath.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($p) -or -not (Test-Path "$p\Darkwood.exe")) {
        [System.Windows.Forms.MessageBox]::Show("Pasta do Darkwood invalida. Escolha a pasta onde fica o Darkwood.exe.", "Erro") | Out-Null
        return $null
    }
    return $p
}

# ===== ABA PRINCIPAL =====
$my = 15
$lblIntro = New-Object System.Windows.Forms.Label
$lblIntro.Text = "1) Instale o mod (primeira vez). 2) Abra o jogo. Para jogar juntos, o HOST" + [Environment]::NewLine +
                 "abre o jogo, carrega o save e aperta F7. O amigo entra pelo botao 'Entrar no" + [Environment]::NewLine +
                 "jogo' na lista de amigos da Steam - o resto e automatico."
$lblIntro.Location = New-Object System.Drawing.Point(12, $my)
$lblIntro.Size = New-Object System.Drawing.Size(470, 60)
$tabMain.Controls.Add($lblIntro)
$my += 68

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "Instalar BepInEx + Mod (primeira vez)"
$btnInstall.Location = New-Object System.Drawing.Point(12, $my)
$btnInstall.Size = New-Object System.Drawing.Size(470, 36)
$btnInstall.Add_Click({
    $path = Get-DarkwoodPathOrWarn; if (-not $path) { return }
    try {
        Set-Status "Baixando BepInEx..."
        $zip = Join-Path $env:TEMP "bepinex-bundle.zip"
        Invoke-WebRequest -Uri "$RepoRaw/bepinex-bundle.zip" -OutFile $zip
        Expand-Archive -Path $zip -DestinationPath $path -Force
        Set-Status "Baixando mod..."
        Invoke-WebRequest -Uri "$RepoRaw/mod/DarkwoodCoopOnline.dll" -OutFile (Join-Path $path "BepInEx\plugins\DarkwoodCoopOnline.dll")
        Write-BepInExConfig -darkwoodPath $path -peerId $txtPeer.Text.Trim()
        $cfg.InstalledModVersion = Get-LatestModVersion; Save-Config $cfg
        Set-Status "Instalado! Abra o jogo pelo botao Jogar."
    } catch { Set-Status "Erro: $($_.Exception.Message)" }
})
$tabMain.Controls.Add($btnInstall)
$my += 42

$btnSyncMod = New-Object System.Windows.Forms.Button
$btnSyncMod.Text = "Atualizar mod (baixar versao mais nova)"
$btnSyncMod.Location = New-Object System.Drawing.Point(12, $my)
$btnSyncMod.Size = New-Object System.Drawing.Size(470, 36)
$btnSyncMod.Add_Click({
    $path = Get-DarkwoodPathOrWarn; if (-not $path) { return }
    try {
        Set-Status "Baixando ultima versao do mod..."
        Invoke-WebRequest -Uri "$RepoRaw/mod/DarkwoodCoopOnline.dll" -OutFile (Join-Path $path "BepInEx\plugins\DarkwoodCoopOnline.dll")
        $cfg.InstalledModVersion = Get-LatestModVersion; Save-Config $cfg
        Set-Status "Mod atualizado para a versao $($cfg.InstalledModVersion)."
    } catch { Set-Status "Erro: $($_.Exception.Message)" }
})
$tabMain.Controls.Add($btnSyncMod)
$my += 42

$btnPlay = New-Object System.Windows.Forms.Button
$btnPlay.Text = "Jogar (abre o Darkwood pela Steam)"
$btnPlay.Location = New-Object System.Drawing.Point(12, $my)
$btnPlay.Size = New-Object System.Drawing.Size(470, 40)
$btnPlay.Add_Click({
    $cfg.DarkwoodPath = $txtPath.Text.Trim()
    $cfg.PeerSteamId64 = $txtPeer.Text.Trim()
    Save-Config $cfg
    Start-Process "steam://rungameid/274520"
    Set-Status "Abrindo o jogo pela Steam..."
})
$tabMain.Controls.Add($btnPlay)
$my += 52

$lblUpdate = New-Object System.Windows.Forms.Label
$lblUpdate.Location = New-Object System.Drawing.Point(12, $my)
$lblUpdate.Size = New-Object System.Drawing.Size(470, 40)
$lblUpdate.ForeColor = [System.Drawing.Color]::DarkOrange
$tabMain.Controls.Add($lblUpdate)

# ===== ABA AVANCADO =====
$ay = 15
$lblPeer = New-Object System.Windows.Forms.Label
$lblPeer.Text = "SteamID64 do HOST (so p/ metodo manual / puxar save - o convite Steam nao precisa):"
$lblPeer.Location = New-Object System.Drawing.Point(12, $ay)
$lblPeer.Size = New-Object System.Drawing.Size(470, 18)
$tabAdv.Controls.Add($lblPeer)
$ay += 20

$txtPeer = New-Object System.Windows.Forms.TextBox
$txtPeer.Text = $cfg.PeerSteamId64
$txtPeer.Location = New-Object System.Drawing.Point(12, $ay)
$txtPeer.Size = New-Object System.Drawing.Size(470, 24)
$tabAdv.Controls.Add($txtPeer)
$ay += 34

$btnFetch = New-Object System.Windows.Forms.Button
$btnFetch.Text = "Puxar save do host AGORA (P2P - host com o jogo aberto)"
$btnFetch.Location = New-Object System.Drawing.Point(12, $ay)
$btnFetch.Size = New-Object System.Drawing.Size(470, 34)
$btnFetch.Add_Click({
    $peerId = $txtPeer.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($peerId) -or $peerId -eq "0") {
        [System.Windows.Forms.MessageBox]::Show("Preencha o SteamID64 do host primeiro.", "Erro") | Out-Null; return
    }
    $txtOut.Clear()
    try {
        Set-Status "Baixando ferramenta de save..."
        $exe = Ensure-SaveFetcher
        Set-Status "Puxando save do host $peerId ..."
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exe; $psi.Arguments = "$peerId 25"; $psi.WorkingDirectory = $SaveFetcherDir
        $psi.RedirectStandardOutput = $true; $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        while (-not $proc.StandardOutput.EndOfStream) { $txtOut.AppendText($proc.StandardOutput.ReadLine() + "`r`n"); $form.Refresh() }
        $proc.WaitForExit()
        if ($proc.ExitCode -eq 0) { Set-Status "Save recebido! Abra o jogo e escolha o save na tela de perfis." }
        else { Set-Status "Nao deu (codigo $($proc.ExitCode)) - host com o jogo aberto? Veja o log abaixo." }
    } catch { Set-Status "Erro: $($_.Exception.Message)" }
})
$tabAdv.Controls.Add($btnFetch)
$ay += 40

$btnSyncSaveOld = New-Object System.Windows.Forms.Button
$btnSyncSaveOld.Text = "Sincronizar save (metodo antigo - download do repo)"
$btnSyncSaveOld.Location = New-Object System.Drawing.Point(12, $ay)
$btnSyncSaveOld.Size = New-Object System.Drawing.Size(470, 34)
$btnSyncSaveOld.Add_Click({
    $c = [System.Windows.Forms.MessageBox]::Show("Isso SOBRESCREVE seu save local pelo save publicado do host. Continuar?", "Confirmar", "YesNo", "Warning")
    if ($c -ne "Yes") { return }
    try {
        Set-Status "Baixando save mais recente..."
        $zip = Join-Path $env:TEMP "save-latest.zip"
        Invoke-WebRequest -Uri "$RepoRaw/save-latest.zip" -OutFile $zip
        $saveRoot = Join-Path $env:USERPROFILE "AppData\LocalLow\Acid Wizard Studio\Darkwood"
        New-Item -ItemType Directory -Force -Path $saveRoot | Out-Null
        Expand-Archive -Path $zip -DestinationPath $saveRoot -Force
        Set-Status "Save sincronizado."
    } catch { Set-Status "Erro: $($_.Exception.Message)" }
})
$tabAdv.Controls.Add($btnSyncSaveOld)
$ay += 40

$btnSendLog = New-Object System.Windows.Forms.Button
$btnSendLog.Text = "Enviar log pro desenvolvedor (gera um link)"
$btnSendLog.Location = New-Object System.Drawing.Point(12, $ay)
$btnSendLog.Size = New-Object System.Drawing.Size(470, 34)
$btnSendLog.Add_Click({
    $path = $txtPath.Text.Trim()
    $logPath = Join-Path $path "BepInEx\LogOutput.log"
    if (-not (Test-Path $logPath)) { Set-Status "Log nao encontrado em $logPath (o jogo ja rodou com o mod?)."; return }
    try {
        Set-Status "Enviando log..."
        $url = Send-LogToPaste $logPath
        if ([string]::IsNullOrWhiteSpace($url)) { Set-Status "Falha ao enviar o log."; return }
        $txtOut.Text = "Link do log (mande pro desenvolvedor):`r`n$url`r`n"
        Set-Clipboard -Value $url
        Set-Status "Log enviado! O link foi copiado - cole e mande pro desenvolvedor."
    } catch { Set-Status "Erro ao enviar log: $($_.Exception.Message)" }
})
$tabAdv.Controls.Add($btnSendLog)
$ay += 40

$txtOut = New-Object System.Windows.Forms.TextBox
$txtOut.Multiline = $true; $txtOut.ScrollBars = "Vertical"; $txtOut.ReadOnly = $true
$txtOut.Location = New-Object System.Drawing.Point(12, $ay)
$txtOut.Size = New-Object System.Drawing.Size(470, 130)
$tabAdv.Controls.Add($txtOut)

# ---- Checagem de versao ao abrir ----
$form.Add_Shown({
    $form.Activate()
    $latest = Get-LatestModVersion
    if (-not [string]::IsNullOrWhiteSpace($latest)) {
        if ([string]::IsNullOrWhiteSpace($cfg.InstalledModVersion)) {
            $lblUpdate.Text = "Versao do mod no repo: $latest (instale/atualize pra registrar a sua)."
        } elseif ($cfg.InstalledModVersion -ne $latest) {
            $lblUpdate.Text = "NOVA VERSAO DO MOD ($latest) disponivel! Clique em 'Atualizar mod'. (sua: $($cfg.InstalledModVersion))"
        } else {
            $lblUpdate.Text = "Mod atualizado (versao $latest)."
            $lblUpdate.ForeColor = [System.Drawing.Color]::DarkGreen
        }
    }
})
[void]$form.ShowDialog()
