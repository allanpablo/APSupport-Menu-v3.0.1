
# APSupport.Setup.Include.ps1
# Inclui libs, add-ons e registra no menu (um-passo). Dot-source perto do final do script principal.

$root = $PSScriptRoot

$toLoad = @(
  'lib\APSupport.Common.ps1',
  'lib\APSupport.UI.Banner.Safe.ps1',
  'lib\APSupport.Menu.Grouping.ps1',
  'addons\APSupport.Addons.WU.ps1',
  'addons\APSupport.Addons.GPUpdate.ps1',
  'addons\APSupport.Addons.Spooler.ps1',
  'addons\APSupport.Addons.Store.ps1',
  'addons\APSupport.Addons.Network.ps1',
  'addons\APSupport.Addons.UX.ps1',
  'addons\APSupport.Addons.LocalPassword.ps1',
  'addons\APSupport.Addons.Register.ps1'
)

foreach ($rel in $toLoad) {
  $full = Join-Path $root $rel
  if (Test-Path $full) { . $full }
}

if ($null -eq $global:MenuItems) { $global:MenuItems = @() }
if (Get-Command Register-APSupportAddons -ErrorAction SilentlyContinue) {
  Register-APSupportAddons -MenuItemsRef ([ref]$global:MenuItems)
}
