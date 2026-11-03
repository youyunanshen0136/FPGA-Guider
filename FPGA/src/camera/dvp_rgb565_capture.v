`timescale 1ns/1ps
// Every output is synchronous to PCLK. No pixel CDC or frame buffering.
// Ignore initial partial frame; resynchronize on VSYNC. HREF active high.
module dvp_rgb565_capture #(
 parameter integer WIDTH=320,HEIGHT=240,
 parameter VSYNC_ACTIVE_HIGH=1, SWAP_BYTES=0
)(input wire pclk,rst_n,enable,input wire [7:0] data,
 input wire href,vsync,output reg pixel_valid,output reg [15:0] pixel,
 output reg [15:0] pixel_x,pixel_y,output reg frame_start,frame_done,frame_good,
 output reg [15:0] last_lines,last_line_pixels,
 output reg [31:0] last_pixels,frame_count,bad_frame_count);
wire sync_active=VSYNC_ACTIVE_HIGH?vsync:!vsync;
reg sync_d,href_d,armed,active,half_byte,bad;
reg [7:0] high_byte;reg [15:0] x,lines;reg [31:0] pixels;
wire closing_line=href_d;
wire [16:0] final_lines={1'b0,lines}+closing_line;
wire valid_end=!bad && !half_byte && (!closing_line || x==WIDTH) &&
               final_lines==HEIGHT && pixels==WIDTH*HEIGHT;
always @(posedge pclk or negedge rst_n) begin
 if(!rst_n) begin
  sync_d<=0;href_d<=0;armed<=0;active<=0;half_byte<=0;bad<=0;
  high_byte<=0;x<=0;lines<=0;pixels<=0;pixel_valid<=0;pixel<=0;pixel_x<=0;pixel_y<=0;
  frame_start<=0;frame_done<=0;frame_good<=0;last_lines<=0;last_line_pixels<=0;
  last_pixels<=0;frame_count<=0;bad_frame_count<=0;
 end else begin
  pixel_valid<=0;frame_start<=0;frame_done<=0;
  sync_d<=sync_active;href_d<=href;
  if(!enable) begin armed<=0;active<=0;half_byte<=0;bad<=0;x<=0;lines<=0;pixels<=0;end
  else if(sync_active) begin
   armed<=1;active<=0;half_byte<=0;x<=0;lines<=0;pixels<=0;bad<=0;
   if(!sync_d && active) begin
    frame_done<=1;frame_good<=valid_end;last_lines<=final_lines[15:0];
    if(closing_line) last_line_pixels<=x;
    last_pixels<=pixels;frame_count<=frame_count+1;
    if(!valid_end) bad_frame_count<=bad_frame_count+1;
   end
  end else if(sync_d && armed) begin
   active<=1;frame_start<=1; // expect vertical blanking before first HREF
   if(href) bad<=1;
  end else if(active) begin
   if(href) begin
    if(!half_byte) begin high_byte<=data;half_byte<=1;end
    else begin
     half_byte<=0;pixel<=SWAP_BYTES?{data,high_byte}:{high_byte,data};
     pixel_x<=x;pixel_y<=lines;
     pixel_valid<=(x<WIDTH && lines<HEIGHT);
     if(x>=WIDTH || lines>=HEIGHT) bad<=1;
     if(x!=16'hffff) x<=x+1;else bad<=1;
     if(pixels!=32'hffffffff) pixels<=pixels+1;else bad<=1;
    end
   end else if(href_d) begin
    if(half_byte || x!=WIDTH) bad<=1;
    half_byte<=0;last_line_pixels<=x;x<=0;
    if(lines!=16'hffff) lines<=lines+1;else bad<=1;
   end
  end
 end
end
endmodule
