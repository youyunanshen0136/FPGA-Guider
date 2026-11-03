`timescale 1ns/1ps
module tb_ultrasonic_guard;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,done=0,valid=0;reg [15:0] distance=0;reg [2:0] status=0;
wire stop,fault,clear,stale;wire [7:0] near_n,error_n,recover_n;
ultrasonic_guard #(.STALE_CYCLES(100)) dut(clk,rst_n,done,valid,distance,status,
 stop,fault,near_n,error_n,recover_n,clear,stale);
task sample(input integer mm,input integer st,input bit v);
 begin
 @(negedge clk);distance=mm;status=st;valid=v;done=1;
 @(negedge clk);done=0;
 end
endtask
task check(input bit ok,input string msg);if(!ok) $fatal(1,"%s",msg);endtask
integer i;
initial begin
 repeat(3) @(negedge clk);rst_n=1;
 check(!stop && !clear && !fault,"startup");
 sample(300,1,1);check(near_n==1 && !stop,"first near");
 repeat(20) @(negedge clk);check(near_n==1 && !stop,"held valid must count once");
 sample(300,1,1);sample(301,1,1);check(near_n==0,"301 breaks near run");
 sample(0,1,1);sample(300,1,1);sample(0,3,0);
 check(!stop && near_n==0 && error_n==1,"anomaly breaks near run");
 sample(300,1,1);sample(300,1,1);check(!stop,"two near");
 sample(300,1,1);check(stop && near_n==3,"third near");
 for(i=0;i<4;i=i+1) sample(399,1,1);
 check(stop && recover_n==0,"399 must not release");
 sample(400,1,1);sample(400,1,1);check(stop,"two safe insufficient");
 sample(350,1,1);check(recover_n==0 && stop,"band breaks recovery");
 sample(400,1,1);sample(400,1,1);sample(0,5,0);
 check(stop && recover_n==0,"error breaks recovery");
 sample(400,1,1);sample(400,1,1);sample(400,1,1);
 check(!stop && clear,"400 third releases");
 for(i=0;i<3;i=i+1) begin sample(0,4,0);check(!fault,"single/three faults must not trip");end
 sample(0,4,0);check(fault && error_n==4,"four abnormal trips");
 for(i=0;i<10;i=i+1) sample(0,3,0);
 check(error_n==4 && fault,"fault count saturates");
 sample(500,1,1);sample(500,1,1);check(fault,"fault waits for clear confirmation");
 sample(500,1,1);check(!fault && clear,"fault auto recovers");
 sample(100,1,1);sample(100,1,1);sample(100,1,1);check(stop,"second obstacle");
 sample(100,2,0);sample(100,2,0);sample(100,2,0);
 check(!stop && !fault && clear,"no target safe despite stale near distance");
 sample(500,1,0);check(error_n==1,"invalid valid/status combination abnormal");
 sample(500,1,1);check(error_n==0,"normal resets error streak");
 sample(500,2,1);check(error_n==1,"inconsistent no-target abnormal");
 sample(500,1,1);
 repeat(300) @(negedge clk);check(!fault && error_n==3,"three stale intervals tolerated");
 repeat(100) @(negedge clk);check(fault && error_n==4,"watchdog counts missing DONE");
 sample(500,1,1);sample(500,1,1);sample(500,1,1);check(!fault,"watchdog recovery");
 $display("PASS tb_ultrasonic_guard: boundaries, fresh events, interruption, hysteresis, errors, no echo, watchdog");$finish;
end
initial begin #100000;$fatal(1,"watchdog");end
endmodule
