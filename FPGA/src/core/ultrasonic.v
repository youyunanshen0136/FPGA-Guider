`timescale 1ns/1ps
// Integer-microsecond acquisition. Existing ports retain their semantics.
module ultrasonic #(
 parameter integer CLK_HZ=125000000, PERIOD_US=60000, MAX_ECHO_US=30000,
 // Symmetric 1 us qualification at 125 MHz; at least two clocks.
 parameter integer ECHO_FILTER_CYCLES=(CLK_HZ/1000000<2 ? 2 : CLK_HZ/1000000),
 parameter integer MIN_ECHO_US=20
)(input wire clk,input wire rst_n,input wire echo,
 output reg trig,output reg [15:0] distance_mm,output reg valid,output reg success,
 output reg done,output reg [2:0] status,output reg [31:0] echo_us,
 output wire busy,output wire echo_synced,output reg echo_filtered);
localparam integer DIV=CLK_HZ/1000000;
localparam IDLE=0,TRIGGER=1,WAIT_RISE=2,MEASURE=3,PRODUCT=4,CONVERT=5;
(* ASYNC_REG="TRUE" *) reg meta,sync;
localparam integer FILTER_BITS=(ECHO_FILTER_CYCLES<2 ? 1 : $clog2(ECHO_FILTER_CYCLES));
reg [FILTER_BITS-1:0] filter_count;
assign echo_synced=sync;
// Qualification is at SYSTEM CLOCK rate, before the 1 us measurement sampling.
// Both edges receive the same delay, preserving the width of clean pulses.
always @(posedge clk) begin
 if(!rst_n) begin echo_filtered<=0;filter_count<=0;end
 else if(sync==echo_filtered) filter_count<=0;
 else if(filter_count>=ECHO_FILTER_CYCLES-1) begin
  echo_filtered<=sync;filter_count<=0;
 end else filter_count<=filter_count+1'b1;
end
reg [2:0] state;
reg [31:0] divider,timer,period_count;
reg [31:0] quotient;
reg [11:0] remainder;
reg [5:0] bits_left;
wire [12:0] trial={remainder,quotient[31]};
wire us_tick=divider==DIV-1;
assign busy=state!=IDLE;
always @(posedge clk) begin
 if(!rst_n) begin
  meta<=0;sync<=0;divider<=0;timer<=0;period_count<=PERIOD_US;
  state<=IDLE;trig<=0;distance_mm<=0;valid<=0;success<=0;
  done<=0;status<=0;echo_us<=0;quotient<=0;remainder<=0;bits_left<=0;
 end else begin
  meta<=echo;sync<=meta;success<=0;done<=0;
  if(us_tick) begin
   divider<=0;
   if(period_count<PERIOD_US) period_count<=period_count+1'b1;
  end else divider<=divider+1'b1;
  // Separate registered product and 32-cycle restoring division: no combinational divider.
  if(state==PRODUCT) begin
   quotient<=echo_us*32'd343;remainder<=0;bits_left<=32;state<=CONVERT;
  end else if(state==CONVERT) begin
   if(trial>=2000) begin
    remainder<=trial-2000;quotient<={quotient[30:0],1'b1};
   end else begin remainder<=trial;quotient<={quotient[30:0],1'b0};end
   bits_left<=bits_left-1'b1;
   if(bits_left==1) begin
    distance_mm<={quotient[14:0],(trial>=2000)};
    valid<=1;success<=1;done<=1;status<=1;state<=IDLE;
   end
  end else if(us_tick) case(state)
   IDLE: if(period_count>=PERIOD_US) begin
    period_count<=0;timer<=0;echo_us<=0;
    if(echo_filtered) begin valid<=0;status<=4;done<=1;end
    else begin trig<=1;state<=TRIGGER;end
   end
   TRIGGER: if(timer==9) begin trig<=0;timer<=0;state<=WAIT_RISE;end
            else timer<=timer+1'b1;
   WAIT_RISE: if(echo_filtered) begin timer<=1;state<=MEASURE;end
              else if(timer==MAX_ECHO_US-1) begin
               valid<=0;status<=2;done<=1;state<=IDLE;
              end else timer<=timer+1'b1;
   MEASURE: if(!echo_filtered) begin
             echo_us<=timer;
             if(timer<MIN_ECHO_US) begin
              valid<=0;status<=5;done<=1;state<=IDLE;
             end else state<=PRODUCT;
            end
            else if(timer==MAX_ECHO_US-1) begin
             echo_us<=MAX_ECHO_US;valid<=0;status<=3;done<=1;state<=IDLE;
            end else timer<=timer+1'b1;
   default: begin state<=IDLE;trig<=0;valid<=0;status<=5;done<=1;end
  endcase
 end
end
// synthesis translate_off
initial if(ECHO_FILTER_CYCLES<2 || MIN_ECHO_US<2 || MIN_ECHO_US>=MAX_ECHO_US ||
 ECHO_FILTER_CYCLES>DIV*MIN_ECHO_US/4 || DIV<1 || CLK_HZ%1000000!=0 || MAX_ECHO_US<2 ||
 MAX_ECHO_US>380000 || PERIOD_US<MAX_ECHO_US+10)
 $fatal(1,"Ultrasonic requires integer MHz clock and period >= timeout+10 us");
// synthesis translate_on
endmodule

