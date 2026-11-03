`timescale 1ns/1ps
// 外部复位异步拉低，经过两拍同步释放；各时钟域各实例化一个。
module reset_sync(input wire clk,input wire reset_n,output wire rst_n);
(* ASYNC_REG="TRUE" *) reg [1:0] sync;
always @(posedge clk or negedge reset_n)
 if(!reset_n) sync<=0; else sync<={sync[0],1'b1};
assign rst_n=sync[1];
endmodule
