
# APSupport — Add-ons Modulares (v3.0.1)

## Estrutura
```
ap-support-structured/
├─ APSupport.Setup.Include.ps1          # inclui libs, add-ons e registra no menu
├─ lib/
│  ├─ APSupport.Common.ps1              # helpers (Invoke-RunAndLog)
│  ├─ APSupport.UI.Banner.Safe.ps1      # Header() seguro (Unicode/ASCII)
│  └─ APSupport.Menu.Grouping.ps1       # agrupamento e ordenação do menu
└─ addons/
   ├─ APSupport.Addons.WU.ps1           # A37, A38, A40 (Windows Update)
   ├─ APSupport.Addons.GPUpdate.ps1     # A39
   ├─ APSupport.Addons.Spooler.ps1      # A41
   ├─ APSupport.Addons.Store.ps1        # A42
   ├─ APSupport.Addons.Network.ps1      # A43, A44
   ├─ APSupport.Addons.UX.ps1           # A45, A46
   └─ APSupport.Addons.LocalPassword.ps1# A47
```

## Como integrar no seu script principal
No **final** do `Menu-Suporte-AllanPablo.ps1`, **antes do `while ($true)`**, adicione:
```powershell
. "$PSScriptRoot\APSupport.Setup.Include.ps1"
```

Isso vai:
1) Habilitar o **Header** “safe” (se quiser manter o seu, basta **comentar** a linha do `UI.Banner.Safe.ps1` dentro do `Setup.Include.ps1`).  
2) Aplicar **agrupamento** do menu por seções.  
3) Carregar todos os **add-ons** e **registrar** no `$MenuItems` sem duplicar IDs.

## Dicas
- Se quiser carregar só alguns add-ons, edite a lista `$toLoad` no `Setup.Include.ps1`.
- IDs e ações **não são sobrescritos**. Apenas adicionamos novas opções e reordenamos a exibição.
- Tudo é compatível com **PowerShell 5.1**.

Boa prática: salve seus `.ps1` como **UTF-8 com BOM**.
