<# 
    MENU DE SUPORTE E REPARO - ALLAN PABLO (v3.0.1)
    Autor original: Pablo Oliveira  •  Revisado por: Allan Pablo
    Descricao: Menu de manutencao para Windows com elevacao automatica, logs, relatorio HTML, temas, perfis e utilitarios.
    Compatibilidade: Windows PowerShell 5.1+ (sem operador '?.')
#>

#region Elevacao automatica como Administrador
function Ensure-Admin {
    $id  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pri = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $pri.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host 'Elevando privilegios...' -ForegroundColor Yellow
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = (Get-Process -Id $PID).Path
        $psi.Arguments = ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath)
        $psi.Verb = 'runas'
        try { [Diagnostics.Process]::Start($psi) | Out-Null } catch { Write-Host 'Usuario cancelou a elevacao.' -ForegroundColor Red }
        exit
    }
}
Ensure-Admin
#endregion

#region Desbloquear o arquivo (Zone.Identifier) e preferencia de detalhes
try {
    Unblock-File -Path $PSCommandPath -ErrorAction SilentlyContinue
} catch {
    try { $ads = "$PSCommandPath:Zone.Identifier"; if (Test-Path $ads) { Remove-Item $ads -Force } } catch {}
}
# Sempre exibir detalhes (quando comandos respeitarem Verbose/Information)
$VerbosePreference = 'Continue'
$InformationPreference = 'Continue'
#endregion

#region Console/Encoding
try {
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}
#endregion

#region Configuracao/Temas/Perfis
$Global:APRoot    = Join-Path $env:ProgramData 'APSupport'
$Global:CfgPath   = Join-Path $APRoot 'config.json'
$null = New-Item -ItemType Directory -Path $APRoot -Force -ErrorAction SilentlyContinue

$DefaultConfig = @{
  Theme    = 'Default';
  Profile  = 'Completo';   # Rapido | Padrao | Completo
  Confirm  = $true;        # se Padrao
  Operator = 'Allan Pablo';
}

function Save-Config([hashtable]$cfg) {
  $json = ($cfg | ConvertTo-Json -Depth 5)
  Set-Content -Path $Global:CfgPath -Value $json -Encoding UTF8
}

function Load-Config {
  if (Test-Path $Global:CfgPath) {
    try { return Get-Content $Global:CfgPath -Raw | ConvertFrom-Json -Depth 5 } catch { return $DefaultConfig }
  } else {
    Save-Config $DefaultConfig
    return $DefaultConfig
  }
}

$Config = Load-Config

# Temas predefinidos
$ThemeCatalog = @{
  default = @{ Banner='Cyan';   Border='DarkCyan'; Text='Gray';  Accent='Green';  Warn='Yellow'; Error='Red' };
  dark    = @{ Banner='White';  Border='DarkGray'; Text='Gray';  Accent='Cyan';   Warn='Yellow'; Error='Red' };
  highcontrast = @{ Banner='White'; Border='Black'; Text='White'; Accent='Yellow'; Warn='Magenta'; Error='Red' };
}

$ThemeName = $Config.Theme
if (-not $ThemeCatalog.ContainsKey($ThemeName)) { $ThemeName = 'default' }
$Theme = $ThemeCatalog[$ThemeName]

$Global:ProfileMode = $Config.Profile  # Rapido/Padrao/Completo
if ('Rapido','Padrao','Completo' -notcontains $Global:ProfileMode) { $Global:ProfileMode = 'Padrao' }

function Should-AutoConfirm([string]$action) {
  switch ($Global:ProfileMode) {
    'Rapido'    { return $true }
    'Completo'  { return $true }
    default     { return $false }
  }
}

function Confirm-UX($message) {
  if (Should-AutoConfirm $message) { return $true }
  if (-not $Config.Confirm) { return $true }
  $ans = Read-Host "$message (S/N)"
  return ($ans -match '^[sS]')
}

# Pergunta/define operador (uma vez) e salva na config
if ([string]::IsNullOrWhiteSpace($Config.Operator)) {
  $op = Read-Host 'Identifique-se (nome do operador)'
  if (-not [string]::IsNullOrWhiteSpace($op)) {
    $Config.Operator = $op
    Save-Config @{ Theme=$ThemeName; Profile=$Global:ProfileMode; Confirm=$Config.Confirm; Operator=$op }
  }
}
$Global:Operator = $Config.Operator
#endregion

#region Logging, Relatorio HTML, Progresso
$global:LogRoot = Join-Path $APRoot 'logs'
$null = New-Item -ItemType Directory -Path $global:LogRoot -Force -ErrorAction SilentlyContinue
$global:LogFile = Join-Path $global:LogRoot ((Get-Date -Format 'yyyy-MM-dd_HH-mm-ss') + '.log')
$global:RunLog  = New-Object 'System.Collections.ArrayList'

function Log($msg) {
    $stamp = (Get-Date).ToString('u')
    $line = "[$stamp] $msg"
    Add-Content -Path $global:LogFile -Value $line
}

function Add-RunLog([string]$action,[string]$status,[string]$details) {
    $null = $global:RunLog.Add([pscustomobject]@{ Time=(Get-Date); Action=$action; Status=$status; Details=$details })
}

# === Banner helpers (Unicode-safe, ASCII fallback) ===
function Get-BoxCharset {
    param([switch]$Ascii)
    if ($Ascii) {
        return @{ TL='+'; TR='+'; BL='+'; BR='+'; H='='; V='|'; ML='+'; MR='+'; MH='-' }
    }
    try {
        return @{
            TL=[char]0x2554; TR=[char]0x2557; BL=[char]0x255A; BR=[char]0x255D;
            H=[char]0x2550;   V=[char]0x2551;  ML=[char]0x255F; MR=[char]0x2562; MH=[char]0x2500
        }
    } catch {
        return @{ TL='+'; TR='+'; BL='+'; BR='+'; H='='; V='|'; ML='+'; MR='+'; MH='-' }
    }
}

function New-Badge([string]$label,[string]$fg='Black',[string]$bg='DarkCyan') {
    try {
        Write-Host -NoNewline (' [' + $label + '] ') -ForegroundColor $fg -BackgroundColor $bg
    } catch {
        Write-Host -NoNewline (' [' + $label + '] ')
    }
}

