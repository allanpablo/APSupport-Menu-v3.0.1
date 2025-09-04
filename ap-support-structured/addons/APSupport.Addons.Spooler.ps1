
# addons/APSupport.Addons.Spooler.ps1
# A41 - Spooler avançado

function A41-Spooler-Advanced {
    Header 'Spooler: Reset AVANCADO e diagnostico'
    if (-not (Confirm-UX 'Parar spooler, limpar fila e reiniciar?')) { return }
    try {
        net stop spooler   | Out-Null
        $path = Join-Path $env:SystemRoot 'System32\spool\PRINTERS'
        if (Test-Path $path) { Get-ChildItem $path -Force | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue }
        Get-Process 'PrintIsolationHost' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        net start spooler  | Out-Null
        Add-RunLog 'Spooler-Advanced' 'OK' $path
        Write-Host 'Spooler limpo e reiniciado.' -ForegroundColor $Theme.Accent
    } catch { Add-RunLog 'Spooler-Advanced' 'ERR' $_.Exception.Message }
    Pause-Return
}
