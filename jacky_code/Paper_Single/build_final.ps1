# Build final submission PDF using 最終doc files + compiled thesis body.
# Run: .\build_final.ps1
# Output: 胡嘉祐_113522011.pdf
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
$outName = "${studentId}_${author}.pdf"

# Sync references.bib from 論文 folder
Copy-Item -Force "..\論文\references.bib" "references.bib"

# Compile thesis body
Write-Host "==> thesis_03_content.tex"
Invoke-XeLaTeX "thesis_03_content.tex"
bibtex thesis_03_content
if ($LASTEXITCODE -ne 0) { Write-Warning "bibtex returned $LASTEXITCODE (continuing)" }
Invoke-XeLaTeX "thesis_03_content.tex"
Invoke-XeLaTeX "thesis_03_content.tex"

# Merge with 最終doc files
Write-Host "==> merge_final.tex"
Invoke-XeLaTeX "merge_final.tex"

$finalDoc = "最終doc\${outName}"
Copy-Item -Force "merge_final.pdf" $outName
Copy-Item -Force "merge_final.pdf" $finalDoc
Write-Host "Done: $outName (also copied to 最終doc/$outName)"
