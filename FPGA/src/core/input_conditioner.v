`timescale 1ns/1ps
// 单输入两级同步+连续稳定消抖；启动按钮用rise事件，急停不经过长消抖。
module input_conditioner #(parameter integer STABLE_CYCLES=1250000)(
 input wire clk,input wire rst_n,input wire raw,
 output reg level,output reg rise);
(* ASYNC_REG="TRUE" *) reg meta,sync;
reg [31:0] count;
always @(posedge clk) begin
 if(!rst_n) begin meta<=0;sync<=0;level<=0;rise<=0;count<=0;end
 else begin
  meta<=raw;sync<=meta;rise<=0;
  if(sync==level) count<=0;
  else if(count>=STABLE_CYCLES-1) begin
   level<=sync;rise<=sync;count<=0;
  end else count<=count+1'b1;
 end
end
endmodule
