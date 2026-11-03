`timescale 1ns/1ps
module tb_curve_equivalence;
reg clk=0;always #500 clk=~clk;
reg reset=1,start=0,echo=0;reg [4:0] raw=5'b00100;
wire trig;integer samples=0;
line_ultrasonic_stop_top #(.CLK_HZ(1000000),.BUTTON_CYCLES(2),
 .US_PERIOD_US(10000),.US_MAX_ECHO_US(5000),.MAX_RUN_CYCLES(0)) dut(
 .clk(clk),.reset_button(reset),.start_button(start),.stop_button(1'b0),.gray(raw),.us_echo(echo),
 .estop_n(1'b1),.help_btn_n(1'b1),.esp_rx(1'b1),.enc_lf_a(1'b0),.enc_lf_b(1'b0),
 .enc_lr_a(1'b0),.enc_lr_b(1'b0),.enc_rf_a(1'b0),.enc_rf_b(1'b0),.enc_rr_a(1'b0),.enc_rr_b(1'b0),.us_trig(trig));
always @(posedge trig) begin
 samples=samples+1;#100000;echo=1;
 // Separated false near/invalid measurements interleaved with good ranges.
 if(samples>4 && samples%7==0) #1000000;
 else if(samples>4 && samples%7==3) #10000;
 else #2900000;
 echo=0;
end
wire [4:0] gray;wire ready,fault,motor,alarm;wire [2:0] state;
wire [7:0] left_duty,right_duty,risk;wire [31:0] debug_word;
line_curve_controller_reference #(.CLK_HZ(1000000),.ACTIVE_LOW(0),.REVERSE_ORDER(1),
 .CRUISE_DUTY(60),.HARD_OUTER_DUTY(190),.HARD_INNER_DUTY(0),.WIDE_DUTY(40)) reference(
 .clk(clk),.rst_n(dut.core.rst_n),.enable(dut.core.enabled),.emergency(dut.core.estop_latched),.raw(raw),
 .gray(gray),.ready(ready),.fault(fault),.state(state),.motor_enable(motor),
 .left_duty(left_duty),.right_duty(right_duty),.alarm_led(alarm),.risk_flags(risk),.debug_word(debug_word));
always @(negedge clk) if(dut.core.rst_n) begin
 if(dut.core.us_pause) $fatal(1,"isolated ultrasound event paused curve");
 if({gray,ready,fault,state,motor,left_duty,right_duty,risk,debug_word} !==
 {dut.core.gray,dut.core.line_ready,dut.core.line_fault,dut.core.state,dut.core.motor_allow,
  dut.core.left_duty,dut.core.right_duty,dut.core.risk,dut.core.curve_debug})
 $fatal(1,"cycle-by-cycle curve mismatch");
end
task ms(input integer n);repeat(n*1000) @(negedge clk);endtask
task pattern(input [4:0] p,input integer out_duty,input integer in_duty);
 begin
 raw=p;ms(110);
 if(!((left_duty==out_duty && right_duty==in_duty) ||
      (right_duty==out_duty && left_duty==in_duty))) $fatal(1,"PWM table mismatch");
 end
endtask
initial begin
 ms(1);reset=0;ms(40);start=1;ms(1);start=0;ms(40);
 pattern(5'b00100,60,60);pattern(5'b01100,100,35);pattern(5'b01000,130,20);
 pattern(5'b11000,170,0);pattern(5'b10000,190,0);
 raw=0;ms(10);raw=5'b00100;ms(30); // unchanged gap/reacquire behavior
 pattern(5'b00110,100,35);pattern(5'b00010,130,20);pattern(5'b00011,170,0);
 pattern(5'b00001,190,0);pattern(5'b01110,40,40);
 raw=0;ms(400);if(state!=6) $fatal(1,"original long-loss fault missing");
 $display("PASS tb_curve_equivalence: baseline cycle equivalence, all PWM table entries, gap/reacquire and serious line fault under isolated US noise");$finish;
end
initial begin #2000000000;$fatal(1,"watchdog");end
endmodule
