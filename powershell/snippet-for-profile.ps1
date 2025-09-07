function Show-Vtt {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [string]$Fixture = '',
    [ValidateSet('html','md')][string]$Format = 'html',
    [switch]$EmitVttx
  )

  # Splat only the parameters that are set
  $args = @{
    Path    = $Path
    Fixture = $Fixture
    Format  = $Format
  }
  if ($EmitVttx) { $args.EmitVttx = $true }

  & 'C:\Scripts\Show-Vtt.ps1' @args
}

Set-Alias vtt Show-Vtt

function Get-VttFixtures {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$Path
  )

  $ErrorActionPreference = 'Stop'

  # Run the extractor phase via Show-Vtt with -EmitVttx (no rendering)
  & "$PSScriptRoot\Show-Vtt.ps1" -Path $Path -EmitVttx | Out-Null

  # Locate the intermediate file right next to the input
  $full = (Resolve-Path -LiteralPath $Path).Path
  $dir  = Split-Path $full -Parent
  $stem = [IO.Path]::GetFileNameWithoutExtension($full)
  $int  = Join-Path $dir "${stem}_intermediate.xml"

  if (-not (Test-Path $int)) {
    Write-Error "Intermediate not found: $int"
    return
  }

  [xml]$x = Get-Content -Raw $int
  $ns = New-Object System.Xml.XmlNamespaceManager($x.NameTable)
  $ns.AddNamespace('v','urn:vttx:v0.1') | Out-Null

  function _walk([System.Xml.XmlElement]$node, [int]$level) {
    $indent = ' ' * ($level * 2)
    Write-Host "$indent- $($node.GetAttribute('title'))"
    foreach ($child in $node.SelectNodes('v:fixture',$ns)) { _walk $child ($level+1) }
  }

  foreach ($root in $x.SelectNodes('/v:vttx/v:fixture',$ns)) { _walk $root 0 }
}

Set-Alias vttf Get-VttFixtures