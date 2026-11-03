`timescale 1ns/1ps
module tb_voice;
reg clk=0; always #5 clk=~clk;
reg rst=0; reg [5:0] conditions=0;wire [5:0] gpio;
asrpro_events #(.CLK_HZ(100),.PULSE_CYCLES(3),.GAP_CYCLES(6)) dut(clk,rst,conditions,gpio);
integer starts[0:5];integer i,j; reg [5:0] prev=0;integer width=0;integer silence=100;
always @(negedge clk) begin
 if(!rst) begin prev=0;width=0;silence=100;end
 else begin
 if(gpio!=0 && (gpio & (gpio-1))!=0) $fatal(1,"Multiple outputs");
 if(gpio!=0) begin
  if(prev==0) begin
   if(silence<6) $fatal(1,"Gap too short");
   for(j=0;j<6;j=j+1) if(gpio[j]) starts[j]=starts[j]+1;
  end
  width=width+1;silence=0;
 end else begin
  if(prev!=0) begin if(width!=3) $fatal(1,"Pulse width %d",width);width=0;end
  silence=silence+1;
 end
 prev=gpio;
 end
end
task tick(input integer n);repeat(n) @(negedge clk);endtask
initial begin
 for(i=0;i<6;i=i+1) starts[i]=0;
 tick(3);rst=1;tick(2);
 conditions=6'b111111;tick(100);
 for(i=0;i<6;i=i+1) if(starts[i]!=1) $fatal(1,"Missing/duplicate %d %d",i,starts[i]);
 tick(100);for(i=0;i<6;i=i+1) if(starts[i]!=1) $fatal(1,"Held condition repeats");
 conditions=0;tick(3);conditions=1;tick(20);
 if(starts[0]!=2) $fatal(1,"Rearm failed");
 conditions=0;tick(3);conditions=3;tick(2);conditions=1;tick(30);
 if(starts[1]!=1) $fatal(1,"Obsolete clear was played");
 rst=0;tick(2);if(gpio!=0) $fatal(1,"Reset not low");
 $display("VOICE_TEST_PASS six channels, width, gap, held, rearm, cancellation, reset");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
