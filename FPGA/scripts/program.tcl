set root [file dirname [file dirname [file normalize [info script]]]]
open_hw_manager
connect_hw_server
open_hw_target
set devs [get_hw_devices -filter {PART =~ xc7z020*}]
if {[llength $devs]!=1} {error "Expected one xc7z020"}
set dev [lindex $devs 0]
set_property PROGRAM.FILE [file join $root output car_zebra_sequence.bit] $dev
set_property PROBES.FILE [file join $root output car_zebra_sequence.ltx] $dev
program_hw_devices $dev
puts "BIT_PROGRAMMED"
