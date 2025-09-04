
# lib/APSupport.Menu.Grouping.ps1
# Agrupa e ordena o menu por seções sem alterar seus IDs/ações.

$Global:MenuGroupOrder = @(
  'Diagnostico & Reparos',
  'Rede & Update',
  'Disco & Armazenamento',
  'Apps, Store & Winget',
  'Usuarios & Seguranca',
  'Impressao',
  'Interface & Utilidades',
  'Outros'
)

function Get-MenuGroup([int]$id) {
  switch ($id) {
    {$_ -in 2,4,5,9,10,15,17,19} { return 'Diagnostico & Reparos' }
    {$_ -in 6,11,12,22,23,31,37,38,39,40,43,44} { return 'Rede & Update' }
    {$_ -in 1,8,13,18,24,27,35} { return 'Disco & Armazenamento' }
    {$_ -in 21,25,26,28,30,32,33,34,42} { return 'Apps, Store & Winget' }
    {$_ -in 14,16,47} { return 'Usuarios & Seguranca' }
    {$_ -in 29,41} { return 'Impressao' }
    {$_ -in 7,20,36,45,46} { return 'Interface & Utilidades' }
    default { return 'Outros' }
  }
}

function Get-MenuItemsOrdered {
  # Cria a lista com o campo Group calculado e remove duplicatas por Id
  $list = @(
    $MenuItems | ForEach-Object {
      [pscustomobject]@{
        Id     = [int]$_.Id
        Title  = $_.Title
        Action = $_.Action
        Group  = Get-MenuGroup([int]$_.Id)
      }
    }
  ) | Sort-Object Id -Unique

  # Ordena por ordem de grupo definida + Id
  $list = $list | Sort-Object `
    @{ Expression = { [array]::IndexOf($Global:MenuGroupOrder, $_.Group) } }, `
    @{ Expression = { $_.Id } }

  return $list
}

function Menu-Grid([array]$Items) {
  $ordered = Get-MenuItemsOrdered
  if (Get-Command Out-GridView -ErrorAction SilentlyContinue) {
    try {
      $sel = $ordered | Select-Object Id, Group, Title |
        Out-GridView -Title 'Menu - APSupport (selecione e clique OK)' -OutputMode Single
      if ($sel) { return $sel.Id } else { return $null }
    } catch { return $null }
  } else {
    return $null
  }
}

function Show-Menu {
  Header $null
  $ordered = Get-MenuItemsOrdered
  $lastGroup = $null

  foreach ($m in $ordered) {
    if ($m.Group -ne $lastGroup) {
      if ($lastGroup) { Write-Host '' }
      Write-Host ('-- ' + $m.Group + ' --') -ForegroundColor $Theme.Accent
      $lastGroup = $m.Group
    }
    Write-Host ("{0,2}. {1}" -f $m.Id, $m.Title) -ForegroundColor $Theme.Text
  }
  Write-Host ' 0. Sair' -ForegroundColor Yellow
}
