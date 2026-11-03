`timescale 1ns/1ps
// Reusable camera boundary. Control/debug -> clk; pixel stream -> cam_pclk.
module ov5640_frontend #(
 parameter integer CLK_HZ=125000000, BUS_HZ=100000,
 parameter TEST_PATTERN=1, VSYNC_ACTIVE_HIGH=1, SWAP_BYTES=0
)(input wire clk,reset_n,cam_pclk,input wire [7:0] cam_data,
 input wire cam_href,cam_vsync,inout wire cam_scl,cam_sda,
 output wire cam_reset_n,cam_pwdn,configured,failed,
 output wire [3:0] error_code,output wire [15:0] chip_id,output wire [9:0] config_index,
 output wire [2:0] fail_verify_index,output wire [7:0] fail_read_data,
 output wire pixel_enabled,output wire pixel_valid,output wire [15:0] pixel,pixel_x,pixel_y,
 output wire frame_start,frame_done,frame_good,
 output wire [15:0] last_lines,last_line_pixels,
 output wire [31:0] last_pixels,frame_count,bad_frame_count);
wire rst_sys_n,rst_pix_n;
reset_sync sys_reset(clk,reset_n,rst_sys_n);
reset_sync pix_reset(cam_pclk,reset_n,rst_pix_n);
ov5640_init #(.CLK_HZ(CLK_HZ),.BUS_HZ(BUS_HZ),.TEST_PATTERN(TEST_PATTERN)) init(
 .clk(clk),.rst_n(rst_sys_n),.cam_reset_n(cam_reset_n),.cam_pwdn(cam_pwdn),
 .cam_scl(cam_scl),.cam_sda(cam_sda),.configured(configured),.failed(failed),
 .error_code(error_code),.chip_id(chip_id),.config_index(config_index),
 .fail_verify_index(fail_verify_index),.fail_read_data(fail_read_data));
(* ASYNC_REG="TRUE" *) reg [1:0] cfg_sync;
always @(posedge cam_pclk or negedge rst_pix_n)
 if(!rst_pix_n) cfg_sync<=0;else cfg_sync<={cfg_sync[0],configured};
assign pixel_enabled=cfg_sync[1];
// Capture the entire source-synchronous bus together, never synchronize bits individually.
reg [7:0] data_q;reg href_q,vsync_q;
always @(posedge cam_pclk) begin data_q<=cam_data;href_q<=cam_href;vsync_q<=cam_vsync;end
dvp_rgb565_capture #(.VSYNC_ACTIVE_HIGH(VSYNC_ACTIVE_HIGH),.SWAP_BYTES(SWAP_BYTES)) capture(
 .pclk(cam_pclk),.rst_n(rst_pix_n),.enable(cfg_sync[1]),.data(data_q),.href(href_q),.vsync(vsync_q),
 .pixel_valid(pixel_valid),.pixel(pixel),.pixel_x(pixel_x),.pixel_y(pixel_y),
 .frame_start(frame_start),.frame_done(frame_done),.frame_good(frame_good),
 .last_lines(last_lines),.last_line_pixels(last_line_pixels),.last_pixels(last_pixels),
 .frame_count(frame_count),.bad_frame_count(bad_frame_count));
endmodule
