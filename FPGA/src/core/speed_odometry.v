`timescale 1ns/1ps

// 编码器计数换算为有符号速度mm/s及累计绝对里程mm。
// COUNTS_PER_REV是四倍频后的每转计数，需要实测标定。
module speed_odometry #(
    parameter integer CLK_HZ=125000000,
    parameter integer SAMPLE_HZ=10,
    parameter integer MM_PER_REV=210,
    parameter integer COUNTS_PER_REV=80
)(
    input wire clk,
    input wire rst_n,
    input wire signed [31:0] count,
    output reg signed [31:0] speed_mm_s,
    output reg [31:0] distance_mm,
    output reg sample
);

localparam integer PERIOD=CLK_HZ/SAMPLE_HZ;

reg [31:0] timer;
reg signed [31:0] previous;
reg [63:0] remainder;

// 32位计数模差，要求单个采样窗口增量不超过可表示范围。
reg signed [31:0] delta;
reg [3:0] valid;
reg [63:0] distance_product;
reg signed [95:0] velocity_stage2,velocity_stage3;
wire signed [63:0] signed_delta={{32{delta[31]}},delta};
wire [31:0] magnitude=delta[31] ? -delta : delta;

// 只在参数展开时计算，不产生运行时最大公约数电路。
function [63:0] constant_gcd;
    input [63:0] a,b;
    reg [63:0] t;
    integer i;
    begin
        for(i=0;i<128;i=i+1) begin
            if(b!=0) begin
                t=a%b;
                a=b;
                b=t;
            end
        end
        constant_gcd=a;
    end
endfunction

// 默认轮周长/每转计数：210/80约分为21/8。
// 保留小于1mm的余数，避免低速里程无法累计。
localparam [63:0] DIST_GCD=constant_gcd(MM_PER_REV,COUNTS_PER_REV);
localparam [63:0] DIST_NUM=MM_PER_REV/DIST_GCD;
localparam [63:0] DIST_DEN=COUNTS_PER_REV/DIST_GCD;

reg [63:0] numerator;
reg [63:0] increment;
wire [32:0] distance_sum={1'b0,distance_mm}+{1'b0,increment[31:0]};

// 按真实采样周期计算速度，常量系数先约分以降低硬件开销。
localparam [63:0] SPEED_NUM_FULL=64'd1*MM_PER_REV*CLK_HZ;
localparam [63:0] SPEED_DEN_FULL=64'd1*COUNTS_PER_REV*PERIOD;
localparam [63:0] SPEED_GCD=constant_gcd(SPEED_NUM_FULL,SPEED_DEN_FULL);
localparam signed [63:0] SPEED_NUM=SPEED_NUM_FULL/SPEED_GCD;
localparam signed [63:0] SPEED_DEN=SPEED_DEN_FULL/SPEED_GCD;

// 扩大中间乘积，避免先乘后除溢出；负数除法向0截断。
reg signed [95:0] speed_product;
wire signed [95:0] velocity=speed_product/SPEED_DEN;

// Four arithmetic stages; sample pulses when speed and distance commit together.
// Counter snapshots retain the requested PERIOD; output latency is four clocks.
always @(posedge clk) begin
 if(!rst_n) begin
  timer<=0;previous<=0;remainder<=0;speed_mm_s<=0;distance_mm<=0;sample<=0;
  delta<=0;valid<=0;distance_product<=0;speed_product<=0;numerator<=0;
  increment<=0;velocity_stage2<=0;velocity_stage3<=0;
 end else begin
  sample<=valid[3];
  valid<={valid[2:0],1'b0};
  if(timer>=PERIOD-1) begin
   timer<=0;previous<=count;delta<=count-previous;valid[0]<=1;
  end else timer<=timer+1'b1;
  if(valid[0]) begin
   distance_product<=magnitude*DIST_NUM;
   speed_product<=$signed(delta)*SPEED_NUM;
  end
  if(valid[1]) begin
   numerator<=distance_product+remainder;
   velocity_stage2<=velocity;
  end
  if(valid[2]) begin
   increment<=numerator/DIST_DEN;
   remainder<=numerator%DIST_DEN;
   velocity_stage3<=velocity_stage2;
  end
  if(valid[3]) begin
   speed_mm_s<=velocity_stage3;
   if(|increment[63:32] || distance_sum[32]) distance_mm<=32'hffffffff;
   else distance_mm<=distance_sum[31:0];
  end
 end
end

// synthesis translate_off
initial if(CLK_HZ<1 || SAMPLE_HZ<1 || PERIOD<5 ||
           MM_PER_REV<1 || COUNTS_PER_REV<1)
    $fatal(1,"Invalid speed_odometry parameters");
// synthesis translate_on

endmodule