`timescale 1ns/1ps
// UART发送器：8数据位、无校验、1停止位，LSB先发；valid/ready表示字节握手。
module uart_tx #(parameter integer CLK_HZ=125000000,parameter integer BAUD=115200)(
 input wire clk,input wire rst_n,input wire valid,input wire [7:0] data,
 output wire ready,output wire tx);
localparam integer BIT_CYCLES=(CLK_HZ+BAUD/2)/BAUD;
reg busy;reg [9:0] shift;reg [3:0] bit_index;reg [31:0] timer;
assign ready=!busy;
assign tx=rst_n && busy ? shift[0] : 1'b1; // 复位/空闲为高电平
always @(posedge clk) begin
 if(!rst_n) begin busy<=0;shift<=10'h3ff;bit_index<=0;timer<=0;end
 else if(!busy) begin
  if(valid) begin busy<=1;shift<={1'b1,data,1'b0};bit_index<=0;timer<=0;end
 end else if(timer>=BIT_CYCLES-1) begin
  timer<=0;shift<={1'b1,shift[9:1]};
  if(bit_index==9) busy<=0;else bit_index<=bit_index+1'b1;
 end else timer<=timer+1'b1;
end
// synthesis translate_off
initial if(BIT_CYCLES<2) $fatal(1,"UART requires >=2 clocks per bit");
// synthesis translate_on
endmodule
