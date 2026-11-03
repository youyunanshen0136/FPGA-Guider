`timescale 1ns/1ps
module tb_traffic_car;
 reg clk=0;always #500 clk=~clk;
 reg reset=1,start=0,stop=0,echo=0,green=0;
 reg [4:0] gray=5'b00100;
 integer pulse_us=2900;
 wire trig,stby,lp,rp,lrp,rrp,buzzer;
 tri1 scl,sda;
 line_ultrasonic_stop_top #(.CLK_HZ(1000000),.BUTTON_CYCLES(2),
  .US_PERIOD_US(10000),.US_MAX_ECHO_US(5000),.MAX_RUN_CYCLES(2000000),
  .TRAFFIC_STRAIGHT_CYCLES(150000)) dut(
  .clk(clk),.reset_button(reset),.start_button(start),.stop_button(stop),
  .gray(gray),.us_echo(echo),.estop_n(1'b1),.help_btn_n(1'b1),.esp_rx(1'b1),
  .enc_lf_a(1'b0),.enc_lf_b(1'b0),.enc_lr_a(1'b0),.enc_lr_b(1'b0),
  .enc_rf_a(1'b0),.enc_rf_b(1'b0),.enc_rr_a(1'b0),.enc_rr_b(1'b0),
  .us_trig(trig),.motor_stby(stby),.motor_left_pwm(lp),.motor_right_pwm(rp),
  .motor_left_rear_pwm(lrp),.motor_right_rear_pwm(rrp),.buzzer_drv(buzzer),
  .cam_pclk(clk),.cam_data(8'd0),.cam_href(1'b0),.cam_vsync(1'b1),
  .cam_scl(scl),.cam_sda(sda),.cam_reset_n());
 always @(posedge trig) begin
  #100000;echo=1;#(pulse_us*1000);echo=0;
 end
 task ms(input integer n);repeat(n*1000) @(negedge clk);endtask
 task press;begin start=1;repeat(20) @(negedge clk);start=0;repeat(20) @(negedge clk);end endtask
 task sample;begin @(posedge dut.core.us_done);repeat(3) @(negedge clk);end endtask
 task check(input bit ok,input string msg);
  if(!ok) $fatal(1,"%s phase=%0d timer=%0d stby=%b us_pause=%b",msg,dut.traffic_phase,dut.straight_timer,stby,dut.core.us_pause);
 endtask
 always @(negedge clk) begin
  #1; // Allow testbench input changes and combinational motor gates to settle.
  if(!reset) begin
  if(dut.traffic_active && (!green || dut.core.us_pause || dut.core.estop_latched))
   if(stby || lp || rp || lrp || rrp) $fatal(1,"traffic/US/estop gate failed");
  if(lp!==lrp || rp!==rrp) $fatal(1,"four-wheel output mapping changed");
  end
 end
 integer held;
 initial begin
  // Unit boundary: the actual image/CDC path is exercised by tb_color_gate.
  force dut.camera_green=green;
 force dut.voice_go_authorized=1;
  ms(1);reset=0;repeat(3) sample();press();ms(5);
  check(stby && dut.traffic_phase==0,"red before zebra must retain line following");
  gray=5'b11111;ms(4);
  check(!stby && dut.traffic_phase==2 && dut.straight_timer==0,"zebra waits on red");
  sample();check(!stby,"ultrasound must keep measuring while waiting");
  green=1;ms(10);check(stby && dut.straight_timer>0,"green forward");
  green=0;repeat(2) @(negedge clk);held=dut.straight_timer;
  ms(10);check(!stby && dut.straight_timer==held,"red pauses both motion and timer");
  green=1;pulse_us=1000;repeat(3) sample();
  check(!stby && dut.core.obstacle_stop && buzzer,"ultrasound still stops and beeps during green");
  held=dut.straight_timer;ms(10);check(dut.straight_timer==held,"US pause stops travel timer");
  green=0;sample();pulse_us=2900;repeat(3) sample();ms(4);
  check(!dut.core.us_pause && !stby,"US recovery cannot override red");
  green=1;ms(5);check(stby,"green after US recovery resumes");
  ms(160);check(!stby && dut.traffic_phase==3,"original accumulated straight limit");
  green=0;ms(2);green=1;gray=5'b11111;ms(4);check(!stby,"one-shot remains finished until reset");
  reset=1;gray=5'b00100;green=0;ms(2);reset=0;repeat(4) sample();press();ms(5);
  check(stby,"reset allows original start sequence");
  gray=5'b11111;ms(4);green=1;ms(5);check(stby,"second run green");
  #10;stop=1;#10;check(!stby && dut.core.estop_latched,"BTN2 immediate stop");stop=0;
  ms(5);check(!stby,"green cannot clear latched stop");
  $display("PASS tb_traffic_car: line before zebra, red/green control, all motors, actual ultrasonic Echo and buzzer, paused timer, one-shot completion, BTN2");
  $finish;
 end
 initial begin #1000000000;$fatal(1,"watchdog");end
endmodule
