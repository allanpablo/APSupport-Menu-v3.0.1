
# addons/APSupport.Addons.GPUpdate.ps1
# A39 - GPUpdate + GPResult

function A39-GPUpdate {
    Header 'Forcar atualizacao de Diretivas (gpupdate)'
    Write-Host '1) Computador+Usuario (padrao)' -ForegroundColor $Theme.Text
    Write-Host '2) Somente Computador' -ForegroundColor $Theme.Text
    Write-Host '3) Somente Usuario' -ForegroundColor $Theme.Text
    $sel = Read-Host 'Opcao (1-3; ENTER=1)'; if ([string]::IsNullOrWhiteSpace($sel)) { $sel = '1' }

    $args = '/force /wait:60'
    switch ($sel) { '2' { $args = '/target:computer /force /wait:60' } '3' { $args = '/target:user /force /wait:60' } }

    if (Confirm-UX 'Reiniciar automaticamente se necessario? (/boot)') { $args += ' /boot' }
    if (Confirm-UX 'Encerrar sessao se necessario? (/logoff)')           { $args += ' /logoff' }

    try {
        Show-ProgressBlock ('gpupdate ' + $args) { gpupdate.exe $args 2>&1 | Tee-Object -FilePath $global:LogFile -Append }
        Add-RunLog 'GPUpdate' 'OK' $args
    } catch { Write-Host ('Falha no gpupdate: ' + $_.Exception.Message) -ForegroundColor $Theme.Error; Add-RunLog 'GPUpdate' 'ERR' $_.Exception.Message }

    if (Confirm-UX 'Gerar GPResult (HTML) no Desktop?') {
        try {
            $out = Join-Path ([Environment]::GetFolderPath('Desktop')) ('GPResult-' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.html')
            gpresult.exe /h "$out" /f 2>&1 | Tee-Object -FilePath $global:LogFile -Append
            Write-Host ('Gerado: ' + $out) -ForegroundColor $Theme.Accent
            Add-RunLog 'GPResult' 'OK' $out
        } catch { Add-RunLog 'GPResult' 'ERR' $_.Exception.Message }
    }
    Pause-Return
}
