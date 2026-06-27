# Preview bilingual abstract only.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

xelatex -interaction=nonstopmode abstract_preview.tex
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

xelatex -interaction=nonstopmode abstract_preview.tex
exit $LASTEXITCODE
