`timescale 1ns/1ps
module tb_traffic;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,pv=0,fs=0,fd=0,fg=1;
 reg [15:0] pixel=0,x=64,y=16;
 wire [1:0] state,raw;
 wire [31:0] rc,gc;
 traffic_light_detector dut(.pclk(clk),.rst_n(rst),.pixel_valid(pv),.pixel(pixel),
  .pixel_x(x),.pixel_y(y),.frame_start(fs),.frame_done(fd),.frame_good(fg),
  .traffic_state(state),.raw_state(raw),.last_red_count(rc),.last_green_count(gc),
  .red_detected(),.green_detected(),.red_streak(),.green_streak(),.unknown_streak());
 task frame;
 input [15:0] color;input good;input [2:0] position;
 integer n;
 begin
  @(negedge clk);fs=1;fg=good;
  case(position)
   1: begin x=0;y=0;end
   2: begin x=319;y=0;end
   3: begin x=0;y=239;end
   4: begin x=319;y=239;end
   default: begin x=64;y=16;end
  endcase
  @(negedge clk);fs=0;pv=1;pixel=color;
  for(n=0;n<400;n=n+1) @(negedge clk);
  pv=0;fd=1;
  @(negedge clk);fd=0;
 end endtask
 task check;
 input [1:0] expected;
 begin if(state!==expected) $fatal(1,"state %d expected %d",state,expected);end
 endtask
 initial begin
  #1;rst=0;repeat(3) @(negedge clk);rst=1;
  frame(16'hf800,1,0);check(0);
  if(rc!==400 || gc!==0) $fatal(1,"pixel counts");
  frame(16'hf800,1,0);check(0);frame(16'hf800,1,0);check(1);
  frame(16'h07e0,1,0);check(1);frame(16'h07e0,1,0);check(1);
  frame(16'h07e0,1,0);check(2);
  repeat(4) begin frame(16'hffff,1,0);check(2);end
  frame(16'hffff,1,0);check(0);
  repeat(3) frame(16'hf800,1,1);check(1);
  repeat(3) frame(16'h07e0,1,2);check(2);
  repeat(3) frame(16'hf800,1,3);check(1);
  repeat(3) frame(16'h07e0,1,4);check(2);
  repeat(5) frame(16'hf800,0,0);check(0);
  frame(16'hf800,1,0);frame(16'hf800,1,0);
  frame(16'h0000,1,0);frame(16'hf800,1,0);check(0);
  frame(16'hf800,1,0);check(0);frame(16'hf800,1,0);check(1);
  // Saturated white must not overflow dominance arithmetic into red/green.
  frame(16'hffff,1,0);if(raw!==0) $fatal(1,"white classified");
  $display("PASS: traffic counts, full-frame corners, 3-frame confirmation, switching, 5-frame loss, bad frames, streak reset");
  $finish;
 end
endmodule
