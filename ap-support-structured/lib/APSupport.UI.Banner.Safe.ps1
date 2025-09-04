
# lib/APSupport.UI.Banner.Safe.ps1
# Header() seguro para PS 5.1 (sem [char]*[int]) e com fallback ASCII.
# Substitui o Header do script principal quando dot-sourced.

function Get-BoxCharset {
    param([switch]$Ascii)
    if ($Ascii) {
        return @{ TL='+'; TR='+'; BL='+'; BR='+'; H='='; V='|'; ML='+'; MR='+'; MH='-' }
    }
    try {
        return @{
            TL=[char]0x2554; TR=[char]0x2557; BL=[char]0x255A; BR=[char]0x255D;
            H=[char]0x2550;  V=[char]0x2551;  ML=[char]0x255F; MR=[char]0x2562; MH=[char]0x2500
        }
    } catch {
        return @{ TL='+'; TR='+'; BL='+'; BR='+'; H='='; V='|'; ML='+'; MR='+'; MH='-' }
    }
}

function Format-Right([string]$left,[string]$right,[int]$width) {
    $maxLeft = [Math]::Max(0, $width - $right.Length - 1)
    if ($left.Length -gt $maxLeft) { $left = $left.Substring(0, $maxLeft) }
    $spaces = [Math]::Max(1, $width - $left.Length - $right.Length)
    return ($left + (' ' * $spaces) + $right)
}

function New-Badge([string]$label,[string]$fg='Black',[string]$bg='DarkCyan') {
    try { Write-Host -NoNewline (' [' + $label + '] ') -ForegroundColor $fg -BackgroundColor $bg }
    catch { Write-Host -NoNewline (' [' + $label + '] ') }
}

function Header($title) {
    Clear-Host
    $ascii = $false
    try { $null = [Console]::OutputEncoding } catch { $ascii = $true }
    $cs = Get-BoxCharset -Ascii:$ascii

    $winW  = $Host.UI.RawUI.WindowSize.Width
    $innerW = [Math]::Min([Math]::Max(60, $winW - 6), 110)

    # Barras repetidas (PS 5.1-safe)
    $hbarTop = New-Object string ($cs.H,  ($innerW + 2))
    $mhbar   = New-Object string ($cs.MH, ($innerW + 2))
    $hbarBot = New-Object string ($cs.H,  ($innerW + 2))

    $top    = ("{0}{1}{2}" -f $cs.TL, $hbarTop, $cs.TR)
    $sep    = ("{0}{1}{2}" -f $cs.ML, $mhbar,   $cs.MR)
    $bottom = ("{0}{1}{2}" -f $cs.BL, $hbarBot, $cs.BR)

    $ver = 'v3.0.1'

    $titleLeft = 'APSupport - Menu de Suporte e Reparo'
    if (-not $ascii) { $titleLeft = 'APSupport ' + [char]0x2022 + ' Menu de Suporte e Reparo' }
    $line1 = Format-Right $titleLeft $ver $innerW

    $sub  = if ($title) { ':: ' + $title } else { '' }
    $op   = $(if ($Global:Operator) { $Global:Operator } else { 'N/A' })
    $themeName = $(if ($ThemeName) { $ThemeName } else { 'default' })
    $meta1 = ('Operador: {0}    Perfil: {1}    Tema: {2}' -f $op, $Global:ProfileMode, $themeName)
    $meta2 = ('Log: {0}' -f $global:LogFile)

    Write-Host $top -ForegroundColor $Theme.Border
    Write-Host ($cs.V + ' ' + $line1.PadRight($innerW) + ' ' + $cs.V) -ForegroundColor $Theme.Banner
    Write-Host $sep -ForegroundColor $Theme.Border
    if ($sub) { Write-Host ($cs.V + ' ' + $sub.PadRight($innerW) + ' ' + $cs.V) -ForegroundColor $Theme.Warn }
    Write-Host ($cs.V + ' ' + $meta1.PadRight($innerW) + ' ' + $cs.V) -ForegroundColor $Theme.Text
    Write-Host ($cs.V + ' ' + $meta2.PadRight($innerW) + ' ' + $cs.V) -ForegroundColor DarkGray

    Write-Host ($cs.V + ' ') -NoNewline -ForegroundColor $Theme.Border
    New-Badge 'ADMIN' 'White' 'DarkGreen'
    New-Badge 'VERBOSE ON' 'Black' 'Yellow'
    New-Badge 'PS 5.1' 'White' 'DarkBlue'
    $wu = if ($Global:EnvInfo.WU_Running) { 'WU: Running' } else { 'WU: Stopped' }
    $wuBg = if ($Global:EnvInfo.WU_Running) { 'DarkGreen' } else { 'DarkRed' }
    New-Badge $wu 'White' $wuBg
    $curr = [Console]::CursorLeft
    $remain = [Math]::Max(0, ($innerW + 3) - $curr)
    Write-Host (' ' * $remain) -NoNewline
    Write-Host $cs.V -ForegroundColor $Theme.Border

    Write-Host $bottom -ForegroundColor $Theme.Border
    Write-Host
}
