`timescale 1ns/1ps
// Curve prototype: calibrated direction, open-loop PWM, bounded blank recovery.
// Timing units are 1 ms control ticks.
module line_curve_controller_reference #(
 parameter integer CLK_HZ=125000000,
 parameter integer ACTIVE_LOW=0, REVERSE_ORDER=1,
 parameter integer GAP_MS=25, LOSS_TIMEOUT_MS=250, REACQUIRE_MS=8,
 parameter integer HISTORY_MS=200, LOSS_BUDGET_MS=300, UNSTABLE_MS=20,
 parameter [7:0] CRUISE_DUTY=60, HARD_OUTER_DUTY=190, HARD_INNER_DUTY=0,
 parameter [7:0] WIDE_DUTY=40,
 parameter integer RAMP_UP=2, RAMP_DOWN=4
)(
 input wire clk,rst_n,enable,emergency,
 input wire [4:0] raw,
 output reg [4:0] gray,
 output wire ready,fault,
 output reg [2:0] state,
 output wire motor_enable,
 output wire [7:0] left_duty,right_duty,
 output wire alarm_led,
 output wire [7:0] risk_flags,
 output wire [31:0] debug_word
);
localparam integer TICK_CYCLES=CLK_HZ/1000;
localparam [2:0] IDLE=0,TRACK=1,GAP=2,SEARCH=3,REACQUIRE=4,FAULT=6;
localparam [3:0] NONE=0,EMERGENCY=1,LOST_TIMEOUT=2,NO_HISTORY=3,
 INVALID_PATTERN=4,UNSTABLE_INPUT=5,LOSS_BUDGET=6;
(* ASYNC_REG="TRUE" *) reg [4:0] meta,sync;
wire [4:0] polarity=ACTIVE_LOW ? ~sync : sync;
wire [4:0] normalized=REVERSE_ORDER ? {polarity[0],polarity[1],polarity[2],polarity[3],polarity[4]} : polarity;
reg [31:0] tick_count;
wire tick=tick_count==TICK_CYCLES-1;
reg [4:0] candidate;
reg [15:0] unsettled_ms;
always @(posedge clk) begin
 if(!rst_n) begin meta<=0;sync<=0;candidate<=0;gray<=0;tick_count<=0;unsettled_ms<=0;end
 else begin
  meta<=raw;sync<=meta;
  if(tick) begin
   tick_count<=0;candidate<=normalized;
   if(candidate==normalized) begin gray<=normalized;unsettled_ms<=0;end
   else if(unsettled_ms<UNSTABLE_MS) unsettled_ms<=unsettled_ms+1'b1;
  end else tick_count<=tick_count+1'b1;
 end
end
reg valid_pattern;
reg signed [3:0] error_q;
always @* begin
 valid_pattern=1;error_q=0;
 case(gray)
  5'b10000:error_q=-4;
  5'b11000:error_q=-3;
  5'b01000,5'b11100:error_q=-2;
  5'b01100:error_q=-1;
  5'b00100,5'b01110:error_q=0;
  5'b00110:error_q=1;
  5'b00010,5'b00111:error_q=2;
  5'b00011:error_q=3;
  5'b00001:error_q=4;
  default:valid_pattern=0;
 endcase
end
wire blank=gray==0;
wire invalid_pattern=!valid_pattern && !blank;
wire unstable=unsettled_ms>=UNSTABLE_MS;
assign ready=rst_n && valid_pattern && !unstable;
assign fault=state==FAULT;
reg [3:0] stop_reason;
reg [15:0] loss_ms,reacquire_ms,history_age,loss_budget;
reg [3:0] decay_count;
reg history_valid,history_right;
wire history_fresh=history_valid && history_age<HISTORY_MS;
reg [7:0] last_left,last_right;
reg [7:0] track_left,track_right,outer_duty,inner_duty;
reg [7:0] target_left,target_right;
wire [3:0] magnitude=error_q[3] ? -error_q : error_q;
always @* begin
 outer_duty=CRUISE_DUTY;inner_duty=CRUISE_DUTY;
 case(magnitude)
  1:begin outer_duty=100;inner_duty=35;end
  2:begin outer_duty=130;inner_duty=20;end
  3:begin outer_duty=170;inner_duty=0;end
  4:begin outer_duty=HARD_OUTER_DUTY;inner_duty=HARD_INNER_DUTY;end
  default:begin outer_duty=CRUISE_DUTY;inner_duty=CRUISE_DUTY;end
 endcase
 if(gray==5'b01110) begin outer_duty=WIDE_DUTY;inner_duty=WIDE_DUTY;end
 track_left=error_q<0 ? inner_duty : outer_duty;
 track_right=error_q<0 ? outer_duty : inner_duty;
 target_left=track_left;target_right=track_right;
 if(state==GAP) begin
  target_left=last_left>60 ? 60 : last_left;
  target_right=last_right>60 ? 60 : last_right;
 end else if(state==SEARCH) begin
  target_left=history_right ? 90 : 0;
  target_right=history_right ? 0 : 90;
 end else if(state==REACQUIRE) begin
  target_left=track_left>60 ? 60 : track_left;
  target_right=track_right>60 ? 60 : track_right;
 end
end
assign motor_enable=rst_n && enable && !emergency && !invalid_pattern && !unstable &&
 (state==TRACK || state==GAP || state==SEARCH || state==REACQUIRE);
assign alarm_led=enable && (fault || emergency);
assign risk_flags={fault,fault,1'b0,4'b0,emergency};
assign debug_word={stop_reason,error_q,loss_ms[7:0],target_left,target_right};

always @(posedge clk) begin
 if(!rst_n || !enable) begin
  state<=IDLE;stop_reason<=NONE;loss_ms<=0;reacquire_ms<=0;
  history_valid<=0;history_right<=0;history_age<=HISTORY_MS;
  loss_budget<=0;decay_count<=0;last_left<=0;last_right<=0;
 end else if(emergency) begin state<=FAULT;stop_reason<=EMERGENCY;end
 else if(state==FAULT) begin state<=FAULT;end
 else if(invalid_pattern) begin state<=FAULT;stop_reason<=INVALID_PATTERN;end
 else if(unstable) begin state<=FAULT;stop_reason<=UNSTABLE_INPUT;end
 else if(tick) begin
  if(history_age<HISTORY_MS) history_age<=history_age+1'b1;
  if(ready && error_q!=0 && state==TRACK) begin
   history_valid<=1;history_right<=!error_q[3];history_age<=0;
  end
  // Leaky loss budget survives reacquisition. Flicker cannot reset this budget.
  if(blank && state!=IDLE) begin
   decay_count<=0;
   if(loss_budget<LOSS_BUDGET_MS) loss_budget<=loss_budget+1'b1;
  end else if(ready && state==TRACK) begin
   if(decay_count==9) begin
    decay_count<=0;
    if(loss_budget!=0) loss_budget<=loss_budget-1'b1;
   end else decay_count<=decay_count+1'b1;
  end
  if(blank && state!=IDLE && loss_budget>=LOSS_BUDGET_MS-1) begin
   state<=FAULT;stop_reason<=LOSS_BUDGET;
  end else case(state)
   IDLE:begin
    if(ready) begin state<=TRACK;last_left<=track_left;last_right<=track_right;end
    else begin state<=FAULT;stop_reason<=NO_HISTORY;end
   end
   TRACK:begin
    loss_ms<=0;reacquire_ms<=0;
    if(blank) begin state<=GAP;loss_ms<=1;end
    else begin last_left<=track_left;last_right<=track_right;end
   end
   GAP,SEARCH,REACQUIRE:begin
    // One deadline includes brief reappearances and reacquisition confirmation.
    if(loss_ms>=LOSS_TIMEOUT_MS-1) begin state<=FAULT;stop_reason<=LOST_TIMEOUT;end
    else begin
     loss_ms<=loss_ms+1'b1;
     if(ready) begin
      state<=REACQUIRE;
      if(reacquire_ms>=REACQUIRE_MS-1) begin
       state<=TRACK;loss_ms<=0;reacquire_ms<=0;
       last_left<=track_left;last_right<=track_right;
       if(error_q!=0) begin history_valid<=1;history_right<=!error_q[3];history_age<=0;end
      end else reacquire_ms<=reacquire_ms+1'b1;
     end else begin
      reacquire_ms<=0;
      if(loss_ms<GAP_MS) state<=GAP;
      else if(history_fresh || state==SEARCH) state<=SEARCH;
      else begin state<=FAULT;stop_reason<=NO_HISTORY;end
     end
    end
   end
   default:begin state<=FAULT;stop_reason<=INVALID_PATTERN;end
  endcase
 end
end
function [7:0] slew;
 input [7:0] current,wanted;
 reg [8:0] diff;
 begin
  if(wanted>current) begin
   diff={1'b0,wanted}-{1'b0,current};
   slew=diff>RAMP_UP ? current+RAMP_UP : wanted;
  end else begin
   diff={1'b0,current}-{1'b0,wanted};
   slew=diff>RAMP_DOWN ? current-RAMP_DOWN : wanted;
  end
 end
endfunction
reg [7:0] duty_l,duty_r;
always @(posedge clk) begin
 if(!rst_n || !motor_enable) begin duty_l<=0;duty_r<=0;end
 else if(tick) begin duty_l<=slew(duty_l,target_left);duty_r<=slew(duty_r,target_right);end
end
assign left_duty=motor_enable ? duty_l : 0;
assign right_duty=motor_enable ? duty_r : 0;
// synthesis translate_off
initial if(CLK_HZ<1000 || CLK_HZ%1000 || GAP_MS<1 || LOSS_TIMEOUT_MS<=GAP_MS ||
 LOSS_TIMEOUT_MS>255 || REACQUIRE_MS<1 || HISTORY_MS<GAP_MS || LOSS_BUDGET_MS<LOSS_TIMEOUT_MS ||
 RAMP_UP<1 || RAMP_DOWN<1) $fatal(1,"Invalid curve parameters");
// synthesis translate_on
endmodule

