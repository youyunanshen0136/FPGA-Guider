`timescale 1ns/1ps
module tb_distance_buzzer;
reg clk=0;always #500 clk=~clk;
reg reset=1,echo=0,echo_enabled=1;
integer pulse_us=3000;
wire trig,buzzer,stby;
line_ultrasonic_stop_top #(.CLK_HZ(1000000),.BUTTON_CYCLES(2),
 .US_PERIOD_US(10000),.US_MAX_ECHO_US(5000),.MAX_RUN_CYCLES(64'd2000000)) dut(
 .clk(clk),.reset_button(reset),.start_button(1'b0),.stop_button(1'b0),
 .gray(5'b00100),.us_echo(echo),.estop_n(1'b1),.help_btn_n(1'b1),.esp_rx(1'b1),
 .enc_lf_a(1'b0),.enc_lf_b(1'b0),.enc_lr_a(1'b0),.enc_lr_b(1'b0),
 .enc_rf_a(1'b0),.enc_rf_b(1'b0),.enc_rr_a(1'b0),.enc_rr_b(1'b0),
 .us_trig(trig),.buzzer_drv(buzzer),.motor_stby(stby));
always @(posedge trig) if(echo_enabled) begin
 #100000;echo=1;#(pulse_us*1000);echo=0;
end
task ms(input integer n);begin repeat(n*1000) @(negedge clk);end endtask
always @(negedge clk) if(stby) $fatal(1,"motor started during stationary test");
initial begin
 ms(1);reset=0;ms(25);
 if(!dut.core.distance_valid || dut.core.distance<=400 || buzzer) $fatal(1,"far alarm");
 pulse_us=1167;ms(25);
 if(!dut.core.distance_valid || dut.core.distance>210 || !buzzer) $fatal(1,"20cm silent while idle");
 pulse_us=2333;ms(25);
 if(dut.core.distance!=400 || !buzzer) $fatal(1,"400mm boundary");
 pulse_us=2339;ms(25);
 if(dut.core.distance!=401 || buzzer) $fatal(1,"401mm boundary");
 pulse_us=1167;ms(25);if(!buzzer) $fatal(1,"return near silent");
 echo_enabled=0;ms(25);
 if(dut.core.distance_valid || buzzer) $fatal(1,"stale/invalid range kept alarm");
 echo_enabled=1;ms(25);if(!buzzer) $fatal(1,"echo recovery silent");
 reset=1;ms(1);if(buzzer) $fatal(1,"reset alarm");
 $display("PASS tb_distance_buzzer: stationary 20cm, 400/401mm boundary, far silent, invalid silent, recovery, reset, no motor start");
 $finish;
end
initial begin #300000000;$fatal(1,"watchdog");end
endmodule
