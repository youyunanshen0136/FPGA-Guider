`timescale 1ns/1ps
// 只读遥测：周期快照40字节，UART背压时保持字节；不接受任何运动控制命令。
// 编码见docs/使用与接线说明.md；checksum为前39字节逐字节异或。
module telemetry_tx #(parameter integer CLK_HZ=125000000,parameter integer BAUD=115200,
 parameter integer RATE_HZ=10)(
 input wire clk,input wire rst_n,input wire [7:0] flags,input wire [2:0] state,
 input wire [4:0] gray,input wire [7:0] risk,input wire [7:0] blocked_reason,
 input wire [15:0] distance_mm,input wire [7:0] left_duty,input wire [7:0] right_duty,
 input wire signed [31:0] left_speed,input wire signed [31:0] right_speed,
 input wire [31:0] left_distance,input wire [31:0] right_distance,
 input wire [31:0] left_errors,input wire [31:0] right_errors,output wire tx,input wire [7:0] visual_status);
localparam integer PERIOD=CLK_HZ/RATE_HZ;
reg [31:0] timer;reg [7:0] sequence_id;reg [319:0] snapshot;reg [5:0] index;reg active;
wire ready;
// 高位为字节38，低位为字节0；所有字段在同一时钟沿冻结，防止帧内跳变。
wire [311:0] raw_frame={visual_status,right_errors,left_errors,right_distance,left_distance,
 right_speed,left_speed,right_duty,left_duty,distance_mm,blocked_reason,risk,
 {3'd0,gray},{5'd0,state},flags,sequence_id,8'd40,8'd1,8'h5a,8'ha5};
function [7:0] checksum;
 input [311:0] value;integer i;begin checksum=0;
 for(i=0;i<39;i=i+1) checksum=checksum ^ value[i*8 +:8];end
endfunction
wire [7:0] data=snapshot[index*8 +:8];
uart_tx #(.CLK_HZ(CLK_HZ),.BAUD(BAUD)) transmitter(clk,rst_n,active,data,ready,tx);
always @(posedge clk) begin
 if(!rst_n) begin timer<=0;sequence_id<=0;snapshot<=0;index<=0;active<=0;end
 else begin
  if(timer>=PERIOD-1) begin
   timer<=0;
   // 一槽快照，无积压队列：带宽不足时跳过这次采样，不截断正在发送的帧。
   if(!active) begin snapshot<={checksum(raw_frame),raw_frame};sequence_id<=sequence_id+1'b1;index<=0;active<=1;end
  end else timer<=timer+1'b1;
  if(active && ready) begin
   if(index==39) active<=0;else index<=index+1'b1;
  end
 end
end
// synthesis translate_off
initial if(PERIOD<1) $fatal(1,"Invalid telemetry sample period");
// synthesis translate_on
endmodule
