
# addons/APSupport.Addons.Network.ps1
# A43, A44 - Proxy WinHTTP e Sincronizar Hora

function A43-Proxy-WinHttp-Reset {
    Header 'Proxy WinHTTP - exibir e resetar'
    try { Invoke-RunAndLog 'netsh winhttp show proxy' 'WinHTTP-Proxy' -AppendLog } catch {}
    if (Confirm-UX 'Resetar proxy WinHTTP para DIRECT?') {
        Invoke-RunAndLog 'netsh winhttp reset proxy' 'WinHTTP-Proxy-Reset' -AppendLog
    }
    if (Confirm-UX 'Importar proxy do IE/Edge para WinHTTP?') {
        Invoke-RunAndLog 'netsh winhttp import proxy source=ie' 'WinHTTP-Proxy-Import' -AppendLog
    }
    Pause-Return
}

function A44-Time-Resync {
    Header 'Sincronizar Hora (w32time)'
    if (Confirm-UX 'Reiniciar servico de hora?') { try { net stop w32time | Out-Null; net start w32time | Out-Null } catch {} }
    if (Confirm-UX 'Deseja especificar servidor NTP (ex: time.windows.com)?') {
        $ntp = Read-Host 'Servidor NTP'; if ($ntp) {
            try { w32tm /config /manualpeerlist:$ntp /syncfromflags:manual /update 2>&1 | Tee-Object -FilePath $global:LogFile -Append } catch {}
        }
    }
    try { w32tm /resync /force 2>&1 | Tee-Object -FilePath $global:LogFile -Append; Add-RunLog 'Time-Resync' 'OK' '' } catch { Add-RunLog 'Time-Resync' 'ERR' $_.Exception.Message }
    Pause-Return
}
