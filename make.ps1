param([Parameter(Position=0)][string]$Target = "render")

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Render {
    python scripts/render.py
    if ($LASTEXITCODE -ne 0) { throw "render failed" }
}

switch ($Target) {
    "render" { Render }
    "evidence" {
        Render
        $pack = "dist/evidence-pack"
        if (Test-Path $pack) { Remove-Item $pack -Recurse -Force }
        New-Item -ItemType Directory -Path $pack -Force | Out-Null
        Copy-Item docs/threat-model-v* $pack -ErrorAction SilentlyContinue
        Copy-Item compliance/CIS.md, compliance/poam.md $pack -ErrorAction SilentlyContinue
        Copy-Item detections $pack -Recurse -ErrorAction SilentlyContinue
        Copy-Item evidence/M6 $pack -Recurse -ErrorAction SilentlyContinue
        Compress-Archive -Path $pack -DestinationPath dist/evidence-pack.zip -Force
        Write-Host "built dist/evidence-pack.zip"
    }
    "clean" { Remove-Item dist -Recurse -Force -ErrorAction SilentlyContinue }
    default { Write-Host "Usage: ./make.ps1 render | evidence | clean" }
}