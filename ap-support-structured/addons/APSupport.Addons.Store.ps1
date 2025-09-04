
# addons/APSupport.Addons.Store.ps1
# A42 - Store reset

function A42-Store-WSReset {
    Header 'Microsoft Store - WSReset'
    try { wsreset.exe 2>&1 | Tee-Object -FilePath $global:LogFile -Append; Add-RunLog 'WSReset' 'OK' 'wsreset.exe' } catch { Add-RunLog 'WSReset' 'ERR' $_.Exception.Message }
    if (Confirm-UX 'Tentar re-registrar a Store (Add-AppxPackage)?') {
        try { Get-AppxPackage -AllUsers Microsoft.WindowsStore | ForEach-Object { Add-AppxPackage -DisableDevelopmentMode -Register ($_.InstallLocation + '\AppxManifest.xml') }; Add-RunLog 'Store-ReRegister' 'OK' '' } catch { Add-RunLog 'Store-ReRegister' 'ERR' $_.Exception.Message }
    }
    Pause-Return
}
