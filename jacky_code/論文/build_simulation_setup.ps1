# Compile simulation_setup_table.tex (abstract + simulation table).
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

xelatex -interaction=nonstopmode simulation_setup_table.tex
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

xelatex -interaction=nonstopmode simulation_setup_table.tex
exit $LASTEXITCODE
