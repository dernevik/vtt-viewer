param(
  [Parameter(Mandatory = $true)][string]$Path,             # .vtt input
  [string]$Fixture = '',                                   # fixture title to render (exact match)
  [ValidateSet('html','md')][string]$Format = 'html',      # output format
  [switch]$EmitVttx                                        # stop after extractor emits the intermediate XML
)
$ErrorActionPreference = 'Stop'

# ---------- resolve paths ----------
$src = (Resolve-Path -LiteralPath $Path).Path
$dir = Split-Path $src -Parent
[Environment]::CurrentDirectory = $dir

$extractXsl = 'C:\Scripts\VttTools\vtest-extract.xsl'
$renderXsl  = if ($Format -eq 'md') {
  'C:\Scripts\VttTools\vttx-to-markdown.xsl'
} else {
  'C:\Scripts\VttTools\vttx-to-html.xsl'
}
if (-not (Test-Path $extractXsl)) { throw "Extractor XSL not found: $extractXsl" }
if (-not (Test-Path $renderXsl))  { throw "Renderer XSL not found:  $renderXsl"  }

$intPath = Join-Path $dir ([IO.Path]::GetFileNameWithoutExtension($src) + '_intermediate.xml')
$outExt  = if ($Format -eq 'md') { '.md' } else { '.html' }
$safeFx  = if ($Fixture) { ($Fixture -replace '[^\w\-]+','_') } else { '' }
$outPath = Join-Path $dir (
  [IO.Path]::GetFileNameWithoutExtension($src) + ($(if($safeFx){"_$safeFx"}else{""})) + $outExt
)

# ---------- hardened XSLT settings ----------
$xsltSettings = New-Object System.Xml.Xsl.XsltSettings($false, $false)  # no document(), no script
$nullResolver = $null                                                   # no external fetches
$readerSettings = New-Object System.Xml.XmlReaderSettings
$readerSettings.DtdProcessing    = 'Prohibit'
$readerSettings.IgnoreWhitespace = $false
$readerSettings.XmlResolver      = $null

# ---------- compile helper ----------
function Compile-Xslt([string]$xslPath) {
  $x = New-Object System.Xml.Xsl.XslCompiledTransform($true)
  try {
    $x.Load($xslPath, $xsltSettings, $nullResolver)
    return $x
    } catch {
      $e  = $_.Exception
      $xe = if ($e.InnerException) { $e.InnerException } else { $e }
      Write-Host ("XSLT load error in {0}: {1}" -f $xslPath, $xe.Message) -ForegroundColor Red
      if ($xe -is [System.Xml.Xsl.XsltException]) {
        Write-Host ("URI: {0}`nLine: {1}  Col: {2}" -f $xe.SourceUri, $xe.LineNumber, $xe.LinePosition) -ForegroundColor Yellow
      }
      throw
    }

}

# ---------- 1) extract ----------
$extractor = Compile-Xslt $extractXsl
$inReader  = [System.Xml.XmlReader]::Create($src, $readerSettings)
$intWriter = [System.Xml.XmlWriter]::Create($intPath, (New-Object System.Xml.XmlWriterSettings -Property @{ Indent = $true; Encoding = [Text.UTF8Encoding]::new($false) }))

try {
  $extractor.Transform($inReader, $null, $intWriter)
} finally {
  if ($intWriter) { $intWriter.Close() }
  if ($inReader)  { $inReader.Close()  }
}

if ($EmitVttx) {
  Write-Host "Wrote $intPath" -ForegroundColor Green
  return
}

# ---------- 2) render ----------
$renderer  = Compile-Xslt $renderXsl
$intReader = [System.Xml.XmlReader]::Create($intPath, $readerSettings)
$outWriter = New-Object System.IO.StreamWriter($outPath, $false, [System.Text.Encoding]::UTF8)

$renderArgs = New-Object System.Xml.Xsl.XsltArgumentList
if ($Fixture) { $renderArgs.AddParam('fixture','', $Fixture) }

try {
  # correct 3-arg overload: (XmlReader, XsltArgumentList, TextWriter)
  $renderer.Transform($intReader, $renderArgs, $outWriter)
} catch {
  $e  = $_.Exception
  $xe = if ($e.InnerException) { $e.InnerException } else { $e }
  Write-Host ("Transform error in {0}: {1}" -f $xslPath, $xe.Message) -ForegroundColor Red
  if ($xe -is [System.Xml.Xsl.XsltException]) {
    Write-Host ("URI: {0}`nLine: {1}  Col: {2}" -f $xe.SourceUri, $xe.LineNumber, $xe.LinePosition) -ForegroundColor Yellow
  }
  throw
} finally {
  if ($outWriter) { $outWriter.Close() }
  if ($intReader) { $intReader.Close() }
}

Write-Host "Wrote $outPath" -ForegroundColor Green
if ($Format -eq 'html') { Start-Process $outPath }
