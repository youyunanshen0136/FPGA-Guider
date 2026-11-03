param([string]$VivadoBin='D:/vivado/Vivado/2024.1/bin')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
New-Item -ItemType Directory -Force -Path "$root/output","$root/reports" | Out-Null
Push-Location $root
try {
 & "$VivadoBin/vivado.bat" -mode batch -source scripts/build.tcl -log reports/build.log -journal reports/build.jou
 if($LASTEXITCODE -ne 0){throw 'Build failed; see reports/build.log'}
} finally {Pop-Location}
