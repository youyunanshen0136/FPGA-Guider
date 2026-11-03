param([string]$VivadoBin='D:/vivado/Vivado/2024.1/bin')
$ErrorActionPreference='Stop'
$env:PROCESSOR_ARCHITECTURE='AMD64'
$root=Split-Path $PSScriptRoot
Push-Location $root
try {
 & "$VivadoBin/xsdb.bat" scripts/start_ps_clock.tcl *> reports/ps_clock_init.log
 if(!(Select-String reports/ps_clock_init.log -Pattern '^PS_CLOCK_STARTED' -Quiet)){throw 'PS clock initialization failed; see reports/ps_clock_init.log'}
 & "$VivadoBin/vivado.bat" -mode batch -source scripts/program.tcl -log reports/program.log -journal reports/program.jou
 if($LASTEXITCODE -ne 0 -or !(Select-String reports/program.log -Pattern '^BIT_PROGRAMMED' -Quiet)){throw 'FPGA download failed'}
 & "$VivadoBin/vivado.bat" -mode batch -source scripts/capture_status.tcl -log reports/capture.log -journal reports/capture.jou -tclargs status_initial
 if($LASTEXITCODE -ne 0 -or !(Select-String reports/capture.log -Pattern '^PS_CLOCK_LIVE_CAPTURE_COMPLETE' -Quiet)){throw 'Runtime capture failed'}
 'PROGRAM_INIT_AND_CAPTURE_COMPLETE'
} finally {Pop-Location}