function Format-Right([string]$left,[string]$right,[int]$width) {
    $maxLeft = [Math]::Max(0, $width - $right.Length - 1)
    if ($left.Length -gt $maxLeft) { $left = $left.Substring(0, $maxLeft) }
    $spaces = [Math]::Max(1, $width - $left.Length - $right.Length)
    return ($left + (' ' * $spaces) + $right)
}
# === end helpers ===



function Header($title) {
    Clear-Host

    # Fallback automático para ASCII caso seu console não renderize Unicode
    $ascii = $false
    try { $null = [Console]::OutputEncoding } catch { $ascii = $true }

    # Tabela de caracteres do quadro (Unicode → ASCII se necessário)
    function Get-BoxCharset {
        param([switch]$Ascii)
        if ($Ascii) {
            return @{ TL='+'; TR='+'; BL='+'; BR='+'; H='='; V='|'; ML='+'; MR='+'; MH='-' }
        }
        return @{
            TL=[char]0x2554; TR=[char]0x2557; BL=[char]0x255A; BR=[char]0x255D;
            H=[char]0x2550;  V=[char]0x2551;  ML=[char]0x255F; MR=[char]0x2562; MH=[char]0x2500
        }
    }

    $cs    = Get-BoxCharset -Ascii:$ascii
    $winW  = $Host.UI.RawUI.WindowSize.Width
    $innerW = [Math]::Min([Math]::Max(60, $winW - 6), 110)   # largura alvo

    # ===== BARRAS (PS 5.1-safe) =====
    # Em vez de [char]*[int], usamos o construtor de string do .NET:
    $hbarTop = New-Object string ($cs.H,  ($innerW + 2))
    $mhbar   = New-Object string ($cs.MH, ($innerW + 2))
    $hbarBot = New-Object string ($cs.H,  ($innerW + 2))

    $top    = ("{0}{1}{2}" -f $cs.TL, $hbarTop, $cs.TR)
    $sep    = ("{0}{1}{2}" -f $cs.ML, $mhbar,   $cs.MR)
    $bottom = ("{0}{1}{2}" -f $cs.BL, $hbarBot, $cs.BR)

    $ver = 'v3.0.1'

    # Título sem símbolos “•” para evitar mojibake em consoles não-UTF8
    $titleLeft = 'APSupport - Menu de Suporte e Reparo'
    function Format-Right([string]$left,[string]$right,[int]$width) {
        $maxLeft = [Math]::Max(0, $width - $right.Length - 1)
        if ($left.Length -gt $maxLeft) { $left = $left.Substring(0, $maxLeft) }
        $spaces = [Math]::Max(1, $width - $left.Length - $right.Length)
        return ($left + (' ' * $spaces) + $right)
    }
    $line1 = Format-Right $titleLeft $ver $innerW

    $sub  = if ($title) { ':: ' + $title } else { '' }
    $op   = $(if ($Global:Operator) { $Global:Operator } else { 'N/A' })
    $meta1 = ('Operador: {0}    Perfil: {1}    Tema: {2}' -f $op, $Global:ProfileMode, $ThemeName)
    $meta2 = ('Log: {0}' -f $global:LogFile)

    # Badges helper
    function New-Badge([string]$label,[string]$fg='Black',[string]$bg='DarkCyan') {
        try { Write-Host -NoNewline (' [' + $label + '] ') -ForegroundColor $fg -BackgroundColor $bg }
        catch { Write-Host -NoNewline (' [' + $label + '] ') }
    }

    # ===== Render =====
    Write-Host $top -ForegroundColor $Theme.Border
    Write-Host ($cs.V + ' ' + $line1.PadRight($innerW) + ' ' + $cs.V) -ForegroundColor $Theme.Banner
    Write-Host $sep -ForegroundColor $Theme.Border
    if ($sub) { Write-Host ($cs.V + ' ' + $sub.PadRight($innerW) + ' ' + $cs.V) -ForegroundColor $Theme.Warn }
    Write-Host ($cs.V + ' ' + $meta1.PadRight($innerW) + ' ' + $cs.V) -ForegroundColor $Theme.Text
    Write-Host ($cs.V + ' ' + $meta2.PadRight($innerW) + ' ' + $cs.V) -ForegroundColor DarkGray

    # Badges
    Write-Host ($cs.V + ' ') -NoNewline -ForegroundColor $Theme.Border
    New-Badge 'ADMIN' 'White' 'DarkGreen'
    New-Badge 'VERBOSE ON' 'Black' 'Yellow'
    New-Badge 'PS 5.1' 'White' 'DarkBlue'
    $wu  = if ($Global:EnvInfo.WU_Running) { 'WU: Running' } else { 'WU: Stopped' }
    $wuB = if ($Global:EnvInfo.WU_Running) { 'DarkGreen' } else { 'DarkRed' }
    New-Badge $wu 'White' $wuB
    $curr = [Console]::CursorLeft
    $remain = [Math]::Max(0, ($innerW + 3) - $curr)
    Write-Host (' ' * $remain) -NoNewline
    Write-Host $cs.V -ForegroundColor $Theme.Border

    Write-Host $bottom -ForegroundColor $Theme.Border
    Write-Host
}



