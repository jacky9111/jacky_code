# Build slim thesis PDF:
#   doc/01_封面.pdf + English Abstract + Chapters 1--7 + Bibliography
# Run: .\build_en_slim.ps1
# Output: thesis_en_slim_full.pdf  (and <姓名>_<學號>_en_slim.pdf)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Invoke-XeLaTeX {
    param([string]$File)
    xelatex -interaction=nonstopmode $File
    if ($LASTEXITCODE -ne 0) { throw "xelatex failed: $File" }
}

$vars = Get-Content "ntuvars.tex" -Raw -Encoding UTF8
$author = "thesis"
$studentId = "000000000"
if ($vars -match '\\authorCH\{([^}]+)\}') { $author = $Matches[1] }
if ($vars -match '\\studentID\{([^}]+)\}') { $studentId = $Matches[1] }
$outName = "${author}_${studentId}_en_slim.pdf"

$coverSrc = Get-ChildItem -Path "doc" -Filter "01_*.pdf" | Select-Object -First 1
if (-not $coverSrc) { throw "Missing doc/01_封面.pdf" }
Write-Host "==> cover: $($coverSrc.Name)"
Copy-Item -Force $coverSrc.FullName "merge_cover.pdf"

Write-Host "==> thesis_en_slim.tex"
$sourceDir = Get-ChildItem -Path ".." -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName "main.tex") } |
    Select-Object -First 1
if (-not $sourceDir) { throw "Missing source thesis directory" }
$referencesSrc = Join-Path $sourceDir.FullName "references.bib"
if (-not (Test-Path $referencesSrc)) { throw "Missing source references.bib" }
Copy-Item -LiteralPath $referencesSrc -Destination (Join-Path $PWD "references.bib") -Force
Invoke-XeLaTeX "thesis_en_slim.tex"
bibtex thesis_en_slim
if ($LASTEXITCODE -ne 0) { Write-Warning "bibtex returned $LASTEXITCODE (continuing)" }
Invoke-XeLaTeX "thesis_en_slim.tex"
Invoke-XeLaTeX "thesis_en_slim.tex"

Write-Host "==> merge_en_slim.tex"
Invoke-XeLaTeX "merge_en_slim.tex"

Copy-Item -Force "merge_en_slim.pdf" "thesis_en_slim_full.pdf"
Copy-Item -Force "merge_en_slim.pdf" $outName
Write-Host "Done: thesis_en_slim_full.pdf (copy: $outName)"
