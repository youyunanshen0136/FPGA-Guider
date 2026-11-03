`timescale 1ns/1ps
// 蜂鸣器物理适配：有源时输出节奏电平，无源时输出被节奏门控的音频方波。
// ACTIVE_LOW只描述驱动模块的有效电平；裸器件仍须外部晶体管/驱动电路。
module buzzer_driver #(
 parameter integer CLK_HZ=125000000,parameter integer PASSIVE=0,
 parameter integer ACTIVE_LOW=0,parameter integer TONE_HZ=2000
)(input wire clk,input wire rst_n,input wire beep_enable,output wire buzzer);
localparam integer HALF_PERIOD=CLK_HZ/(2*TONE_HZ);
reg [31:0] timer;reg tone;
always @(posedge clk) begin
 if(!rst_n || !beep_enable) begin timer<=0;tone<=0;end
 else if(timer>=HALF_PERIOD-1) begin timer<=0;tone<=~tone;end
 else timer<=timer+1'b1;
end
wire active=rst_n && beep_enable && (PASSIVE ? tone : 1'b1);
// 低有效模块复位时输出1才是关闭，不能无条件拉低。
assign buzzer=ACTIVE_LOW ? !active : active;
// synthesis translate_off
initial if(TONE_HZ<1 || HALF_PERIOD<1) $fatal(1,"Invalid buzzer frequency");
// synthesis translate_on
endmodule
