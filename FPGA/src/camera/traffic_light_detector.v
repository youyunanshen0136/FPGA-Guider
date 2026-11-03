`timescale 1ns/1ps
// RGB565 streaming detector. Coordinates and frame flags belong to pclk.
module traffic_light_detector #(
 parameter integer ROI_X_MIN=0, ROI_X_MAX=319, ROI_Y_MIN=0, ROI_Y_MAX=239,
 parameter integer RED_BRIGHT_MIN=34, GREEN_BRIGHT_MIN=30, DOMINANCE=10,
 parameter integer RED_PIXEL_MIN=300, GREEN_PIXEL_MIN=300, COUNT_MARGIN=100,
 parameter integer CONFIRM_FRAMES=3, UNKNOWN_FRAMES=5
)(input wire pclk,rst_n,pixel_valid,input wire [15:0] pixel,pixel_x,pixel_y,
 input wire frame_start,frame_done,frame_good,
 output reg [1:0] traffic_state,output wire red_detected,green_detected,
 output reg [31:0] last_red_count,last_green_count,
 output reg [1:0] raw_state,
 output reg [31:0] red_streak,green_streak,unknown_streak);
 localparam [1:0] UNKNOWN=0,RED=1,GREEN=2;
 reg [31:0] red_count,green_count;
 reg active;
 wire [6:0] r={1'b0,pixel[15:11],1'b0};
 wire [6:0] g={1'b0,pixel[10:5]};
 wire [6:0] b={1'b0,pixel[4:0],1'b0};
 wire roi=pixel_x>=ROI_X_MIN && pixel_x<=ROI_X_MAX &&
          pixel_y>=ROI_Y_MIN && pixel_y<=ROI_Y_MAX;
 wire take=pixel_valid && roi && (active || frame_start);
 wire red_pixel=take && r>=RED_BRIGHT_MIN && r>g+DOMINANCE && r>b+DOMINANCE;
 wire green_pixel=take && g>=GREEN_BRIGHT_MIN && g>r+DOMINANCE && g>b+DOMINANCE;
 // Include a coincident last pixel; widen comparisons to avoid count overflow.
 wire [31:0] rc=(frame_start ? 32'd0 : red_count)+red_pixel;
 wire [31:0] gc=(frame_start ? 32'd0 : green_count)+green_pixel;
 wire [1:0] decision=(!frame_good || !active) ? UNKNOWN :
   (rc>=RED_PIXEL_MIN && {1'b0,rc}>({1'b0,gc}+COUNT_MARGIN)) ? RED :
   (gc>=GREEN_PIXEL_MIN && {1'b0,gc}>({1'b0,rc}+COUNT_MARGIN)) ? GREEN : UNKNOWN;
 assign red_detected=traffic_state==RED;
 assign green_detected=traffic_state==GREEN;
 always @(posedge pclk or negedge rst_n) begin
  if(!rst_n) begin
   active<=0;red_count<=0;green_count<=0;last_red_count<=0;last_green_count<=0;
   raw_state<=UNKNOWN;traffic_state<=UNKNOWN;red_streak<=0;green_streak<=0;unknown_streak<=0;
  end else begin
   if(frame_start) active<=1;
   if(active || frame_start) begin red_count<=rc;green_count<=gc;end
   if(frame_done) begin
    active<=0;last_red_count<=rc;last_green_count<=gc;raw_state<=decision;
    case(decision)
     RED: begin
      green_streak<=0;unknown_streak<=0;
      if(red_streak<CONFIRM_FRAMES) red_streak<=red_streak+1;
      if(red_streak>=CONFIRM_FRAMES-1) traffic_state<=RED;
     end
     GREEN: begin
      red_streak<=0;unknown_streak<=0;
      if(green_streak<CONFIRM_FRAMES) green_streak<=green_streak+1;
      if(green_streak>=CONFIRM_FRAMES-1) traffic_state<=GREEN;
     end
     default: begin
      red_streak<=0;green_streak<=0;
      if(unknown_streak<UNKNOWN_FRAMES) unknown_streak<=unknown_streak+1;
      if(unknown_streak>=UNKNOWN_FRAMES-1) traffic_state<=UNKNOWN;
     end
    endcase
   end
  end
 end
endmodule
