# Build degree-exam application PDF (學位考試申請).
# Run: .\build_degree_exam.ps1
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Invoke-XeLaTeX {
    param([string]$File)
    xelatex -interaction=nonstopmode $File
    if ($LASTEXITCODE -ne 0) { throw "xelatex failed: $File" }
}

$coverSrc = Get-ChildItem -Path "doc" -Filter "01_*.pdf" | Select-Object -First 1
if (-not $coverSrc) {
    throw "Missing cover PDF in doc/ (expected doc/01_封面.pdf)"
}
Write-Host "==> cover: $($coverSrc.Name) -> merge_cover.pdf"
Copy-Item -Force $coverSrc.FullName "merge_cover.pdf"

Write-Host "==> thesis_02_title.tex"
Invoke-XeLaTeX "thesis_02_title.tex"
Invoke-XeLaTeX "thesis_02_title.tex"
Copy-Item -Force "thesis_02_title.pdf" "doc\02_title_page.pdf"

Write-Host "==> thesis_03_content.tex"
Copy-Item -Force "..\論文\references.bib" "references.bib"
Invoke-XeLaTeX "thesis_03_content.tex"
bibtex thesis_03_content
if ($LASTEXITCODE -ne 0) { Write-Warning "bibtex returned $LASTEXITCODE (continuing)" }
Invoke-XeLaTeX "thesis_03_content.tex"
Invoke-XeLaTeX "thesis_03_content.tex"

Write-Host "==> merge_04_degree_exam.tex"
Invoke-XeLaTeX "merge_04_degree_exam.tex"
Invoke-XeLaTeX "merge_04_degree_exam.tex"

Copy-Item -Force "merge_04_degree_exam.pdf" "degree_exam_submit.pdf"
Write-Host "Done: merge_04_degree_exam.pdf (copy: degree_exam_submit.pdf)"
