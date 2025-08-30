# vtt-viewer

Small utility to view Vector vTESTstudio “.vtt” files outside the tool.
Transforms .vtt into readable HTML or Markdown for code review (VS Code, Gerrit, GitHub).

## What this is
XSLT stylesheets plus a tiny PowerShell wrapper.
Outputs a readable listing of fixtures, preparation/steps/completion.
No dependencies on Vector tools at runtime (just Windows + PowerShell + .NET’s XSLT).

## Features
- Expands STATECHANGE / STATECHECK (IN / WAIT / EXPECTED)
- Renders AWAITVALUEMATCH, SET, DIAG
- Handles VARIABLES / VARIABLE_DEFINITION and ASSIGNMENT
- Covers OCCURRENCE_COUNT, CHECK_DEACTIVATION, NOVALUECHANGE
- Displays CAPLINLINE code blocks and external CAPL calls (notes path if present in the VTT)

## Install (Windows + PowerShell)
### Clone the repo (example path shown):
```
git clone https://github.com/dernevik/vtt-viewer.git C:\Repos\vtt-viewer
```

### Optional: create a junction so the tools are available under a stable path (example path shown):
```
if (Test-Path 'C:\Scripts\VttTools') { Rename-Item 'C:\Scripts\VttTools' 'C:\Scripts\VttTools.bak' -Force }
New-Item -ItemType Junction -Path 'C:\Scripts\VttTools' -Target 'C:\Repos\vtt-viewer\VttTools' | Out-Null
```
### Info: Uninstall / revert the junction:
```
Remove-Item 'C:\Scripts\VttTools' -Force      # removes junction only
# (optional) restore your backup if you created one earlier
Rename-Item 'C:\Scripts\VttTools.bak' 'C:\Scripts\VttTools'
```


Create C:\Scripts\Show-Vtt.ps1 with this content (example path):

```
param(
  [Parameter(Mandatory)][string]$Path,
  [string]$Fixture = "",
  [ValidateSet("html","md")][string]$Format = "html"
)

$xsl = if ($Format -eq 'md') { 'vtest-to-markdown.xsl' } else { 'vtest-to-html.xsl' }
$xslPath = Join-Path 'C:\Scripts\VttTools' $xsl

$xml = New-Object System.Xml.XmlDocument
$xml.Load((Resolve-Path $Path))

$xslt = New-Object System.Xml.Xsl.XslCompiledTransform
$xslt.Load($xslPath)

$args = New-Object System.Xml.Xsl.XsltArgumentList
if ($Fixture) { $args.AddParam('fixture','', $Fixture) }

$stem = [IO.Path]::GetFileNameWithoutExtension($Path)
$dir  = Split-Path -Parent $Path
$suffix = ($Fixture ? "_$($Fixture.Replace(' ','_'))" : "")
$out = Join-Path $dir ("{0}{1}.{2}" -f $stem,$suffix,$Format)

$enc = [System.Text.Encoding]::UTF8
$tw = New-Object System.IO.StreamWriter($out,$false,$enc)
$xslt.Transform($xml,$args,$tw)
$tw.Close()
Write-Host "Wrote $out"
```

It is practical to add an alias to your PowerShell profile:
```
notepad $PROFILE
```
(then add a line like below and save) (example path shown)

```
function vtt { param($Path, $Fixture, $Format='html'); & 'C:\Scripts\Show-Vtt.ps1' -Path $Path -Fixture $Fixture -Format $Format }
```
reload current session (or open a new terminal)
```
. $PROFILE
```

## Usage

### HTML for a specific fixture:
```
vtt .\<filename.vtt> -Fixture <fixture name>
```

### Markdown instead of HTML:
```
vtt .\<filename.vtt> -Fixture <fixture name> -Format md
```

### Fixture name with spaces:
If the fixture name contains spaces, quote it
```
vtt .\<filename.vtt> -Fixture "Power Sleep Management"
```

### List fixture titles in a .vtt
```
$ns = @{ tt = 'http://www.vector-informatik.de/ITE/TestTable/1.0' }
Select-Xml -Path .\your.vtt -XPath '//tt:tf/tt:title' -Namespace $ns |
  ForEach-Object { $_.Node.InnerText }
```

### Entire file (no fixture filter):
```
vtt .\<filename.vtt>
```
Or, Markdown
```
vtt .\<filename.vtt> -Format md
```

## Examples (included in this repo under examples/)
demo_generic_automotive.vtt (two fixtures to demo -Fixture)
```
vtt .\examples\demo_generic_automotive.vtt
vtt .\examples\demo_generic_automotive.vtt -Fixture Power_Sleep_Management
vtt .\examples\demo_generic_automotive.vtt -Fixture Diagnostics_And_Communication -Format md
```

## Line endings
This repo includes .gitattributes to keep endings consistent:
```
*.xsl text eol=lf
*.md text eol=lf
*.ps1 text eol=crlf
```

If Git warns about CRLF/LF on Windows, that’s normal. The repo stores LF for XSL/MD and CRLF for PS1.

## Execution policy
If PowerShell blocks the script (execution policy), run once as Admin:
```
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

## Disclaimer
This project is an independent utility provided “as is”, without warranty of any kind.

It is not affiliated with, endorsed by, or supported by Vector Informatik GmbH.

“Vector”, “vTESTstudio”, “CANoe”, and related names are trademarks of their respective owners.

Use at your own risk and ensure compliance with your organization’s policies and licenses.

## License
MIT

See LICENSE in the repository.