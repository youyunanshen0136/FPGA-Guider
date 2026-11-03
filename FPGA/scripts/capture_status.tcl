set root [file dirname [file dirname [file normalize [info script]]]]
open_hw_manager
connect_hw_server
open_hw_target
set dev [lindex [get_hw_devices -filter {PART =~ xc7z020*}] 0]
set_property PROBES.FILE [file join $root output car_zebra_sequence.ltx] $dev
current_hw_device $dev
refresh_hw_device $dev
set ilas [get_hw_ilas]
if {[llength $ilas]!=1} {error "Clock/debug core unavailable"}
set ila [lindex $ilas 0]
run_hw_ila -trigger_now $ila
wait_on_hw_ila -timeout 10 $ila
set data [upload_hw_ila_data $ila]
set name status
if {[llength $argv]} {set name [lindex $argv 0]}
write_hw_ila_data -force -csv_file [file join $root reports ${name}.csv] $data
puts "PS_CLOCK_LIVE_CAPTURE_COMPLETE $name"
