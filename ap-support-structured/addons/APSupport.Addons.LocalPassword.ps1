
# addons/APSupport.Addons.LocalPassword.ps1
# A47 - Reset de senha de conta LOCAL (não-AD)

function Get-LocalUsersCompat {
    try {
        return Get-LocalUser | Where-Object { -not $_.Disabled } | Select-Object -ExpandProperty Name
    } catch {
        $out = (net user) -join "`n"
        $lines = $out -split "`n"
        $names = @()
        $collect = $false
        foreach ($ln in $lines) {
            if ($ln -match '---') { $collect = -not $collect; continue }
            if ($collect) {
                $parts = $ln -split '\s+' | Where-Object { $_ -and $_ -notmatch 'A conta de comandos NET' }
                $names += $parts
            }
        }
        return $names | Where-Object { $_ -and $_ -notmatch 'O comando foi concluido com exito' }
    }
}

function A47-LocalPasswordReset {
    Header 'Reset de Senha - Conta LOCAL (nao-AD)'
    Write-Host 'ATENCAO: Nao afeta contas de dominio/AD. Para AD use ADUC/RSAT.' -ForegroundColor $Theme.Warn

    $users = Get-LocalUsersCompat
    if (-not $users -or $users.Count -eq 0) { Write-Host 'Nenhum usuario local encontrado.' -ForegroundColor $Theme.Warn; Pause-Return; return }

    if (Get-Command Out-GridView -ErrorAction SilentlyContinue) {
        $user = $users | Sort-Object | Out-GridView -Title 'Selecione a conta local' -OutputMode Single
    } else {
        for ($i=0; $i -lt $users.Count; $i++) { "{0,2}) {1}" -f ($i+1), $users[$i] | Write-Host }
        $idx = Read-Host 'Numero'
        if ($idx -notmatch '^\d+$') { return }
        $user = $users[[int]$idx - 1]
    }
    if (-not $user) { return }

    $p1 = Read-Host ("Nova senha para '" + $user + "'") -AsSecureString
    $p2 = Read-Host 'Confirmar nova senha' -AsSecureString
    if ( [Runtime.InteropServices.Marshal]::PtrToStringAuto( [Runtime.InteropServices.Marshal]::SecureStringToBSTR($p1) ) -ne
         [Runtime.InteropServices.Marshal]::PtrToStringAuto( [Runtime.InteropServices.Marshal]::SecureStringToBSTR($p2) ) ) {
        Write-Host 'Senhas nao conferem.' -ForegroundColor $Theme.Error; Pause-Return; return
    }

    try {
        try {
            $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto( [Runtime.InteropServices.Marshal]::SecureStringToBSTR($p1) )
            $sec   = ConvertTo-SecureString $plain -AsPlainText -Force
            Set-LocalUser -Name $user -Password $sec
            Add-RunLog 'LocalPasswordReset' 'OK' ('Set-LocalUser ' + $user)
        } catch {
            $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto( [Runtime.InteropServices.Marshal]::SecureStringToBSTR($p1) )
            Invoke-RunAndLog ('net user "' + $user + '" "' + $plain + '"') 'LocalPasswordReset' -AppendLog
        }
        Write-Host ('Senha redefinida para ' + $user + '.') -ForegroundColor $Theme.Accent
    } catch {
        Write-Host ('Falha ao redefinir senha: ' + $_.Exception.Message) -ForegroundColor $Theme.Error
        Add-RunLog 'LocalPasswordReset' 'ERR' $_.Exception.Message
    }
    Pause-Return
}
