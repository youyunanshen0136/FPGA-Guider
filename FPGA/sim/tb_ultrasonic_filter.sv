`timescale 1ns/1ps
module tb_ultrasonic_filter;
reg clk=0;always #4 clk=~clk; // production 125 MHz, 8 ns clocks
reg rst_n=0,echo=0;
wire trig,valid,success,done,busy,synced,filtered;
wire [15:0] distance;wire [2:0] status;wire [31:0] echo_us;
ultrasonic #(.PERIOD_US(6000),.MAX_ECHO_US(5000)) dut(
 .clk(clk),.rst_n(rst_n),.echo(echo),.trig(trig),.distance_mm(distance),.valid(valid),
 .success(success),.done(done),.status(status),.echo_us(echo_us),.busy(busy),
 .echo_synced(synced),.echo_filtered(filtered));
task check(input bit ok,input string msg);if(!ok) $fatal(1,"%s status=%0d width=%0d distance=%0d",msg,status,echo_us,distance);endtask
task result;begin @(posedge done);@(negedge clk);end endtask
task launch;begin @(negedge trig);#100000;end endtask
integer i;
initial begin
 repeat(5) @(negedge clk);rst_n=1;
 launch();
 // A range of sub-qualification high spikes never produces a filtered rise.
 for(i=1;i<125;i=i+11) begin
  @(negedge clk);echo=1;repeat(i) @(negedge clk);echo=0;
  repeat(150) @(negedge clk);check(!filtered,"high glitch passed filter");
 end
 echo=1;#1000000;echo=0;result();
 check(status==1 && valid && echo_us>=999 && echo_us<=1001 && distance>=171 && distance<=172,"clean 1ms pulse width");
 launch();echo=1;#400000;echo=0;#400;echo=1;#599600;echo=0;result();
 check(status==1 && echo_us>=999 && echo_us<=1001,"low notch split normal echo");
 launch();echo=1;#10000;echo=0;result();
 check(status==5 && !valid && echo_us>=9 && echo_us<=11,"short qualified pulse invalid");
 launch();result();check(status==2 && !valid,"no rise timeout safe status");
 launch();echo=1;result();check(status==3 && !valid && echo_us==5000,"pulse timeout");
 result();check(status==4 && !valid,"pre-trigger stuck high");
 echo=0;launch();echo=1;#2333000;echo=0;result();
 check(status==1 && valid && distance==400,"width accuracy after recovery at 400mm");
 // Complete reset also clears filter and statuses.
 rst_n=0;repeat(4) @(negedge clk);check(!filtered && !valid && !trig,"reset");
 $display("PASS tb_ultrasonic_filter: 125MHz high glitches, low notch, width accuracy, invalid, both timeouts, recovery");$finish;
end
initial begin #100000000;$fatal(1,"watchdog");end
endmodule
