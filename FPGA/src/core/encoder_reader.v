`timescale 1ns/1ps
// AB正交编码器x4计数：00->01->11->10->00为正方向，逆序为负方向。
// 两位同时跳变属于非法转换，不计数并置invalid脉冲；同步不是机械触点消抖。
// REVERSE将车辆前进统一为正，与电机驱动极性独立校准。
module encoder_reader #(parameter integer REVERSE=0)(input wire clk,input wire rst_n,input wire a,input wire b,
 output reg signed [31:0] count,output reg invalid);
(* ASYNC_REG="TRUE" *) reg [1:0] meta,sync;
reg [1:0] previous;
reg [2:0] settled; // 先采集静止初相位，防止上电时非00初值产生虚假一步
always @(posedge clk) begin
 if(!rst_n) begin meta<=0;sync<=0;previous<=0;settled<=0;count<=0;invalid<=0;end
 else begin
  meta<={a,b};sync<=meta;previous<=sync;invalid<=0;settled<={settled[1:0],1'b1};
  if(settled[2]) case({previous,sync})
   4'b0001,4'b0111,4'b1110,4'b1000: count<=REVERSE ? count-1'b1 : count+1'b1;
   4'b0010,4'b1011,4'b1101,4'b0100: count<=REVERSE ? count+1'b1 : count-1'b1;
   4'b0011,4'b1100,4'b0110,4'b1001: invalid<=1;
   default: count<=count;
  endcase
 end
end
endmodule
