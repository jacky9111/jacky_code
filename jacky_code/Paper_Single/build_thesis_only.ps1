# Build thesis PDF: cover + title page + body (no application attachments).
# Run: .\build_thesis_only.ps1
# Output: <姓名>_<學號>.pdf  (from ntuvars.tex)
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
$outName = "${author}_${studentId}.pdf"

$coverSrc = Get-ChildItem -Path "doc" -Filter "01_*.pdf" | Select-Object -First 1
if (-not $coverSrc) { throw "Missing doc/01_封面.pdf" }
Write-Host "==> cover: $($coverSrc.Name)"
Copy-Item -Force $coverSrc.FullName "merge_cover.pdf"

$titleSrc = Get-ChildItem -Path "doc" -Filter "02_*.pdf" | Select-Object -First 1
if (-not $titleSrc) {
    Write-Host "==> thesis_02_title.tex (doc/02_*.pdf not found)"
    Invoke-XeLaTeX "thesis_02_title.tex"
    Invoke-XeLaTeX "thesis_02_title.tex"
    New-Item -ItemType Directory -Force -Path "doc" | Out-Null
    Copy-Item -Force "thesis_02_title.pdf" "doc\02_title_page.pdf"
    $titleSrc = Get-Item "doc\02_title_page.pdf"
} else {
    Write-Host "==> title: $($titleSrc.Name)"
}
Copy-Item -Force $titleSrc.FullName "merge_title.pdf"

Write-Host "==> thesis_03_content.tex"
Copy-Item -Force "..\論文\references.bib" "references.bib"
Invoke-XeLaTeX "thesis_03_content.tex"
bibtex thesis_03_content
if ($LASTEXITCODE -ne 0) { Write-Warning "bibtex returned $LASTEXITCODE (continuing)" }
Invoke-XeLaTeX "thesis_03_content.tex"
Invoke-XeLaTeX "thesis_03_content.tex"

Write-Host "==> merge_thesis_only.tex"
Invoke-XeLaTeX "merge_thesis_only.tex"
Invoke-XeLaTeX "merge_thesis_only.tex"

Copy-Item -Force "merge_thesis_only.pdf" $outName
Write-Host "Done: merge_thesis_only.pdf (copy: $outName)"
