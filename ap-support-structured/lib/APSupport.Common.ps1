
# lib/APSupport.Common.ps1
# Helpers genéricos. Pensado para PS 5.1. Carregado cedo no pipeline.

# Define apenas se não existir (evita conflitos com o seu script principal)
if (-not (Get-Command Invoke-RunAndLog -ErrorAction SilentlyContinue)) {
    function Invoke-RunAndLog {
        param(
            [Parameter(Mandatory=$true)][string]$CommandLine,
            [string]$Action='cmd',
            [switch]$AppendLog
        )
        try {
            if ($AppendLog) {
                cmd.exe /c $CommandLine 2>&1 | Tee-Object -FilePath $global:LogFile -Append
            } else {
                cmd.exe /c $CommandLine 2>&1 | Tee-Object -FilePath $global:LogFile -Append | Out-Null
            }
            if (Get-Command Add-RunLog -ErrorAction SilentlyContinue) {
                Add-RunLog $Action 'OK' $CommandLine
            }
        } catch {
            if (Get-Command Add-RunLog -ErrorAction SilentlyContinue) {
                Add-RunLog $Action 'ERR' ($CommandLine + ' :: ' + $_.Exception.Message)
            }
        }
    }
}
