module car_bd_shell(input wire clk,input wire reset_button,input wire start_button,input wire stop_button,
 input wire [4:0] gray,input wire us_echo,input wire estop_n,input wire help_btn_n,
 input wire enc_lf_a,input wire enc_lf_b,input wire enc_lr_a,input wire enc_lr_b,
 input wire enc_rf_a,input wire enc_rf_b,input wire enc_rr_a,input wire enc_rr_b,
 input wire esp_rx,output wire esp_tx,
 output wire us_trig,output wire motor_left_pwm,output wire motor_left_in1,output wire motor_left_in2,
 output wire motor_right_pwm,output wire motor_right_in1,output wire motor_right_in2,
 output wire motor_stby,output wire buzzer_drv,output wire status_led,
 output wire motor_left_rear_pwm,output wire motor_left_rear_in1,output wire motor_left_rear_in2,
 output wire motor_right_rear_pwm,output wire motor_right_rear_in1,output wire motor_right_rear_in2,
 output wire [2:0] line_led,
 input wire cam_pclk,input wire [7:0] cam_data,input wire cam_href,cam_vsync,
 inout wire cam_scl,cam_sda,output wire cam_reset_n,
 (* X_INTERFACE_IGNORE="TRUE" *) output wire hdmi_out_clk_p,hdmi_out_clk_n,
 output wire [2:0] hdmi_out_data_p,hdmi_out_data_n,output wire [5:0] voice_gpio);
line_ultrasonic_stop_top car_logic(.voice_gpio(voice_gpio),.clk(clk),.reset_button(reset_button),.start_button(start_button),.stop_button(stop_button),.gray(gray),.us_echo(us_echo),.estop_n(estop_n),.help_btn_n(help_btn_n),.enc_lf_a(enc_lf_a),.enc_lf_b(enc_lf_b),.enc_lr_a(enc_lr_a),.enc_lr_b(enc_lr_b),.enc_rf_a(enc_rf_a),.enc_rf_b(enc_rf_b),.enc_rr_a(enc_rr_a),.enc_rr_b(enc_rr_b),.esp_rx(esp_rx),.esp_tx(esp_tx),.us_trig(us_trig),.motor_left_pwm(motor_left_pwm),.motor_left_in1(motor_left_in1),.motor_left_in2(motor_left_in2),.motor_right_pwm(motor_right_pwm),.motor_right_in1(motor_right_in1),.motor_right_in2(motor_right_in2),.motor_stby(motor_stby),.buzzer_drv(buzzer_drv),.status_led(status_led),.motor_left_rear_pwm(motor_left_rear_pwm),.motor_left_rear_in1(motor_left_rear_in1),.motor_left_rear_in2(motor_left_rear_in2),.motor_right_rear_pwm(motor_right_rear_pwm),.motor_right_rear_in1(motor_right_rear_in1),.motor_right_rear_in2(motor_right_rear_in2),.line_led(line_led),.cam_pclk(cam_pclk),.cam_data(cam_data),.cam_href(cam_href),.cam_vsync(cam_vsync),.cam_scl(cam_scl),.cam_sda(cam_sda),.cam_reset_n(cam_reset_n),.hdmi_out_clk_p(hdmi_out_clk_p),.hdmi_out_clk_n(hdmi_out_clk_n),.hdmi_out_data_p(hdmi_out_data_p),.hdmi_out_data_n(hdmi_out_data_n));
endmodule
