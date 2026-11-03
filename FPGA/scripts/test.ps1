param([string]$VivadoBin='E:/Xilinx/2026.1/Vivado/bin',
 [string[]]$Tests=@('tb_traffic','tb_color_gate','tb_traffic_car','tb_ultrasonic_guard','tb_ultrasonic_filter','tb_line_ultrasonic_stop','tb_distance_buzzer','tb_curve_equivalence','tb_web_telemetry','tb_rgb565_le','tb_car_voice','tb_voice','tb_zebra_sequence'))
$ErrorActionPreference='Stop'
if (-not $env:PROCESSOR_ARCHITECTURE -and [Environment]::Is64BitOperatingSystem) {
 $env:PROCESSOR_ARCHITECTURE='AMD64'
}
$root=Split-Path $PSScriptRoot
$sim=Join-Path $root 'build/sim'
New-Item -ItemType Directory -Force -Path $sim | Out-Null
$rtl=@((Get-ChildItem "$root/src/core/*.v").FullName)
$rtl+=@((Get-ChildItem "$root/src/camera/*.v").FullName)
$rtl+=Join-Path $root 'src/line_ultrasonic_stop_top.v'
$rtl+=Join-Path $root 'sim/reference/line_curve_controller_reference.v'
$benches=@((Get-ChildItem "$root/sim/*" -Include '*.v','*.sv').FullName)
Push-Location $sim
try {
 & "$VivadoBin/xvlog.bat" --sv @rtl @benches
 if($LASTEXITCODE){throw 'xvlog failed'}
 foreach($test in $tests){
  & "$VivadoBin/xelab.bat" $test -s $test
  if($LASTEXITCODE){throw "xelab failed: $test"}
  $log=Join-Path $root "reports/$test.log"
  & "$VivadoBin/xsim.bat" $test -runall -log $log
  if($LASTEXITCODE -or !(Select-String -Path $log -Pattern 'PASS' -Quiet) -or
     (Select-String -Path $log -Pattern 'Fatal:|Error:' -Quiet)) {throw "simulation failed: $test"}
 }
 Write-Output "ALL_TESTS_PASSED: $($Tests.Count)"
} finally {Pop-Location}
