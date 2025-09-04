
# addons/APSupport.Addons.Register.ps1
# Registra os add-ons no $MenuItems, evitando duplicatas e preservando IDs.

function Register-APSupportAddons {
    param([ref]$MenuItemsRef)

    $items = @()

    if (Get-Command A37-WU-ForceCycle -ErrorAction SilentlyContinue) {
        $items += @{ Id=37; Title='WU: Forcar Scan/Download/Install'; Action={ A37-WU-ForceCycle } }
    }
    if (Get-Command A38-WU-ResetComponents -ErrorAction SilentlyContinue) {
        $items += @{ Id=38; Title='WU: Reset de Componentes (safe)'; Action={ A38-WU-ResetComponents } }
    }
    if (Get-Command A39-GPUpdate -ErrorAction SilentlyContinue) {
        $items += @{ Id=39; Title='GPUpdate: Forcar (+GPResult)'; Action={ A39-GPUpdate } }
    }
    if (Get-Command A40-WU-RunTasksOnly -ErrorAction SilentlyContinue) {
        $items += @{ Id=40; Title='WU: Rodar Tarefas Agendadas'; Action={ A40-WU-RunTasksOnly } }
    }
    if (Get-Command A41-Spooler-Advanced -ErrorAction SilentlyContinue) {
        $items += @{ Id=41; Title='Spooler: Reset AVANCADO'; Action={ A41-Spooler-Advanced } }
    }
    if (Get-Command A42-Store-WSReset -ErrorAction SilentlyContinue) {
        $items += @{ Id=42; Title='Store: WSReset (+Re-Register)'; Action={ A42-Store-WSReset } }
    }
    if (Get-Command A43-Proxy-WinHttp-Reset -ErrorAction SilentlyContinue) {
        $items += @{ Id=43; Title='Proxy WinHTTP: Show/Reset/Import'; Action={ A43-Proxy-WinHttp-Reset } }
    }
    if (Get-Command A44-Time-Resync -ErrorAction SilentlyContinue) {
        $items += @{ Id=44; Title='Hora: Resync (w32tm)'; Action={ A44-Time-Resync } }
    }
    if (Get-Command A45-Audio-Restart -ErrorAction SilentlyContinue) {
        $items += @{ Id=45; Title='Audio: Reiniciar servicos'; Action={ A45-Audio-Restart } }
    }
    if (Get-Command A46-Explorer-Restart -ErrorAction SilentlyContinue) {
        $items += @{ Id=46; Title='Explorer: Reiniciar Shell'; Action={ A46-Explorer-Restart } }
    }
    if (Get-Command A47-LocalPasswordReset -ErrorAction SilentlyContinue) {
        $items += @{ Id=47; Title='Senha LOCAL: Reset (nao-AD)'; Action={ A47-LocalPasswordReset } }
    }

    if ($null -eq $MenuItemsRef.Value) { $MenuItemsRef.Value = @() }
    $existingIds = @($MenuItemsRef.Value | ForEach-Object { $_.Id })
    foreach ($i in $items) {
        if (-not ($existingIds -contains $i.Id)) {
            $MenuItemsRef.Value += $i
        }
    }
    $MenuItemsRef.Value = $MenuItemsRef.Value | Sort-Object Id
}
