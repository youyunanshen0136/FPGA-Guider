`timescale 1ns/1ps
module tb_line_ultrasonic_stop;
reg clk=0;always #500 clk=~clk;
reg reset=1,start=0,stop=0,echo=0;
reg [4:0] line_raw=5'b00100;
integer mode=0,pulse_us=2900;
wire trig,stby,lp,rp,lrp,rrp;
line_ultrasonic_stop_top #(.CLK_HZ(1000000),.BUTTON_CYCLES(2),
 .US_PERIOD_US(10000),.US_MAX_ECHO_US(5000),.MAX_RUN_CYCLES(64'd2000000)) dut(
 .clk(clk),.reset_button(reset),.start_button(start),.stop_button(stop),
 .gray(line_raw),.us_echo(echo),.estop_n(1'b1),.help_btn_n(1'b1),.esp_rx(1'b1),
 .enc_lf_a(1'b0),.enc_lf_b(1'b0),.enc_lr_a(1'b0),.enc_lr_b(1'b0),
 .enc_rf_a(1'b0),.enc_rf_b(1'b0),.enc_rr_a(1'b0),.enc_rr_b(1'b0),
 .us_trig(trig),.motor_stby(stby),.motor_left_pwm(lp),.motor_right_pwm(rp),
 .motor_left_rear_pwm(lrp),.motor_right_rear_pwm(rrp));
always @(posedge trig) begin
 if(mode!=0) begin
  #100000;echo=1;
  if(mode==2) #10000;
  else if(mode==3) #6000000;
  else #(pulse_us*1000);
  echo=0;
 end
end
task ms(input integer n);repeat(n*1000) @(negedge clk);endtask
task press;begin start=1;repeat(20) @(negedge clk);start=0;repeat(20) @(negedge clk);end endtask
task sample;begin @(posedge dut.core.us_done);repeat(3) @(negedge clk);end endtask
task check(input bit ok,input string msg);if(!ok) $fatal(1,"%s state=%0d near=%0d error=%0d recover=%0d enabled=%b curve_en=%b pending=%b pause=%b ready=%b gray=%b raw=%b",msg,dut.core.state,dut.core.us_near_count,dut.core.us_error_count,dut.core.us_recover_count,dut.core.enabled,dut.core.curve_enable,dut.core.us_resume_pending,dut.core.us_pause,dut.core.line_ready,dut.core.gray,line_raw);endtask
always @(negedge clk) if(dut.core.us_pause || dut.core.estop_latched)
 if(stby || lp || rp || lrp || rrp) $fatal(1,"pause/estop failed on motor output");
integer i;
initial begin
 ms(1);reset=0;press();ms(1);check(!dut.core.enabled,"start before first result");
 sample();sample();check(!dut.core.us_start_clear,"startup requires three clear");
 sample();check(dut.core.us_start_clear && !dut.core.obstacle_stop,"no target startup");
 press();ms(4);check(stby && dut.core.state==1,"open scene start");
 mode=1;pulse_us=1000;
 sample();check(stby && !dut.core.obstacle_stop,"single near tolerated");
 sample();check(stby && !dut.core.obstacle_stop,"second near tolerated");
 sample();check(!stby && dut.core.obstacle_stop && dut.core.state!=6,"third near recoverable stop");
 pulse_us=2041;repeat(3) sample();check(!stby && dut.core.obstacle_stop,"350mm hysteresis");
 pulse_us=2333;
 sample();sample();check(!stby,"two far results do not recover");
 sample();ms(3);check(stby && dut.core.state==1,"400mm third auto recovery");
 // Each curve step remains active even when a single false near result arrives.
 for(i=0;i<4;i=i+1) begin
  case(i) 0:line_raw=5'b01100;1:line_raw=5'b01000;2:line_raw=5'b11000;3:line_raw=5'b10000;endcase
  pulse_us=1000;sample();check(stby && dut.core.state!=6,"single near during curve");
  pulse_us=2900;sample();check(stby && dut.core.us_near_count==0,"far resets curve noise");
 end
 mode=2;sample();check(stby && dut.core.us_error_count==1 && dut.core.us_status==5,"single short invalid pulse");
 mode=1;sample();check(stby && dut.core.us_error_count==0,"normal clears isolated error");
 mode=3;sample();check(stby && dut.core.us_status==3 && dut.core.us_error_count==1,"single timeout tolerated");
 mode=1;ms(2);sample();check(stby && dut.core.us_error_count==0,"timeout recovers");
 mode=0;echo=1;
 sample();sample();sample();check(stby && !dut.core.us_sensor_fault,"three stuck-high errors tolerated");
 sample();check(!stby && dut.core.us_sensor_fault && dut.core.state!=6,"four errors pause without FAULT");
 echo=0;sample();sample();check(!stby,"two no echo insufficient fault recovery");
 sample();ms(3);check(stby && !dut.core.us_sensor_fault,"no echo fault recovery");
 // A stopped car may be over a gap longer than LOSS_TIMEOUT_MS.
 mode=1;pulse_us=1000;repeat(3) sample();
 line_raw=0;ms(400);check(!stby && dut.core.state==0 && !dut.core.line_fault,"stationary blank must not consume line deadline");
 // Finish any near pulse already in flight before requesting three far frames.
 sample();pulse_us=2900;repeat(3) sample();ms(5);
 check(!dut.core.obstacle_stop && !dut.core.us_sensor_fault,"three completed far frames clear pause");
 check(!stby && dut.core.us_resume_pending && dut.core.state!=6,"wait for real line after obstacle");
 line_raw=5'b00100;ms(5);check(stby && dut.core.state==1,"resume when original line filter ready");
 // Asynchronous short estop while obstacle pause is in effect.
 pulse_us=1000;repeat(3) sample();
 #10;stop=1;#10;check(!stby && dut.core.estop_latched,"short estop immediately latched");stop=0;
 pulse_us=2900;repeat(3) sample();ms(3);
 check(!stby && dut.core.estop_latched && dut.core.state==6,"ultrasound cannot release estop");
 press();ms(3);check(!dut.core.enabled && !stby,"manual acknowledge disables");
 press();ms(3);check(stby,"original manual restart");
 // An unrelated serious line fault cannot be cleared by a later US pause.
 line_raw=5'b10101;ms(4);check(dut.core.state==6,"original invalid pattern FAULT");
 line_raw=5'b00100;pulse_us=1000;repeat(3) sample();
 pulse_us=2900;repeat(3) sample();ms(3);
 check(dut.core.state==6 && !stby,"obstacle recovery preserves prior line FAULT");
 $display("PASS tb_line_ultrasonic_stop: actual Echo, curve noise, pause/restart, all motors, blank hold, estop, retained FAULT");$finish;
end
initial begin #2000000000;$fatal(1,"watchdog");end
endmodule
