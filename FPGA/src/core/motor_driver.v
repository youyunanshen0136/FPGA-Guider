`timescale 1ns/1ps
// 双路正向PWM，方向输出约定IN1=1/IN2=0为前进。实际驱动板须核对真值表。
// 仅支持前进/停车，不接受反转请求，因而不会在运行中换向。
// 每周期锁存占空比，避免更新时截断脉冲；禁止/急停组合拉低PWM和使能。
module motor_driver #(parameter integer CLK_HZ=125000000,parameter integer PWM_HZ=20000,
 // 仅改变逻辑前进时的引脚方向，参数是综合常量，不允许运行中换向。
 parameter integer LEFT_REVERSE=0,parameter integer RIGHT_REVERSE=0)(
 input wire clk,input wire rst_n,input wire allow,input wire emergency,
 input wire [7:0] left_duty,input wire [7:0] right_duty,
 output wire left_pwm,output wire right_pwm,
 output wire left_in1,output wire left_in2,output wire right_in1,output wire right_in2,
 output wire driver_enable);
localparam integer PERIOD=CLK_HZ/PWM_HZ;
reg [31:0] phase,left_limit,right_limit;
// Exact duty scaling is computed at elaboration, not through a runtime divider.
(* rom_style="distributed" *) reg [31:0] duty_limit [0:255];
integer duty_index;
initial for(duty_index=0;duty_index<256;duty_index=duty_index+1)
 duty_limit[duty_index]=(64'd1*duty_index*PERIOD)/255;
wire gate=rst_n && allow && !emergency;
always @(posedge clk) begin
 if(!gate) begin phase<=0;left_limit<=0;right_limit<=0;end
 else begin
  if(phase==0) begin
   // 255映射全开，0完全关闭；64位乘法避免高时钟参数下中间值溢出。
   left_limit<=duty_limit[left_duty];
   right_limit<=duty_limit[right_duty];
  end
  if(phase>=PERIOD-1) phase<=0;else phase<=phase+1'b1;
 end
end
assign driver_enable=gate;
assign left_pwm=gate && phase<left_limit;
assign right_pwm=gate && phase<right_limit;
// 禁止时IN1/IN2均为0且STBY关闭；左右极性独立适配镜像安装。
assign left_in1=gate && !LEFT_REVERSE;assign left_in2=gate && LEFT_REVERSE;
assign right_in1=gate && !RIGHT_REVERSE;assign right_in2=gate && RIGHT_REVERSE;
// synthesis translate_off
initial if(PERIOD<2) $fatal(1,"PWM period must be >=2");
// synthesis translate_on
endmodule
