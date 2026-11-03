`timescale 1ns/1ps
// One decision per DONE event, never one decision per clock of held valid.
// status: 1=valid range, 2=no target (safe, legacy semantics),
// 3=pulse timeout, 4=pre-trigger high, 5=invalid/short pulse.
module ultrasonic_guard #(
 parameter [15:0] STOP_DISTANCE_MM=300, RECOVER_DISTANCE_MM=400,
 parameter integer NEAR_CONFIRM_COUNT=3, RECOVER_CONFIRM_COUNT=3,
 parameter integer ERROR_CONFIRM_COUNT=4, STALE_CYCLES=25000000
)(input wire clk,rst_n,
 input wire done,distance_valid,input wire [15:0] distance,
 input wire [2:0] status,
 output reg obstacle_stop,output reg sensor_fault,
 output reg [7:0] near_count,error_count,recover_count,
 output wire start_clear,output wire stale_event);
reg [31:0] age;
assign stale_event=!done && age>=STALE_CYCLES-1;
wire valid_range=distance_valid && status==3'd1;
wire no_target=!distance_valid && status==3'd2;
wire clear_sample=no_target || (valid_range && distance>=RECOVER_DISTANCE_MM);
assign start_clear=(recover_count>=RECOVER_CONFIRM_COUNT) && !obstacle_stop && !sensor_fault;
always @(posedge clk) begin
 if(!rst_n) begin
  age<=0;near_count<=0;error_count<=0;recover_count<=0;
  obstacle_stop<=0;sensor_fault<=0;
 end else begin
  if(done || stale_event) age<=0;else age<=age+1'b1;
  if(done || stale_event) begin
   if(stale_event || !(valid_range || no_target)) begin
    near_count<=0;recover_count<=0;
    if(error_count<ERROR_CONFIRM_COUNT) error_count<=error_count+1'b1;
    if(error_count>=ERROR_CONFIRM_COUNT-1) sensor_fault<=1;
    // Isolated errors preserve the existing obstacle decision.
   end else begin
    error_count<=0;
    if(valid_range && distance<=STOP_DISTANCE_MM) begin
     recover_count<=0;
     if(near_count<NEAR_CONFIRM_COUNT) near_count<=near_count+1'b1;
     if(near_count>=NEAR_CONFIRM_COUNT-1) obstacle_stop<=1;
    end else begin
     near_count<=0; // also reset on a single result in the hysteresis band
     if(clear_sample) begin
      if(recover_count<RECOVER_CONFIRM_COUNT) recover_count<=recover_count+1'b1;
      if(recover_count>=RECOVER_CONFIRM_COUNT-1) begin
       obstacle_stop<=0;sensor_fault<=0;
      end
     end else recover_count<=0; // 300 < distance < 400: hold stop state
    end
   end
  end
 end
end
// synthesis translate_off
initial if(STOP_DISTANCE_MM>=RECOVER_DISTANCE_MM || STALE_CYCLES<1 ||
 NEAR_CONFIRM_COUNT<1 || NEAR_CONFIRM_COUNT>255 || RECOVER_CONFIRM_COUNT<1 ||
 RECOVER_CONFIRM_COUNT>255 || ERROR_CONFIRM_COUNT<1 || ERROR_CONFIRM_COUNT>255)
 $fatal(1,"Invalid ultrasonic guard parameters");
// synthesis translate_on
endmodule
