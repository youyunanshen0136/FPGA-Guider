set root [file dirname [file dirname [file normalize [info script]]]]
connect
targets -set -filter {name =~ "*Cortex-A9*#0"}
rst -system
after 500
targets -set -filter {name =~ "*Cortex-A9*#0"}
stop
targets -set -filter {name =~ "*Cortex-A9*#1"}
stop
targets -set -filter {name == "APU"}
source [file join $root output ps7_init.tcl]
ps7_init
ps7_post_config
puts PS_CLOCK_STARTED
disconnect
exit
