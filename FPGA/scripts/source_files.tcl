set projectRoot [file dirname [file dirname [file normalize [info script]]]]
set rtlSources {}
foreach name {reset_sync input_conditioner ultrasonic ultrasonic_guard line_curve_controller motor_driver encoder_reader speed_odometry alarm_output buzzer_driver uart_tx telemetry_tx car_curve_top} {
 lappend rtlSources [file join $projectRoot src core ${name}.v]
}
foreach name {dvp_rgb565_capture ov5640_frontend ov5640_init ov5640_reg_rom sccb_master traffic_light_detector traffic_color_gate traffic_camera} {
 lappend rtlSources [file join $projectRoot src camera ${name}.v]
}
lappend rtlSources [file join $projectRoot src line_ultrasonic_stop_top.v]
foreach path $rtlSources {
 if {![file isfile $path]} {error "Missing RTL: $path"}
}

lappend rtlSources [file join $projectRoot src video hdmi_preview.v]

lappend rtlSources [file join $projectRoot src core asrpro_events.v]
lappend rtlSources [file join $projectRoot src core car_voice_controller.v]