function Generate-Report {
    try {
        $desktop = [Environment]::GetFolderPath('Desktop')
        $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
        $htmlPath = Join-Path $desktop ('APSupport-Relatorio-' + $ts + '.html')
        $style = @'
<style>
body { font-family: Segoe UI, Arial, sans-serif; background:#0b0e11; color:#e6e6e6; }
h1 { color:#7bdcb5; }
h2 { color:#e6e6e6; border-bottom:1px solid #333; padding-bottom:4px; }
.table { width:100%; border-collapse:collapse; }
.table th, .table td { border-bottom:1px solid #333; padding:6px 8px; text-align:left; }
.badge { display:inline-block; padding:2px 6px; border-radius:6px; font-size:12px; }
.ok { background:#1b5e20; }
.warn { background:#8d6e63; }
.err { background:#b71c1c; }
.small { color:#aaa; font-size:12px; }
</style>
'@
        $rowList = @()
        foreach ($r in $global:RunLog) {
            $cls = switch ($r.Status) { 'OK' {'ok'} 'WARN' {'warn'} default {'err'} }
            $rowList += ("<tr><td>{0}</td><td>{1}</td><td><span class='badge {2}'>{3}</span></td><td>{4}</td></tr>" -f $r.Time, $r.Action, $cls, $r.Status, ($r.Details -replace '<','&lt;'))
        }
        $rows = ($rowList -join [Environment]::NewLine)

        $op = $(if ($Global:Operator) { $Global:Operator } else { 'N/A' })
        $content = @"
<!DOCTYPE html><html><head><meta charset='UTF-8'>$style</head><body>
<h1>Relatorio de Suporte - Allan Pablo (v3.0.1)</h1>
<p><b>Operador:</b> $op &nbsp; <b>Perfil:</b> $($Global:ProfileMode) &nbsp; <b>Tema:</b> $ThemeName</p>
<p class='small'><b>Log:</b> $global:LogFile</p>
<h2>Acoes executadas</h2>
<table class='table'><thead><tr><th>Hora</th><th>Acao</th><th>Status</th><th>Detalhes</th></tr></thead><tbody>
$rows
</tbody></table>
</body></html>
"@
        Set-Content -Path $htmlPath -Value $content -Encoding UTF8
        Write-Host ('Relatorio gerado: ' + $htmlPath) -ForegroundColor $Theme.Accent
    } catch { Write-Host 'Falha ao gerar relatorio.' -ForegroundColor $Theme.Error }
}

function Show-ProgressBlock([string]$Activity,[scriptblock]$Block) {
    try {
        Write-Progress -Activity $Activity -Status 'Em andamento...'
        & $Block
    } finally {
        Write-Progress -Activity $Activity -Completed
    }
}
#endregion

#region Auto-deteccao de ambiente (PS 5.1-friendly)
$svcWU = $null
try { $svcWU = Get-Service wuauserv -ErrorAction SilentlyContinue } catch {}
$WU = $false
if ($svcWU) { $WU = ($svcWU.Status -eq 'Running') }

$Global:EnvInfo = [pscustomobject]@{
  HasWinget   = [bool](Get-Command winget -ErrorAction SilentlyContinue);
  WindowsSKU  = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').ProductName;
  WU_Running  = $WU;
  Disks       = @();
}
try {
  $Global:EnvInfo.Disks = Get-PhysicalDisk | Select-Object FriendlyName,MediaType,Size,HealthStatus
} catch { $Global:EnvInfo.Disks = @() }
#endregion

#region Utilitarios
function Pause-Return { Write-Host ''; Read-Host 'Pressione ENTER para voltar ao menu' | Out-Null }

function Set-ThemeAndProfile {
    Header 'Trocar Tema/Perfil'
    Write-Host 'Temas: default, dark, highcontrast' -ForegroundColor $Theme.Accent
    $t = Read-Host ('Tema atual: ' + $ThemeName + '  -> Novo tema (ENTER mantem)')
    if (-not [string]::IsNullOrWhiteSpace($t) -and $ThemeCatalog.ContainsKey($t)) { $script:ThemeName = $t; $script:Theme = $ThemeCatalog[$t] }
    Write-Host 'Perfis: Rapido, Padrao, Completo' -ForegroundColor $Theme.Accent
    $p = Read-Host ('Perfil atual: ' + $Global:ProfileMode + '  -> Novo perfil (ENTER mantem)')
    if ('Rapido','Padrao','Completo' -contains $p) { $Global:ProfileMode = $p }
    $Config.Theme   = $ThemeName
    $Config.Profile = $Global:ProfileMode
    Save-Config $Config
    Write-Host 'Tema/Perfil atualizados.' -ForegroundColor $Theme.Accent
    Pause-Return
}
#endregion

#region Acoes principais (A01..A28)
function A01-ChkDsk {
    Header 'Verificar/Agendar CHKDSK'
    $drive  = (Read-Host 'Informe a letra da unidade (ex: C)').Trim().TrimEnd(':')
    if (-not $drive) { return }
    $target = "$($drive):"
    Log "CHKDSK /F /R na unidade $target"
    Write-Host "Agendando CHKDSK /F /R na unidade $target" -ForegroundColor $Theme.Accent
    try {
        Show-ProgressBlock 'Executando CHKDSK' { chkdsk $target /F /R }
        Add-RunLog 'CHKDSK' 'OK' $target
    } catch { Write-Host $_ -ForegroundColor $Theme.Error; Log $_; Add-RunLog 'CHKDSK' 'ERR' $_.ToString() }
    Pause-Return
}

function A02-SFC {
    Header 'SFC /SCANNOW'
    Log 'Executando SFC /SCANNOW'
    try {
        Show-ProgressBlock 'Executando SFC' { sfc /scannow | Tee-Object -FilePath $global:LogFile -Append }
        Add-RunLog 'SFC' 'OK' 'sfc /scannow'
    } catch { Add-RunLog 'SFC' 'ERR' $_.ToString() }
    Pause-Return
}

function A03-CleanupTemp {
    Header 'Limpeza de Arquivos Temporarios'
    Log 'Limpando pastas TEMP do sistema e usuario'
    $paths = @($env:TEMP, $env:TMP, "$env:WinDir\Temp") | Select-Object -Unique
    foreach ($p in $paths) {
        Write-Host "Limpando: $p" -ForegroundColor $Theme.Accent
        try { Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue } catch { Log $_ }
    }
    if (Confirm-UX 'Deseja tambem limpar cache do Windows Update?') {
        Log 'Limpando cache do Windows Update'
        net stop wuauserv | Out-Null
        net stop bits | Out-Null
        Remove-Item -Path "$env:SystemRoot\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
        net start bits | Out-Null
        net start wuauserv | Out-Null
        Write-Host 'Cache do Windows Update limpo.' -ForegroundColor $Theme.Accent
        Add-RunLog 'Cleanup WU' 'OK' 'SoftwareDistribution\Download'
    }
    Write-Host 'Limpeza concluida.' -ForegroundColor $Theme.Accent
    Add-RunLog 'Cleanup TEMP' 'OK' ($paths -join ', ')
    Pause-Return
}

function A04-MemDiag { Header 'Diagnostico de Memoria (mdsched)'; Log 'Abrindo mdsched'; mdsched.exe; Add-RunLog 'MemDiag' 'OK' 'mdsched'; Pause-Return }
function A05-RestoreSystem { Header 'Restaurar Sistema'; Log 'Abrindo rstrui'; rstrui.exe; Add-RunLog 'System Restore' 'OK' 'rstrui'; Pause-Return }

function A06-NetworkTest {
    Header 'Teste de Conectividade'
    $targetHost = Read-Host 'Host/IP para ping (padrao 8.8.8.8)'
    if ([string]::IsNullOrWhiteSpace($targetHost)) { $targetHost = '8.8.8.8' }
    Log "Ping em $targetHost"
    try {
        Test-Connection -ComputerName $targetHost -Count 5 | Tee-Object -FilePath $global:LogFile -Append
        if (Confirm-UX 'Deseja executar um tracert tambem?') { tracert $targetHost | Tee-Object -FilePath $global:LogFile -Append }
        Add-RunLog 'Network Test' 'OK' $targetHost
    } catch { Add-RunLog 'Network Test' 'ERR' $_.ToString() }
    Pause-Return
}

function A07-TaskManager { Header 'Gerenciador de Tarefas'; Log 'Abrindo TASKMGR'; Start-Process taskmgr.exe; Add-RunLog 'Task Manager' 'OK' ''; Pause-Return }

function A08-BackupDrivers {
    Header 'Backup de Drivers (pnputil)'
    $dest = Read-Host 'Pasta de destino (ex: D:\DriversBackup)'
    if (-not $dest) { return }
    $null = New-Item -ItemType Directory -Path $dest -Force -ErrorAction SilentlyContinue
    Log "Exportando drivers para $dest"
    pnputil /export-driver * "$dest" | Tee-Object -FilePath $global:LogFile -Append
    Write-Host "Backup concluido em: $dest" -ForegroundColor $Theme.Accent
    Add-RunLog 'Drivers Backup' 'OK' $dest
    Pause-Return
}

function A09-WindowsUpdateLog { Header 'Gerar WindowsUpdate.log'; Log 'Get-WindowsUpdateLog'; Get-WindowsUpdateLog -LogPath (Join-Path $env:Public 'WindowsUpdate.log'); Add-RunLog 'WU Log' 'OK' 'Public\WindowsUpdate.log'; Pause-Return }

function A10-SystemInfo {
    Header 'Informacoes do Sistema'
    Log 'Coletando SystemInfo'
    systeminfo | Tee-Object -FilePath $global:LogFile -Append
    Write-Host "`nResumo de hardware (memoria/CPU):" -ForegroundColor $Theme.Warn
    Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model, NumberOfLogicalProcessors, TotalPhysicalMemory | Format-List
    Add-RunLog 'System Info' 'OK' 'systeminfo + CIM'
    Pause-Return
}

function A11-FlushDNS {
    Header 'Limpar Cache DNS'
    Log 'ipconfig /flushdns'
    ipconfig /flushdns | Tee-Object -FilePath $global:LogFile -Append
    if (Confirm-UX 'Deseja renovar IP (ipconfig /release /renew)?') { ipconfig /release; ipconfig /renew }
    Add-RunLog 'DNS Flush' 'OK' ''
    Pause-Return
}

function A12-NetworkReset {
    Header 'Reiniciar Pilha de Rede'
    Log 'netsh winsock reset & netsh int ip reset'
    netsh winsock reset | Tee-Object -FilePath $global:LogFile -Append
    netsh int ip reset   | Tee-Object -FilePath $global:LogFile -Append
    Write-Host 'Reinicializacao aplicada. Reinicie o computador para efeito completo.' -ForegroundColor $Theme.Warn
    Add-RunLog 'Network Reset' 'OK' ''
    Pause-Return
}

function A13-Defrag {
    Header 'Desfragmentar Disco (HDD)'
    $drive  = (Read-Host 'Letra da unidade (ex: C)').Trim().TrimEnd(':')
    if (-not $drive) { return }
    $target = "$($drive):"
    Log "desfragmentando $target"
    defrag $target /U /V | Tee-Object -FilePath $global:LogFile -Append
    Add-RunLog 'Defrag' 'OK' $target
    Pause-Return
}

function A14-LocalUsers { Header 'Gerenciar Usuarios Locais'; Log 'lusrmgr.msc'; lusrmgr.msc; Add-RunLog 'Lusrmgr' 'OK' ''; Pause-Return }

function A15-DISM {
    Header 'DISM /RestoreHealth'
    Log 'DISM /Online /Cleanup-Image /RestoreHealth'
    try { Show-ProgressBlock 'Executando DISM' { DISM /Online /Cleanup-Image /RestoreHealth | Tee-Object -FilePath $global:LogFile -Append }; Add-RunLog 'DISM' 'OK' '' } catch { Add-RunLog 'DISM' 'ERR' $_.ToString() }
    if ($Global:ProfileMode -eq 'Completo') { try { sfc /scannow | Tee-Object -FilePath $global:LogFile -Append; Add-RunLog 'SFC pos-DISM' 'OK' '' } catch {} }
    Pause-Return
}

function A16-FirewallToggle {
    Header 'Ativar/Desativar Firewall'
    $state = Read-Host 'Digite ON para ativar ou OFF para desativar o Firewall (todas as perfis)'
    if ($state -match '^(on|ON)$') { Log 'Firewall ON'; netsh advfirewall set allprofiles state on; Write-Host 'Firewall ATIVADO.' -ForegroundColor $Theme.Accent; Add-RunLog 'Firewall' 'OK' 'ON' }
    elseif ($state -match '^(off|OFF)$') {
        if (Confirm-UX 'Tem certeza que deseja DESATIVAR o Firewall? Risco de seguranca!') { Log 'Firewall OFF'; netsh advfirewall set allprofiles state off; Write-Host 'Firewall DESATIVADO.' -ForegroundColor $Theme.Warn; Add-RunLog 'Firewall' 'WARN' 'OFF' }
    } else { Write-Host 'Opcao invalida.' -ForegroundColor $Theme.Error; Add-RunLog 'Firewall' 'ERR' 'Entrada invalida' }
    Pause-Return
}

function A17-EventViewer { Header 'Visualizador de Eventos'; Log 'eventvwr.msc'; eventvwr.msc; Add-RunLog 'Event Viewer' 'OK' ''; Pause-Return }

function A18-DiskSpeed {
    Header 'Teste de Velocidade de Disco (winsat)'
    Log 'winsat disk'
    $drive = (Read-Host 'Letra da unidade (padrao: C)').Trim()
    if ([string]::IsNullOrWhiteSpace($drive)) { $drive = 'C' }
    $drive = $drive.TrimEnd(':')
    winsat disk -drive $drive | Tee-Object -FilePath $global:LogFile -Append
    Add-RunLog 'WinSAT' 'OK' $drive
    Pause-Return
}

function A19-RestorePoint {
    Header 'Criar Ponto de Restauracao'
    Log 'Checkpoint-Computer'
    $desc = Read-Host 'Descricao do ponto (padrao: Ponto Manual)'
    if ([string]::IsNullOrWhiteSpace($desc)) { $desc = 'Ponto Manual' }
    try { Checkpoint-Computer -Description $desc -RestorePointType 'MODIFY_SETTINGS'; Write-Host 'Ponto de restauracao criado.' -ForegroundColor $Theme.Accent; Add-RunLog 'Restore Point' 'OK' $desc } catch { Write-Host 'Falhou ao criar ponto. Protecao do Sistema pode estar desabilitada.' -ForegroundColor $Theme.Warn; Log $_; Add-RunLog 'Restore Point' 'ERR' $_.ToString() }
    Pause-Return
}

function A20-CustomCMD {
    Header 'Comando Personalizado (CMD/PowerShell)'
    $cmd = Read-Host 'Digite o comando para executar'
    if (-not $cmd) { return }
    Log "Exec custom: $cmd"
    try { Invoke-Expression $cmd 2>&1 | Tee-Object -FilePath $global:LogFile -Append; Add-RunLog 'Custom CMD' 'OK' $cmd } catch { Write-Host $_ -ForegroundColor $Theme.Error; Log $_; Add-RunLog 'Custom CMD' 'ERR' $_.ToString() }
    Pause-Return
}

function A21-WingetUpdate {
    Header 'Atualizar programas (winget)'
    if (-not $Global:EnvInfo.HasWinget) { Write-Host 'winget nao encontrado.' -ForegroundColor $Theme.Warn; Add-RunLog 'winget update' 'ERR' 'sem winget'; Pause-Return; return }
    Log 'winget upgrade --all --silent'
    try {
        Show-ProgressBlock 'Atualizando via winget' { winget source update; winget upgrade --all --silent --include-unknown | Tee-Object -FilePath $global:LogFile -Append }
        Add-RunLog 'winget upgrade' 'OK' ''
    } catch { Write-Host 'Falha no winget.' -ForegroundColor $Theme.Error; Log $_; Add-RunLog 'winget upgrade' 'ERR' $_.ToString() }
    Pause-Return
}

function A22-ServicesQuickFix {
    Header 'Reiniciar servicos (BITS, WUAUSERV, DHCP, DNS)'
    $services = 'BITS','wuauserv','Dhcp','Dnscache'
    $i=0; foreach ($s in $services) { $i++; Write-Progress -Activity 'Reiniciando servicos' -Status $s -PercentComplete ($i*25); try { Restart-Service -Name $s -Force -ErrorAction SilentlyContinue; Write-Host ("Reiniciado: " + $s) -ForegroundColor $Theme.Accent; Log ("Restart " + $s); Add-RunLog 'Svc Restart' 'OK' $s } catch { Log $_ } }
    Write-Progress -Activity 'Reiniciando servicos' -Completed
    Pause-Return
}

function A23-NetworkInfo { Header 'Informacoes de Rede'; ipconfig /all | Tee-Object -FilePath $global:LogFile -Append; Get-NetAdapter | Sort-Object Status -Descending | Format-Table -AutoSize; Get-NetIPAddress | Sort-Object InterfaceAlias | Format-Table -AutoSize; Add-RunLog 'Net Info' 'OK' ''; Pause-Return }

function A24-StorageHealth {
    Header 'Saude do Armazenamento'
    try { Get-PhysicalDisk | Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus, Size | Format-Table -AutoSize; Add-RunLog 'Storage Health' 'OK' '' } catch { Write-Host 'Recurso indisponivel nesta edicao.' -ForegroundColor $Theme.Warn; Add-RunLog 'Storage Health' 'WARN' 'sem suporte' }
    Pause-Return
}

function A25-StartupApps { Header 'Apps de Inicializacao'; try { Get-CimInstance Win32_StartupCommand | Select-Object Name, Location, Command | Format-Table -Wrap; Add-RunLog 'Startup Apps' 'OK' '' } catch { Add-RunLog 'Startup Apps' 'ERR' $_.ToString() }; Pause-Return }

function A26-RemoveBloatApps {
    Header 'Remover Apps preinstalados (Windows 11)'
    Write-Host 'Remove apps para usuarios atuais e provisionados (novos usuarios).' -ForegroundColor $Theme.Warn
    if (Confirm-UX 'Criar ponto de restauracao antes?') { try { Checkpoint-Computer -Description 'Before RemoveBloatApps' -RestorePointType 'MODIFY_SETTINGS' } catch { Log $_ } }
    Write-Host ''
    Write-Host '1) Remover conjunto recomendado (SAFE)' -ForegroundColor $Theme.Accent
    Write-Host '2) Selecionar manualmente apps para remover' -ForegroundColor $Theme.Accent
    Write-Host '3) Remover Microsoft Teams (consumer) via winget' -ForegroundColor $Theme.Accent
    Write-Host '0) Voltar' -ForegroundColor Yellow
    $sel = Read-Host 'Escolha (0-3)'
    switch ($sel) {
        '1' {
            $patterns = @('Microsoft.3DBuilder*','Microsoft.3DViewer*','Microsoft.BingNews*','Microsoft.BingWeather*','Microsoft.GetHelp*','Microsoft.Getstarted*','Microsoft.MicrosoftOfficeHub*','Microsoft.MicrosoftSolitaireCollection*','Microsoft.MixedReality.Portal*','Microsoft.OneConnect*','Microsoft.People*','Microsoft.SkypeApp*','Microsoft.Wallet*','Microsoft.Whiteboard*','Microsoft.Xbox*','Microsoft.ZuneMusic*','Microsoft.ZuneVideo*','Microsoft.Clipchamp*','Microsoft.549981C3F5F10*')
            $total = $patterns.Count; $i=0
            foreach ($pat in $patterns) {
                $i++; Write-Progress -Activity 'Removendo Apps SAFE' -Status $pat -PercentComplete ([int](($i/$total)*100))
                Get-AppxPackage -AllUsers -Name $pat | ForEach-Object { try { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue; Log ('Removed Appx: ' + $_.PackageFullName) } catch { Log $_ } }
                Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $pat } | ForEach-Object { try { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName | Out-Null; Log ('Removed Provisioned: ' + $_.PackageName) } catch { Log $_ } }
            }
            Write-Progress -Activity 'Removendo Apps SAFE' -Completed
            Add-RunLog 'Remove Bloat (SAFE)' 'OK' 'lista padrao'
            Pause-Return
        }
        '2' {
            $apps = Get-AppxPackage -AllUsers | Sort-Object Name | Select-Object Name, PackageFullName -Unique
            $names = $apps.Name | Sort-Object -Unique
            if (-not $names -or $names.Count -eq 0) { Write-Host 'Nenhum appx encontrado.' -ForegroundColor $Theme.Warn; Pause-Return; break }
            if (Get-Command Out-GridView -ErrorAction SilentlyContinue) {
                $picked = $names | Out-GridView -Title 'Selecione (multi-selecao) e clique OK' -OutputMode Multiple
            } else {
                Write-Host 'Apps encontrados (digite numeros separados por virgula):' -ForegroundColor $Theme.Warn
                for ($i=0; $i -lt $names.Count; $i++) { '{0,3}) {1}' -f ($i+1), $names[$i] | Write-Host }
                $pick = Read-Host 'Sua selecao (ex: 1,5,12)'
                $idxs = $pick -split '[^0-9]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ - 1 } | Where-Object { $_ -ge 0 -and $_ -lt $names.Count }
                $picked = @(); foreach ($id in $idxs) { $picked += $names[$id] }
            }
            $picked = $picked | Sort-Object -Unique
            foreach ($name in $picked) {
                Write-Host ('Removendo: ' + $name) -ForegroundColor Cyan
                Get-AppxPackage -AllUsers -Name $name | ForEach-Object { try { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue; Log ('Removed Appx: ' + $_.PackageFullName) } catch { Log $_ } }
                Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $name } | ForEach-Object { try { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName | Out-Null; Log ('Removed Provisioned: ' + $_.PackageName) } catch { Log $_ } }
            }
            Add-RunLog 'Remove Bloat (manual)' 'OK' (($picked -join ', '))
            Pause-Return
        }
        '3' { if ($Global:EnvInfo.HasWinget) { try { winget uninstall Microsoft.Teams --silent --accept-source-agreements --accept-package-agreements; Add-RunLog 'Remove Teams' 'OK' '' } catch { Add-RunLog 'Remove Teams' 'ERR' $_.ToString() } } else { Write-Host 'winget nao encontrado.' -ForegroundColor $Theme.Warn; Add-RunLog 'Remove Teams' 'ERR' 'sem winget' }; Pause-Return }
        default { }
    }
}

function A27-DiagnosticPack {
    Header 'Pacote de Diagnostico (ZIP no Desktop)'
    $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
    $outRoot = Join-Path $env:PUBLIC ('APSupport-Diagnostic-' + $ts)
    $null = New-Item -ItemType Directory -Path $outRoot -Force -ErrorAction SilentlyContinue
    Log ('Diagnostic root: ' + $outRoot)
    try { systeminfo > (Join-Path $outRoot 'systeminfo.txt') } catch {}
    try { ipconfig /all > (Join-Path $outRoot 'ipconfig_all.txt') } catch {}
    try { Get-ComputerInfo | Out-File -FilePath (Join-Path $outRoot 'computerinfo.txt') -Width 500 } catch {}
    try { Get-EventLog -LogName System -Newest 500 | Export-Csv -Path (Join-Path $outRoot 'events_system_500.csv') -NoTypeInformation -Encoding UTF8 } catch {}
    try { Get-EventLog -LogName Application -Newest 500 | Export-Csv -Path (Join-Path $outRoot 'events_app_500.csv') -NoTypeInformation -Encoding UTF8 } catch {}
    try { Get-Process | Sort-Object CPU -Descending | Select-Object -First 50 | Format-Table -AutoSize | Out-String | Set-Content (Join-Path $outRoot 'top_processes.txt') } catch {}
    try { route print > (Join-Path $outRoot 'route_print.txt') } catch {}
    try { arp -a > (Join-Path $outRoot 'arp_a.txt') } catch {}
    try { netstat -ano > (Join-Path $outRoot 'netstat_ano.txt') } catch {}
    try { pnputil /enum-drivers > (Join-Path $outRoot 'drivers_enum.txt') } catch {}
    try { if ($Global:EnvInfo.HasWinget) { winget list > (Join-Path $outRoot 'winget_list.txt') } } catch {}
    try { Get-WindowsUpdateLog -LogPath (Join-Path $outRoot 'WindowsUpdate.log') } catch {}
    $zip = Join-Path ([Environment]::GetFolderPath('Desktop')) ('APSupport-Diagnostic-' + $ts + '.zip')
    try { if (Test-Path $zip) { Remove-Item $zip -Force }; Compress-Archive -Path (Join-Path $outRoot '*') -DestinationPath $zip -Force; Write-Host ('Pacote gerado: ' + $zip) -ForegroundColor $Theme.Accent; Add-RunLog 'Diagnostic Pack' 'OK' $zip } catch { Write-Host 'Falha ao compactar.' -ForegroundColor $Theme.Error; Add-RunLog 'Diagnostic Pack' 'ERR' $_.ToString() }
    Pause-Return
}

function A28-BrowserCleanup {
    Header 'Limpar caches (Edge/Chrome/Firefox)'
    if (-not (Confirm-UX 'Tem certeza que deseja LIMPAR caches? (Pode encerrar navegadores abertos)')) { return }
    $targets = @()
    $edge   = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Default'
    if (Test-Path $edge)   { $targets += @(Join-Path $edge 'Cache'; Join-Path $edge 'Code Cache'; Join-Path $edge 'GPUCache'; Join-Path $edge 'Service Worker\CacheStorage') }
    $chrome = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Default'
    if (Test-Path $chrome) { $targets += @(Join-Path $chrome 'Cache'; Join-Path $chrome 'Code Cache'; Join-Path $chrome 'GPUCache'; Join-Path $chrome 'Service Worker\CacheStorage') }
    $ffRoot = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles'
    if (Test-Path $ffRoot) { Get-ChildItem $ffRoot -Directory | ForEach-Object { $targets += @(Join-Path $_.FullName 'cache2'; Join-Path $_.FullName 'startupCache') } }
    foreach ($t in $targets | Select-Object -Unique) { try { if (Test-Path $t) { Write-Host ('Limpando: ' + $t) -ForegroundColor $Theme.Accent; Get-ChildItem -Path $t -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue } } catch { Log $_ } }
    Add-RunLog 'Browser Cleanup' 'OK' 'cache'
    Pause-Return
}
#endregion

#region Novas acoes (A29..A36)
function A29-ResetSpooler {
    Header 'Reset Spooler de Impressao'
    try {
        net stop spooler | Out-Null
        $path = Join-Path $env:SystemRoot 'System32\spool\PRINTERS'
        if (Test-Path $path) { Get-ChildItem $path -Force | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue }
        net start spooler | Out-Null
        Write-Host 'Spooler reiniciado e fila limpa.' -ForegroundColor $Theme.Accent
        Add-RunLog 'Reset Spooler' 'OK' $path
    } catch { Add-RunLog 'Reset Spooler' 'ERR' $_.ToString() }
    Pause-Return
}

function A30-ReinstallStore {
    Header 'Reinstalar Microsoft Store (UWP base)'
    try {
        Get-AppxPackage -AllUsers Microsoft.WindowsStore | ForEach-Object { Add-AppxPackage -DisableDevelopmentMode -Register ($_.InstallLocation + '\AppxManifest.xml') }
        Write-Host 'Tentativa de reinstalar a Store concluida.' -ForegroundColor $Theme.Accent
        Add-RunLog 'Reinstall Store' 'OK' ''
    } catch { Write-Host 'Falha ao reinstalar Store.' -ForegroundColor $Theme.Warn; Add-RunLog 'Reinstall Store' 'ERR' $_.ToString() }
    Pause-Return
}

function A31-NICToggle {
    Header 'Desabilitar/Habilitar Adaptador de Rede'
    $adapters = Get-NetAdapter | Sort-Object Name
    if (-not $adapters) { Write-Host 'Nenhum adaptador encontrado.' -ForegroundColor $Theme.Warn; Pause-Return; return }
    if (Get-Command Out-GridView -ErrorAction SilentlyContinue) {
        $sel = $adapters | Select-Object Name, Status, InterfaceDescription | Out-GridView -Title 'Selecione adaptador' -OutputMode Single
    } else {
        for($i=0;$i -lt $adapters.Count;$i++){ '{0,2}) {1} [{2}]' -f ($i+1), $adapters[$i].Name, $adapters[$i].Status | Write-Host }
        $num = Read-Host 'Numero'
        if ($num -notmatch '^\d+$') { return }
        $sel = $adapters[[int]$num - 1]
    }
    if (-not $sel) { return }
    $act = Read-Host 'Digite OFF para desabilitar ou ON para habilitar'
    try {
        if ($act -match '^(off|OFF)$') { Disable-NetAdapter -Name $sel.Name -Confirm:$false; Add-RunLog 'NIC' 'OK' ('Disable ' + $sel.Name) }
        elseif ($act -match '^(on|ON)$') { Enable-NetAdapter  -Name $sel.Name -Confirm:$false; Add-RunLog 'NIC' 'OK' ('Enable ' + $sel.Name) }
    } catch { Add-RunLog 'NIC' 'ERR' $_.ToString() }
    Pause-Return
}

function A32-BrowserCleanupAdvanced {
    Header 'Limpeza AVANCADA de navegadores'
    $incCookies = Confirm-UX 'Incluir COOKIES? (encerra navegadores)'
    $incHistory = Confirm-UX 'Incluir HISTORICO? (encerra navegadores)'
    $procs = 'msedge','chrome','firefox'
    foreach ($p in $procs) { Get-Process $p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
    A28-BrowserCleanup
    if ($incCookies -or $incHistory) {
        try {
            $edge = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Default'
            $chrome = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Default'
            $ffRoot = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles'
            if ($incCookies) {
                foreach ($p in @($edge,$chrome)) { $f = Join-Path $p 'Network\Cookies'; if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue } }
                if (Test-Path $ffRoot) { Get-ChildItem $ffRoot -Directory | ForEach-Object { $f = Join-Path $_.FullName 'cookies.sqlite'; if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue } } }
            }
            if ($incHistory) {
                foreach ($p in @($edge,$chrome)) { $f = Join-Path $p 'History'; if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue } }
                if (Test-Path $ffRoot) { Get-ChildItem $ffRoot -Directory | ForEach-Object { $f = Join-Path $_.FullName 'places.sqlite'; if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue } } }
            }
            Add-RunLog 'Browser Advanced' 'OK' ('cookies=' + $incCookies + '; history=' + $incHistory)
        } catch { Add-RunLog 'Browser Advanced' 'ERR' $_.ToString() }
    }
    Pause-Return
}

function A33-WingetExport {
    Header 'Export baseline (winget export)'
    if (-not $Global:EnvInfo.HasWinget) { Write-Host 'winget nao encontrado.' -ForegroundColor $Theme.Warn; Add-RunLog 'winget export' 'ERR' 'sem winget'; Pause-Return; return }
    $dest = Read-Host 'Caminho do arquivo JSON (ex: C:\Temp\baseline.json)'
    if ([string]::IsNullOrWhiteSpace($dest)) { return }
    try { winget export "$dest" --accept-source-agreements; Write-Host ('Exportado para ' + $dest) -ForegroundColor $Theme.Accent; Add-RunLog 'winget export' 'OK' $dest } catch { Add-RunLog 'winget export' 'ERR' $_.ToString() }
    Pause-Return
}

function A34-WingetImport {
    Header 'Import baseline (winget import)'
    if (-not $Global:EnvInfo.HasWinget) { Write-Host 'winget nao encontrado.' -ForegroundColor $Theme.Warn; Add-RunLog 'winget import' 'ERR' 'sem winget'; Pause-Return; return }
    $src = Read-Host 'Caminho do baseline JSON'
    if (-not (Test-Path $src)) { Write-Host 'Arquivo nao encontrado.' -ForegroundColor $Theme.Error; Pause-Return; return }
    try { winget import "$src" --silent --accept-source-agreements --accept-package-agreements | Tee-Object -FilePath $global:LogFile -Append; Add-RunLog 'winget import' 'OK' $src } catch { Add-RunLog 'winget import' 'ERR' $_.ToString() }
    Pause-Return
}

function A35-RegistryBackup {
    Header 'Backup do Registro (HKLM/HKCU)'
    $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
    $outDir = Join-Path $env:PUBLIC ('APSupport-RegistryBackup-' + $ts)
    $null = New-Item -ItemType Directory -Path $outDir -Force -ErrorAction SilentlyContinue
    Write-Host ('Destino: ' + $outDir) -ForegroundColor $Theme.Accent
    try {
        reg export HKLM\SOFTWARE (Join-Path $outDir 'HKLM_SOFTWARE.reg') /y | Out-Null
        reg export HKLM\SYSTEM   (Join-Path $outDir 'HKLM_SYSTEM.reg') /y   | Out-Null
        reg export HKCU\Software (Join-Path $outDir 'HKCU_Software.reg') /y | Out-Null
        $zip = Join-Path ([Environment]::GetFolderPath('Desktop')) ('RegistryBackup-' + $ts + '.zip')
        if (Test-Path $zip) { Remove-Item $zip -Force }
        Compress-Archive -Path (Join-Path $outDir '*') -DestinationPath $zip -Force
        Write-Host ('Backup gerado: ' + $zip) -ForegroundColor $Theme.Accent
        Add-RunLog 'Registry Backup' 'OK' $zip
    } catch { Write-Host 'Falha no backup do Registro.' -ForegroundColor $Theme.Error; Add-RunLog 'Registry Backup' 'ERR' $_.ToString() }
    Pause-Return
}

function A36-ThemeProfile { Set-ThemeAndProfile }
#endregion

#region Menu / UI
$MenuItems = @(
    @{ Id=1;  Title='Verificar/Agendar CHKDSK';          Action={ A01-ChkDsk } },
    @{ Id=2;  Title='Reparar Arquivos de Sistema (SFC)';  Action={ A02-SFC } },
    @{ Id=3;  Title='Limpar Temporarios (+WU opcional)';  Action={ A03-CleanupTemp } },
    @{ Id=4;  Title='Diagnostico de Memoria (mdsched)';   Action={ A04-MemDiag } },
    @{ Id=5;  Title='Restaurar Sistema';                  Action={ A05-RestoreSystem } },
    @{ Id=6;  Title='Teste de Conectividade (Ping/Tracert)'; Action={ A06-NetworkTest } },
    @{ Id=7;  Title='Gerenciador de Tarefas';             Action={ A07-TaskManager } },
    @{ Id=8;  Title='Backup de Drivers (pnputil)';        Action={ A08-BackupDrivers } },
    @{ Id=9;  Title='Gerar WindowsUpdate.log';            Action={ A09-WindowsUpdateLog } },
    @{ Id=10; Title='Informacoes do Sistema';             Action={ A10-SystemInfo } },
    @{ Id=11; Title='Limpar Cache DNS (+renew)';          Action={ A11-FlushDNS } },
    @{ Id=12; Title='Reiniciar Pilha de Rede';            Action={ A12-NetworkReset } },
    @{ Id=13; Title='Desfragmentar Disco (HDD)';          Action={ A13-Defrag } },
    @{ Id=14; Title='Gerenciar Usuarios Locais';          Action={ A14-LocalUsers } },
    @{ Id=15; Title='DISM /RestoreHealth (+SFC no Completo)'; Action={ A15-DISM } },
    @{ Id=16; Title='Ativar/Desativar Firewall';          Action={ A16-FirewallToggle } },
    @{ Id=17; Title='Visualizador de Eventos';            Action={ A17-EventViewer } },
    @{ Id=18; Title='Teste de Disco (winsat)';            Action={ A18-DiskSpeed } },
    @{ Id=19; Title='Criar Ponto de Restauracao';         Action={ A19-RestorePoint } },
    @{ Id=20; Title='Executar Comando Personalizado';     Action={ A20-CustomCMD } },
    @{ Id=21; Title='Atualizar Programas (winget)';       Action={ A21-WingetUpdate } },
    @{ Id=22; Title='Reiniciar Servicos (BITS/WUAUSERV/DHCP/DNS)'; Action={ A22-ServicesQuickFix } },
    @{ Id=23; Title='Informacoes de Rede';                Action={ A23-NetworkInfo } },
    @{ Id=24; Title='Saude do Armazenamento';             Action={ A24-StorageHealth } },
    @{ Id=25; Title='Apps de Inicializacao';              Action={ A25-StartupApps } },
    @{ Id=26; Title='Remover Apps preinstalados (Win11)'; Action={ A26-RemoveBloatApps } },
    @{ Id=27; Title='Pacote de Diagnostico (ZIP)';        Action={ A27-DiagnosticPack } },
    @{ Id=28; Title='Limpar caches de navegadores';       Action={ A28-BrowserCleanup } },
    @{ Id=29; Title='Reset Spooler de Impressao';         Action={ A29-ResetSpooler } },
    @{ Id=30; Title='Reinstalar Microsoft Store';         Action={ A30-ReinstallStore } },
    @{ Id=31; Title='NIC: Desabilitar/Habilitar adaptador'; Action={ A31-NICToggle } },
    @{ Id=32; Title='Limpeza AVANCADA navegadores';       Action={ A32-BrowserCleanupAdvanced } },
    @{ Id=33; Title='Winget: Export baseline';            Action={ A33-WingetExport } },
    @{ Id=34; Title='Winget: Import baseline';            Action={ A34-WingetImport } },
    @{ Id=35; Title='Backup do Registro (HKLM/HKCU)';     Action={ A35-RegistryBackup } },
    @{ Id=36; Title='Trocar Tema/Perfil (persistente)';   Action={ A36-ThemeProfile } }
)

function Menu-Grid([array]$Items) {
    if (Get-Command Out-GridView -ErrorAction SilentlyContinue) {
        try { $sel = $Items | Select-Object Id, Title | Out-GridView -Title 'Menu - Allan Pablo (selecione e clique OK)' -OutputMode Single -PassThru; if ($sel) { return $sel.Id } else { return $null } } catch { return $null }
    } else { return $null }
}

function Show-Menu {
    Header $null
    foreach ($m in $MenuItems) { Write-Host ("{0,2}. {1}" -f $m.Id, $m.Title) -ForegroundColor $Theme.Accent }
    Write-Host ' 0. Sair' -ForegroundColor Yellow
}

while ($true) {
    $chosenId = Menu-Grid -Items $MenuItems
    if (-not $chosenId) {
        Show-Menu
        $input = Read-Host "`nEscolha uma opcao (0-36)"
        if ($input -eq '0') { break }
        if ($input -notmatch '^\d+$') { Write-Host 'Opcao invalida.' -ForegroundColor $Theme.Error; Start-Sleep -Milliseconds 800; continue }
        $chosenId = [int]$input
    } elseif ($chosenId -eq 0) { break }

    $item = $MenuItems | Where-Object { $_.Id -eq $chosenId } | Select-Object -First 1
    if ($null -eq $item) { Write-Host 'Opcao invalida.' -ForegroundColor $Theme.Error; Start-Sleep -Milliseconds 800; continue }

    & $item.Action
}

# Ao sair, gera relatorio
Generate-Report
Write-Host 'Ate logo!' -ForegroundColor $Theme.Banner
#endregion
