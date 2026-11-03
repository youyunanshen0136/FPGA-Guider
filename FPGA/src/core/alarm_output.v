`timescale 1ns/1ps
// 报警节奏：正常常亮不鸣，警告1Hz闪/0.1秒鸣，危险5Hz声光同闪。
// 严重级别改变时节奏重新开始，危险到达后不必等之前的静音相位结束。
// 可单独接有源模块；car_top保持此模块高有效，再由buzzer_driver适配硬件。
module alarm_output #(parameter integer CLK_HZ=125000000,
 parameter integer BUZZER_ACTIVE_LOW=0)(
 input wire clk,input wire rst_n,input wire running,input wire warning,input wire danger,
 output wire led,output wire buzzer);
wire [1:0] mode=danger ? 2'd3 : warning ? 2'd2 : running ? 2'd1 : 2'd0;
reg [1:0] previous_mode;
reg [31:0] phase;
always @(posedge clk) begin
 if(!rst_n) begin phase<=0;previous_mode<=0;end
 else begin
  previous_mode<=mode;
  if(mode!=previous_mode || phase>=CLK_HZ-1) phase<=0;
  else phase<=phase+1'b1;
 end
end
wire fast=(phase%(CLK_HZ/5))<(CLK_HZ/10);
wire request=rst_n && (danger ? fast : warning && phase<CLK_HZ/10);
assign led=rst_n && (danger ? fast : warning ? phase<CLK_HZ/2 : running);
assign buzzer=BUZZER_ACTIVE_LOW ? !request : request;
// synthesis translate_off
initial if(CLK_HZ<10) $fatal(1,"Alarm CLK_HZ must be >=10");
// synthesis translate_on
endmodule
