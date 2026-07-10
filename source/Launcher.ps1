Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepoRaw = "https://raw.githubusercontent.com/felipescoutfx/darkwood-coop-launcher/main"
# O .exe do launcher em si NAO fica commitado na branch (pesaria o repo a cada
# versao) - vive so como asset de GitHub Release. "latest/download/..." e uma
# URL ESTAVEL da propria Github que sempre aponta pro asset da release mais
# recente, sem precisar saber o numero da versao.
$LauncherExeUrl = "https://github.com/felipescoutfx/darkwood-coop-launcher/releases/latest/download/DarkwoodCoopLauncher.exe"
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
$LauncherVersion = "2026-07-10.5"

function Try-SelfUpdate {
    # TRAVA CONTRA LOOP INFINITO (achado em teste real, jul/2026): se o
    # `launcher_version.txt` publicado ficar dessincronizado do `.exe` publicado de
    # verdade (ex.: erro humano ao publicar), a instancia recem-atualizada baixaria
    # o MESMO exe de novo, veria a mesma "versao nova" e reabriria em loop infinito
    # (visto ao vivo: ciclo de poucos segundos, tela piscando pra sempre. 1a
    # tentativa de trava usava variavel de ambiente setada pelo `cmd` auxiliar antes
    # de reabrir - NAO FUNCIONOU em teste real, o loop continuou; suspeita: a
    # variavel nao chega limpa no processo novo por algum detalhe de como
    # Start-Process/cmd propaga o ambiente pra um `start` dentro do mesmo `/c`).
    # Fix 2, mais simples e a prova de falha: um ARQUIVO-MARCADOR com timestamp
    # (I/O simples, sem depender de heranca de ambiente entre processos). Se
    # existir E for recente (< 2 min), pula a checagem e apaga o marcador.
    $markerPath = Join-Path $ConfigDir ".just_updated"
    if (Test-Path $markerPath) {
        $age = (Get-Date) - (Get-Item $markerPath).LastWriteTime
        Remove-Item $markerPath -Force -ErrorAction SilentlyContinue
        if ($age.TotalMinutes -lt 2) { return }
    }

    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $exeName = [System.IO.Path]::GetFileNameWithoutExtension($exePath)
    # Rodando via "powershell.exe Launcher.ps1" direto (dev) em vez do .exe compilado -
    # nao ha o que auto-atualizar (nao existe .exe pra trocar).
    if ($exeName -ieq "powershell" -or $exeName -ieq "pwsh") { return }

    try {
        $latest = (Invoke-WebRequest -Uri "$RepoRaw/launcher_version.txt" -UseBasicParsing -TimeoutSec 5).Content.Trim()
    } catch { return }
    # ACHADO EM TESTE REAL: comparar so "diferente" (-ne/-eq) deixa a auto-atualizacao
    # se autossabotar - testando localmente com uma versao NOVA ainda nao publicada,
    # o launcher via a remota como "diferente" e baixava a Release antiga por cima,
    # revertendo o proprio teste. Fix: so atualiza se a remota for ESTRITAMENTE MAIS
    # NOVA (-gt funciona por ordem lexicografica normal no formato AAAA-MM-DD.N) -
    # nunca faz downgrade, nem se dessincronizar de novo por engano.
    if (-not $latest -or $latest -le $LauncherVersion) { return }

    try {
        $newExePath = "$exePath.new"
        Invoke-WebRequest -Uri $LauncherExeUrl -OutFile $newExePath -UseBasicParsing

        # Segunda trava: se o arquivo baixado for IDENTICO (mesmo tamanho) ao atual,
        # nao e uma atualizacao de verdade - nao troca nem reabre, so ignora.
        $curSize = (Get-Item $exePath).Length
        $newSize = (Get-Item $newExePath).Length
        if ($curSize -eq $newSize) {
            Remove-Item $newExePath -Force -ErrorAction SilentlyContinue
            return
        }

        # Marca o arquivo ANTES de disparar o helper - a proxima instancia (recem
        # atualizada) le e apaga isso no proprio Try-SelfUpdate, acima.
        Set-Content -Path $markerPath -Value (Get-Date).Ticks -Encoding UTF8

        # cmd oculto: espera este processo soltar o arquivo, troca, reabre. Nada visivel.
        $helperArgs = "/c timeout /t 1 /nobreak >nul & move /y `"$newExePath`" `"$exePath`" >nul & start `"`" `"$exePath`""
        Start-Process -FilePath "cmd.exe" -ArgumentList $helperArgs -WindowStyle Hidden
        exit
    } catch {
        if (Test-Path "$exePath.new") { Remove-Item "$exePath.new" -Force -ErrorAction SilentlyContinue }
        if (Test-Path $markerPath) { Remove-Item $markerPath -Force -ErrorAction SilentlyContinue }
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

# =====================================================================================
# ---------------- UI (tema escuro/horror, pedido do usuario jul/2026) ----------------
# Paleta inspirada no Darkwood: quase-preto de fundo, musgo/verde apagado como acento
# primario (menus/hover do proprio jogo usam esse tom), vermelho seco como acento de
# perigo/aviso. Janela sem moldura nativa do Windows (barra de titulo propria, arrastavel)
# + navegacao lateral em vez de abas padrao - visual mais "parte do jogo", menos
# generico. Sem assets do jogo em si (direitos autorais) - so cor/tipografia/layout.
# =====================================================================================
$ColBg          = [System.Drawing.Color]::FromArgb(255, 13, 13, 12)
$ColPanelBg     = [System.Drawing.Color]::FromArgb(255, 20, 20, 18)
$ColSidebarBg   = [System.Drawing.Color]::FromArgb(255, 17, 17, 15)
$ColBorder      = [System.Drawing.Color]::FromArgb(255, 40, 40, 36)
$ColAccent      = [System.Drawing.Color]::FromArgb(255, 122, 138, 92)   # musgo/verde apagado
$ColAccentDim   = [System.Drawing.Color]::FromArgb(255, 58,  66,  44)   # mesmo tom, escurecido (fundo de item ativo)
$ColAccentHover = [System.Drawing.Color]::FromArgb(255, 84,  96,  62)
$ColDanger      = [System.Drawing.Color]::FromArgb(255, 138, 58,  53)   # vermelho seco
$ColDangerHover = [System.Drawing.Color]::FromArgb(255, 168, 72,  64)
$ColTextMain    = [System.Drawing.Color]::FromArgb(255, 214, 210, 199)
$ColTextMuted   = [System.Drawing.Color]::FromArgb(255, 132, 128, 118)
$ColBtnBg       = [System.Drawing.Color]::FromArgb(255, 30,  30,  27)
$ColBtnHover    = [System.Drawing.Color]::FromArgb(255, 42,  42,  38)

$FontTitle  = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$FontNav    = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$FontBody   = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Regular)
$FontLabel  = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Regular)
$FontMono   = New-Object System.Drawing.Font("Consolas", 8.5, [System.Drawing.FontStyle]::Regular)
$FontClose  = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Regular)

function New-StyledButton($text, $x, $y, $w, $h, $bg, $hoverBg, $fg, $font) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Location = New-Object System.Drawing.Point($x, $y)
    $btn.Size = New-Object System.Drawing.Size($w, $h)
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderSize = 0
    $btn.FlatAppearance.MouseOverBackColor = $hoverBg
    $btn.BackColor = $bg
    $btn.ForeColor = $fg
    $btn.Font = $font
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.TextAlign = "MiddleCenter"
    $btn.UseVisualStyleBackColor = $false
    return $btn
}

function New-Label($text, $x, $y, $w, $h, $fg, $font) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $text
    $lbl.Location = New-Object System.Drawing.Point($x, $y)
    $lbl.Size = New-Object System.Drawing.Size($w, $h)
    $lbl.ForeColor = $fg
    $lbl.Font = $font
    $lbl.BackColor = [System.Drawing.Color]::Transparent
    return $lbl
}

function New-DarkTextBox($x, $y, $w, $h) {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location = New-Object System.Drawing.Point($x, $y)
    $t.Size = New-Object System.Drawing.Size($w, $h)
    $t.BackColor = $ColBtnBg
    $t.ForeColor = $ColTextMain
    $t.BorderStyle = "FixedSingle"
    $t.Font = $FontBody
    return $t
}

# ---- Janela principal (sem moldura nativa) ----
$form = New-Object System.Windows.Forms.Form
$form.Text = "Darkwood Co-op - Launcher"
$form.ClientSize = New-Object System.Drawing.Size(660, 640)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "None"
$form.BackColor = $ColBg
$form.MaximizeBox = $false
$form.ShowInTaskbar = $true

# Borda de 1px sutil ao redor de tudo (janela sem moldura fica "boiando" sem isso)
$form.Add_Paint({
    param($s, $e)
    $pen = New-Object System.Drawing.Pen($ColBorder, 1)
    $e.Graphics.DrawRectangle($pen, 0, 0, $form.ClientSize.Width - 1, $form.ClientSize.Height - 1)
    $pen.Dispose()
})

# ---- Barra de titulo customizada (arrastavel) ----
$titleBar = New-Object System.Windows.Forms.Panel
$titleBar.Location = New-Object System.Drawing.Point(0, 0)
$titleBar.Size = New-Object System.Drawing.Size(660, 38)
$titleBar.BackColor = $ColSidebarBg
$form.Controls.Add($titleBar)

$lblTitle = New-Label "DARKWOOD  //  CO-OP LAUNCHER" 16 8 400 22 $ColTextMain $FontTitle
$titleBar.Controls.Add($lblTitle)

$btnClose = New-StyledButton "X" 624 0 36 38 $ColSidebarBg $ColDanger $ColTextMuted $FontClose
$btnClose.Add_Click({ $form.Close() })
$titleBar.Controls.Add($btnClose)

$btnMin = New-StyledButton "-" 588 0 36 38 $ColSidebarBg $ColBtnHover $ColTextMuted $FontClose
$btnMin.Add_Click({ $form.WindowState = "Minimized" })
$titleBar.Controls.Add($btnMin)

# Arrastar pela barra de titulo (janela sem moldura nao arrasta sozinha)
$script:dragging = $false
$script:dragOffset = New-Object System.Drawing.Point 0, 0
$dragHandler = {
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $script:dragging = $true
        $script:dragOffset = New-Object System.Drawing.Point($e.X, $e.Y)
    }
}
$moveHandler = {
    param($s, $e)
    if ($script:dragging) {
        $p = $form.PointToScreen($e.Location)
        $form.Location = New-Object System.Drawing.Point(($p.X - $script:dragOffset.X), ($p.Y - $script:dragOffset.Y))
    }
}
$upHandler = { $script:dragging = $false }
$titleBar.Add_MouseDown($dragHandler); $titleBar.Add_MouseMove($moveHandler); $titleBar.Add_MouseUp($upHandler)
$lblTitle.Add_MouseDown($dragHandler); $lblTitle.Add_MouseMove($moveHandler); $lblTitle.Add_MouseUp($upHandler)

# ---- Linha da pasta do jogo (compartilhada, acima da navegacao) ----
$pathPanel = New-Object System.Windows.Forms.Panel
$pathPanel.Location = New-Object System.Drawing.Point(0, 38)
$pathPanel.Size = New-Object System.Drawing.Size(660, 64)
$pathPanel.BackColor = $ColPanelBg
$form.Controls.Add($pathPanel)

$pathPanel.Controls.Add((New-Label "PASTA DO DARKWOOD" 16 8 300 16 $ColTextMuted $FontLabel))

$cfg = Load-Config
# Auto-deteccao: tenta sozinho SEMPRE que o caminho salvo estiver vazio OU invalido
# (pedido do usuario) - so sobra pro botao manual se a deteccao automatica falhar.
if ([string]::IsNullOrWhiteSpace($cfg.DarkwoodPath) -or -not (Test-Path (Join-Path $cfg.DarkwoodPath "Darkwood.exe"))) {
    $auto = Find-DarkwoodPath
    if (-not [string]::IsNullOrWhiteSpace($auto)) { $cfg.DarkwoodPath = $auto }
}
if (-not ($cfg.PSObject.Properties.Name -contains "InstalledModVersion")) {
    $cfg | Add-Member -NotePropertyName InstalledModVersion -NotePropertyValue "" -Force
}

$txtPath = New-DarkTextBox 16 28 560 26
$txtPath.Text = $cfg.DarkwoodPath
$pathPanel.Controls.Add($txtPath)

$btnBrowse = New-StyledButton "..." 584 28 60 26 $ColBtnBg $ColBtnHover $ColTextMain $FontBody
$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dlg.ShowDialog() -eq "OK") { $txtPath.Text = $dlg.SelectedPath }
})
$pathPanel.Controls.Add($btnBrowse)

# ---- Sidebar de navegacao + area de conteudo ----
$sidebar = New-Object System.Windows.Forms.Panel
$sidebar.Location = New-Object System.Drawing.Point(0, 102)
$sidebar.Size = New-Object System.Drawing.Size(150, 502)
$sidebar.BackColor = $ColSidebarBg
$form.Controls.Add($sidebar)

$content = New-Object System.Windows.Forms.Panel
$content.Location = New-Object System.Drawing.Point(150, 102)
$content.Size = New-Object System.Drawing.Size(510, 502)
$content.BackColor = $ColBg
$form.Controls.Add($content)

$script:NavButtons = @{}
$script:NavPanels = @{}
$script:NavY = 14

function Register-NavPanel($key, $label) {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(0, 0)
    $panel.Size = New-Object System.Drawing.Size(510, 502)
    $panel.BackColor = $ColBg
    $panel.Visible = $false
    $content.Controls.Add($panel)

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "  $label"
    $btn.Location = New-Object System.Drawing.Point(0, $script:NavY)
    $btn.Size = New-Object System.Drawing.Size(150, 38)
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderSize = 0
    $btn.TextAlign = "MiddleLeft"
    $btn.Font = $FontNav
    $btn.ForeColor = $ColTextMuted
    $btn.BackColor = $ColSidebarBg
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.UseVisualStyleBackColor = $false
    $btn.Add_Click({ Show-NavPanel $key }.GetNewClosure())
    $sidebar.Controls.Add($btn)

    $script:NavButtons[$key] = $btn
    $script:NavPanels[$key] = $panel
    $script:NavY += 40
    return $panel
}

function Show-NavPanel($key) {
    foreach ($k in $script:NavPanels.Keys) {
        $active = ($k -eq $key)
        $script:NavPanels[$k].Visible = $active
        $script:NavButtons[$k].BackColor = if ($active) { $ColAccentDim } else { $ColSidebarBg }
        $script:NavButtons[$k].ForeColor = if ($active) { $ColTextMain } else { $ColTextMuted }
    }
}

$panelMain = Register-NavPanel "main" "PRINCIPAL"
$panelAdv  = Register-NavPanel "adv"  "AVANCADO"

function Get-DarkwoodPathOrWarn {
    $p = $txtPath.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($p) -or -not (Test-Path "$p\Darkwood.exe")) {
        [System.Windows.Forms.MessageBox]::Show("Pasta do Darkwood invalida. Escolha a pasta onde fica o Darkwood.exe.", "Erro") | Out-Null
        return $null
    }
    return $p
}

# ===== PAINEL PRINCIPAL =====
$my = 16
$lblIntro = New-Label ("1) Instale o mod (primeira vez). 2) Abra o jogo. Para jogar juntos, o HOST" + [Environment]::NewLine +
                 "abre o jogo, carrega o save e aperta F7. O amigo entra pelo botao 'Entrar no" + [Environment]::NewLine +
                 "jogo' na lista de amigos da Steam - o resto e automatico.") 0 $my 490 60 $ColTextMuted $FontLabel
$panelMain.Controls.Add($lblIntro)
$my += 66

$btnInstall = New-StyledButton "INSTALAR BEPINEX + MOD (1a vez)" 0 $my 490 40 $ColAccentDim $ColAccentHover $ColTextMain $FontNav
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
$panelMain.Controls.Add($btnInstall)
$my += 48

$btnSyncMod = New-StyledButton "ATUALIZAR MOD (baixar versao mais nova)" 0 $my 490 40 $ColBtnBg $ColBtnHover $ColTextMain $FontBody
$btnSyncMod.Add_Click({
    $path = Get-DarkwoodPathOrWarn; if (-not $path) { return }
    try {
        Set-Status "Baixando ultima versao do mod..."
        Invoke-WebRequest -Uri "$RepoRaw/mod/DarkwoodCoopOnline.dll" -OutFile (Join-Path $path "BepInEx\plugins\DarkwoodCoopOnline.dll")
        $cfg.InstalledModVersion = Get-LatestModVersion; Save-Config $cfg
        Set-Status "Mod atualizado para a versao $($cfg.InstalledModVersion)."
    } catch { Set-Status "Erro: $($_.Exception.Message)" }
})
$panelMain.Controls.Add($btnSyncMod)
$my += 48

$btnPlay = New-StyledButton "JOGAR  (abre o Darkwood pela Steam)" 0 $my 490 46 $ColAccent $ColAccentHover ([System.Drawing.Color]::FromArgb(255,14,14,12)) $FontNav
$btnPlay.Add_Click({
    $cfg.DarkwoodPath = $txtPath.Text.Trim()
    $cfg.PeerSteamId64 = $txtPeer.Text.Trim()
    Save-Config $cfg
    Start-Process "steam://rungameid/274520"
    Set-Status "Abrindo o jogo pela Steam..."
})
$panelMain.Controls.Add($btnPlay)
$my += 58

$lblUpdate = New-Label "" 0 $my 490 40 $ColTextMuted $FontLabel
$panelMain.Controls.Add($lblUpdate)

# ===== PAINEL AVANCADO =====
$ay = 16
$panelAdv.Controls.Add((New-Label "STEAMID64 DO HOST (metodo manual / puxar save - o convite Steam nao precisa)" 0 $ay 490 16 $ColTextMuted $FontLabel))
$ay += 20

$txtPeer = New-DarkTextBox 0 $ay 490 26
$txtPeer.Text = $cfg.PeerSteamId64
$panelAdv.Controls.Add($txtPeer)
$ay += 34

# Pedido do usuario (jul/2026): digitar o SteamID64 aqui nao gravava nada sozinho -
# so ia pro .cfg do jogo se clicasse "Instalar" de novo na aba Principal (confuso,
# gerou um bug real de conexao). Botao dedicado: atualiza o .cfg na hora, sem
# precisar reinstalar nada.
$btnUpdateCfg = New-StyledButton "ATUALIZAR .cfg COM ESTE STEAMID64" 0 $ay 490 34 $ColAccentDim $ColAccentHover $ColTextMain $FontBody
$btnUpdateCfg.Add_Click({
    $path = Get-DarkwoodPathOrWarn; if (-not $path) { return }
    $peerId = $txtPeer.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($peerId) -or $peerId -eq "0") {
        [System.Windows.Forms.MessageBox]::Show("Preencha o SteamID64 antes de atualizar o .cfg.", "Erro") | Out-Null; return
    }
    try {
        Write-BepInExConfig -darkwoodPath $path -peerId $peerId
        $cfg.PeerSteamId64 = $peerId; Save-Config $cfg
        Set-Status ".cfg atualizado com PeerSteamId64=$peerId e Mode=Steam. Reabra o jogo se ja estava aberto."
    } catch { Set-Status "Erro atualizando .cfg: $($_.Exception.Message)" }
})
$panelAdv.Controls.Add($btnUpdateCfg)
$ay += 42

$btnFetch = New-StyledButton "PUXAR SAVE DO HOST AGORA (P2P - host com o jogo aberto)" 0 $ay 490 34 $ColBtnBg $ColBtnHover $ColTextMain $FontBody
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
$panelAdv.Controls.Add($btnFetch)
$ay += 40

$btnSyncSaveOld = New-StyledButton "SINCRONIZAR SAVE (metodo antigo - download do repo)" 0 $ay 490 34 $ColBtnBg $ColBtnHover $ColTextMain $FontBody
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
$panelAdv.Controls.Add($btnSyncSaveOld)
$ay += 40

$btnSendLog = New-StyledButton "ENVIAR LOG PRO DESENVOLVEDOR (gera um link)" 0 $ay 490 34 $ColDanger $ColDangerHover $ColTextMain $FontBody
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
$panelAdv.Controls.Add($btnSendLog)
$ay += 42

$txtOut = New-Object System.Windows.Forms.TextBox
$txtOut.Multiline = $true; $txtOut.ScrollBars = "Vertical"; $txtOut.ReadOnly = $true
$txtOut.Location = New-Object System.Drawing.Point(0, $ay)
$txtOut.Size = New-Object System.Drawing.Size(490, 140)
$txtOut.BackColor = $ColBtnBg
$txtOut.ForeColor = $ColTextMain
$txtOut.BorderStyle = "FixedSingle"
$txtOut.Font = $FontMono
$panelAdv.Controls.Add($txtOut)

Show-NavPanel "main"

# ---- Barra de status (fixa embaixo) ----
$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Location = New-Object System.Drawing.Point(0, 604)
$statusPanel.Size = New-Object System.Drawing.Size(660, 36)
$statusPanel.BackColor = $ColSidebarBg
$form.Controls.Add($statusPanel)

$lblStatus = New-Label "Pronto." 16 8 620 20 $ColTextMuted $FontLabel
$statusPanel.Controls.Add($lblStatus)
function Set-Status($msg) { $lblStatus.Text = $msg; $form.Refresh() }

# ---- Checagem de versao ao abrir ----
$form.Add_Shown({
    $form.Activate()
    $latest = Get-LatestModVersion
    if (-not [string]::IsNullOrWhiteSpace($latest)) {
        if ([string]::IsNullOrWhiteSpace($cfg.InstalledModVersion)) {
            $lblUpdate.ForeColor = $ColTextMuted
            $lblUpdate.Text = "Versao do mod no repo: $latest (instale/atualize pra registrar a sua)."
        } elseif ($cfg.InstalledModVersion -ne $latest) {
            $lblUpdate.ForeColor = $ColAccent
            $lblUpdate.Text = "NOVA VERSAO DO MOD ($latest) disponivel! Clique em Atualizar mod. (sua: $($cfg.InstalledModVersion))"
        } else {
            $lblUpdate.ForeColor = $ColTextMuted
            $lblUpdate.Text = "Mod atualizado (versao $latest)."
        }
    }
})
[void]$form.ShowDialog()
