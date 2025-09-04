
# addons/APSupport.Addons.WU.ps1
# A37, A38, A40 - Windows Update

function A37-WU-ForceCycle {
    Header 'Forcar Windows Update (scan/download/install)'
    try {
        $svcs = 'bits','wuauserv','cryptsvc'
        foreach ($s in $svcs) {
            try { $svc = Get-Service -Name $s -ErrorAction SilentlyContinue; if ($svc -and $svc.Status -ne 'Running') { Start-Service $s -ErrorAction SilentlyContinue } ; Add-RunLog 'WU-Svc' 'OK' ('ensure ' + $s) } catch { Add-RunLog 'WU-Svc' 'WARN' ('falha ao iniciar ' + $s) }
        }

        if (Confirm-UX 'RESET LEVE do Windows Update (renomear SoftwareDistribution/Catroot2)?') {
            foreach ($s in $svcs) { try { Stop-Service $s -Force -ErrorAction SilentlyContinue } catch {} }
            $sd = Join-Path $env:SystemRoot 'SoftwareDistribution'
            $cr = Join-Path $env:SystemRoot 'System32\catroot2'
            $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
            try { if (Test-Path $sd) { Rename-Item $sd ($sd + '.bak.' + $ts) -Force } } catch { Add-RunLog 'WU-Reset' 'WARN' ('rename SD: ' + $_.Exception.Message) }
            try { if (Test-Path $cr) { Rename-Item $cr ($cr + '.bak.' + $ts) -Force } } catch { Add-RunLog 'WU-Reset' 'WARN' ('rename catroot2: ' + $_.Exception.Message) }
            foreach ($s in $svcs) { try { Start-Service $s -ErrorAction SilentlyContinue } catch {} }
            Add-RunLog 'WU-Reset' 'OK' 'reset leve concluido'
        }

        $uso = Join-Path $env:SystemRoot 'System32\UsoClient.exe'
        if (Test-Path $uso) {
            Show-ProgressBlock 'Windows Update (UsoClient)' {
                & $uso StartScan      2>&1 | Tee-Object -FilePath $global:LogFile -Append
                & $uso StartDownload  2>&1 | Tee-Object -FilePath $global:LogFile -Append
                & $uso StartInstall   2>&1 | Tee-Object -FilePath $global:LogFile -Append
            }
            Add-RunLog 'WU-UsoClient' 'OK' 'Scan/Download/Install'
        } else {
            Invoke-RunAndLog 'wuauclt /resetauthorization /detectnow' 'WU-wuauclt'
            Invoke-RunAndLog 'wuauclt /reportnow' 'WU-wuauclt'
        }

        $tasks = @(
            '\Microsoft\Windows\UpdateOrchestrator\Schedule Scan',
            '\Microsoft\Windows\WindowsUpdate\Scheduled Start',
            '\Microsoft\Windows\WindowsUpdate\Automatic App Update',
            '\Microsoft\Windows\InstallService\ScanForUpdates'
        )
        foreach ($t in $tasks) { try { schtasks /Run /TN "$t" 2>&1 | Tee-Object -FilePath $global:LogFile -Append; Add-RunLog 'WU-Task' 'OK' $t } catch { Add-RunLog 'WU-Task' 'WARN' ('falha ' + $t) } }

        Write-Host 'Ciclo do Windows Update acionado.' -ForegroundColor $Theme.Accent
    } catch {
        Write-Host ('Falha ao forcar WU: ' + $_.Exception.Message) -ForegroundColor $Theme.Error
        Add-RunLog 'WU-ForceCycle' 'ERR' $_.Exception.Message
    }
    Pause-Return
}

function A38-WU-ResetComponents {
    Header 'Reset de Componentes do Windows Update'
    if (-not (Confirm-UX 'Confirmar reset de componentes do WU?')) { return }
    try {
        $svcs = 'bits','wuauserv','cryptsvc'
        foreach ($s in $svcs) { try { Stop-Service $s -Force -ErrorAction SilentlyContinue } catch {} }

        $sd = Join-Path $env:SystemRoot 'SoftwareDistribution'
        $cr = Join-Path $env:SystemRoot 'System32\catroot2'
        $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
        try { if (Test-Path $sd) { Rename-Item $sd ($sd + '.bak.' + $ts) -Force } } catch { Add-RunLog 'WU-Reset' 'WARN' ('rename SD: ' + $_.Exception.Message) }
        try { if (Test-Path $cr) { Rename-Item $cr ($cr + '.bak.' + $ts) -Force } } catch { Add-RunLog 'WU-Reset' 'WARN' ('rename catroot2: ' + $_.Exception.Message) }

        try { bitsadmin /reset /allusers 2>&1 | Tee-Object -FilePath $global:LogFile -Append } catch {}

        foreach ($s in $svcs) { try { Start-Service $s -ErrorAction SilentlyContinue } catch {} }
        Add-RunLog 'WU-ResetComponents' 'OK' 'SD/Catroot2 renomeados, servicos reiniciados'

        if (Confirm-UX 'Deseja iniciar varredura de atualizacoes agora?') { A37-WU-ForceCycle }
        else { Write-Host 'Reset concluido.' -ForegroundColor $Theme.Accent }
    } catch {
        Write-Host ('Falha no reset: ' + $_.Exception.Message) -ForegroundColor $Theme.Error
        Add-RunLog 'WU-ResetComponents' 'ERR' $_.Exception.Message
    }
    Pause-Return
}

function A40-WU-RunTasksOnly {
    Header 'Acionar tarefas do Windows Update'
    $tasks = @(
        '\Microsoft\Windows\UpdateOrchestrator\Schedule Scan',
        '\Microsoft\Windows\WindowsUpdate\Scheduled Start',
        '\Microsoft\Windows\WindowsUpdate\Automatic App Update',
        '\Microsoft\Windows\InstallService\ScanForUpdates',
        '\Microsoft\Windows\WindowsUpdate\AUSessionConnect'
    )
    foreach ($t in $tasks) { try { schtasks /Run /TN "$t" 2>&1 | Tee-Object -FilePath $global:LogFile -Append; Add-RunLog 'WU-Task' 'OK' $t } catch { Add-RunLog 'WU-Task' 'WARN' ('falha ' + $t) } }
    Write-Host 'Tarefas acionadas.' -ForegroundColor $Theme.Accent
    Pause-Return
}
