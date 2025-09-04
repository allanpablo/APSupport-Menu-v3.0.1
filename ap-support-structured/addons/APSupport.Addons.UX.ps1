
# addons/APSupport.Addons.UX.ps1
# A45, A46 - Audio e Explorer

function A45-Audio-Restart {
    Header 'Audio - Reiniciar servicos'
    $svcs = 'Audiosrv','AudioEndpointBuilder'
    foreach ($s in $svcs) {
        try { Restart-Service -Name $s -Force -ErrorAction SilentlyContinue; Add-RunLog 'AudioSvc' 'OK' ('restart ' + $s) } catch { Add-RunLog 'AudioSvc' 'WARN' ('falha ' + $s) }
    }
    Write-Host 'Servicos de audio reiniciados.' -ForegroundColor $Theme.Accent
    Pause-Return
}

function A46-Explorer-Restart {
    Header 'Explorer - Reiniciar shell'
    try {
        Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Process explorer.exe
        Add-RunLog 'Explorer-Restart' 'OK' ''
    } catch { Add-RunLog 'Explorer-Restart' 'ERR' $_.Exception.Message }
    Pause-Return
}
