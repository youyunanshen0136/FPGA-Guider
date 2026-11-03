set root [file dirname [file dirname [file normalize [info script]]]]
source [file join $root scripts source_files.tcl]
set_param board.repoPaths [list [file join $root board_files]]
create_project -force car_psclock [file join $root build project] -part xc7z020clg400-1
set_property board_part tul.com.tw:pynq-z2:part0:1.0 [current_project]
set_param general.maxThreads 2
add_files $rtlSources
add_files [file join $root src car_bd_shell.v]
create_bd_design clock_system
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} [get_bd_cells ps7]
set_property -dict [list CONFIG.PCW_USE_M_AXI_GP0 0 CONFIG.PCW_EN_CLK0_PORT 1 CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ 125.000000] [get_bd_cells ps7]
create_bd_cell -type module -reference car_bd_shell car
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins car/clk]
source [file join $root scripts ports.tcl]
foreach name $externalPorts {
 make_bd_pins_external [get_bd_pins car/$name]
 set_property name $name [get_bd_ports ${name}_0]
}
validate_bd_design
save_bd_design
set bd [get_files clock_system.bd]
set_property synth_checkpoint_mode None $bd
generate_target all $bd
set wrapper [make_wrapper -files $bd -top]
add_files $wrapper
read_xdc [file join $root constraints line_straight.xdc]
set_property top clock_system_wrapper [current_fileset]
update_compile_order -fileset sources_1
synth_design -top clock_system_wrapper -part xc7z020clg400-1 -flatten_hierarchy none
write_checkpoint -force [file join $root output synthesized.dcp]
set sysclk [get_clocks -of_objects [get_pins clock_system_i/car/clk]]
if {![llength $sysclk]} {error "PS FCLK0 timing clock not found"}
set_clock_groups -asynchronous -group $sysclk -group [get_clocks camera_pclk]
create_debug_core stability_ila ila
set_property C_DATA_DEPTH 1024 [get_debug_cores stability_ila]
connect_debug_port stability_ila/clk [get_nets clock_system_i/ps7_FCLK_CLK0]
set index 0
foreach spec {{vision/configured 1} {vision/failed 1} {camera_live 1} {camera_green 1} {vision/display/locked 1} {reset_n 1} {core/enabled 1} {core/motor_allow 1} {core/distance_valid 1} {core/distance 16} {speech/clear_armed 1} {voice_gpio 6}} {
 lassign $spec name width
 if {$index>0} {create_debug_port stability_ila probe}
 set port stability_ila/probe$index
 set_property port_width $width [get_debug_ports $port]
 set nets {}
 if {$width==1} {set nets [get_nets clock_system_i/car/inst/car_logic/$name]} else {
  for {set bit 0} {$bit<$width} {incr bit} {lappend nets [get_nets [format {clock_system_i/car/inst/car_logic/%s[%d]} $name $bit]]}
 }
 if {[llength $nets]!=$width} {error "Missing debug net: $name"}
 connect_debug_port $port $nets
 incr index
}
opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force [file join $root output car_zebra_sequence.dcp]
report_timing_summary -file [file join $root reports timing_summary.rpt]
report_drc -file [file join $root reports drc.rpt]
report_cdc -details -file [file join $root reports cdc.rpt]
report_utilization -file [file join $root reports utilization.rpt]
foreach delay {max min} {
 set p [get_timing_paths -delay_type $delay -max_paths 1]
 if {![llength $p] || [get_property SLACK $p]<0} {error "Timing failed: $delay"}
}
if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error}]]} {error "DRC failed"}
write_bitstream -force [file join $root output car_zebra_sequence.bit]
write_debug_probes -force [file join $root output car_zebra_sequence.ltx]
set initfiles [glob -nocomplain [file join $root build project car_psclock.gen sources_1 bd clock_system ip *ps7* ps7_init.tcl]]
if {[llength $initfiles]!=1} {error "PS clock initialization script not found"}
file copy -force [lindex $initfiles 0] [file join $root output ps7_init.tcl]
puts PS_CLOCK_BUILD_COMPLETE
