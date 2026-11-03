`timescale 1ns/1ps
// Full-frame RGB565 color statistics. No shape, circle or area-maximum test.
// Only single-bit permission and heartbeat cross into the motor clock domain.
module traffic_color_gate #(
 parameter integer CLK_HZ=125000000,
 parameter integer FRAME_TIMEOUT_CYCLES=CLK_HZ
)(
 input wire clk,rst_n,pclk,p_rst_n,
 input wire configured,failed,
 input wire pixel_valid,input wire [15:0] pixel,pixel_x,pixel_y,
 input wire frame_start,frame_done,frame_good,
 output wire [1:0] observed_color,
 output wire camera_live,green_permitted
);
 (* MARK_DEBUG="TRUE" *) wire [1:0] traffic_state,raw_state;
 (* MARK_DEBUG="TRUE" *) wire [31:0] last_red_count,last_green_count;
 wire [31:0] green_streak;
 traffic_light_detector detector(
  .pclk(pclk),.rst_n(p_rst_n),.pixel_valid(pixel_valid),.pixel(pixel),
  .pixel_x(pixel_x),.pixel_y(pixel_y),.frame_start(frame_start),
  .frame_done(frame_done),.frame_good(frame_good),.traffic_state(traffic_state),
  .red_detected(),.green_detected(),.raw_state(raw_state),
  .last_red_count(last_red_count),.last_green_count(last_green_count),
  .red_streak(),.green_streak(green_streak),.unknown_streak());
 reg result_pending,good_pending,frame_toggle,green_level;
 reg [1:0] color_hold;
 reg color_toggle;
 (* ASYNC_REG="TRUE" *) reg [2:0] color_toggle_sync;
 reg color_seen;
 reg [1:0] color_sys;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin color_toggle_sync<=0;color_seen<=0;color_sys<=0;end
  else begin
   color_toggle_sync<={color_toggle_sync[1:0],color_toggle};
   color_seen<=color_toggle_sync[2];
   if(color_seen!=color_toggle_sync[2]) color_sys<=color_hold;
  end
 end
 assign observed_color=camera_live ? color_sys : 2'd0;
 always @(posedge pclk or negedge p_rst_n) begin
  if(!p_rst_n) begin
   result_pending<=0;good_pending<=0;frame_toggle<=0;green_level<=0;color_hold<=0;color_toggle<=0;
  end else begin
   result_pending<=frame_done;
   if(frame_done) good_pending<=frame_good;
   // Detector outputs are committed one PCLK after frame_done is observed.
   if(result_pending) begin
    color_hold<=good_pending ? raw_state : 2'd0;
    color_toggle<=~color_toggle;
    if(good_pending) frame_toggle<=~frame_toggle;
    // Stop on the first red/unknown/bad result, even if stable_state was green.
    green_level<=good_pending && raw_state==2 && traffic_state==2 && green_streak>=3;
   end
  end
 end
 (* ASYNC_REG="TRUE", SHREG_EXTRACT="NO" *) reg [2:0] frame_sync;
 (* ASYNC_REG="TRUE", SHREG_EXTRACT="NO" *) reg [1:0] green_sync;
 reg frame_seen;
 reg [31:0] stale_timer;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   frame_sync<=0;green_sync<=0;frame_seen<=0;stale_timer<=FRAME_TIMEOUT_CYCLES;
  end else begin
   frame_sync<={frame_sync[1:0],frame_toggle};
   green_sync<={green_sync[0],green_level};
   frame_seen<=frame_sync[2];
   if(!configured || failed) stale_timer<=FRAME_TIMEOUT_CYCLES;
   else if(frame_sync[2]!=frame_seen) stale_timer<=0;
   else if(stale_timer<FRAME_TIMEOUT_CYCLES) stale_timer<=stale_timer+1'b1;
  end
 end
 assign camera_live=configured && !failed && stale_timer<FRAME_TIMEOUT_CYCLES;
 assign green_permitted=camera_live && green_sync[1];
endmodule
