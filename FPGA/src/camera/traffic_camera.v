`timescale 1ns/1ps
module traffic_camera #(
 parameter integer CLK_HZ=125000000
)(input wire clk,reset_n,cam_pclk,input wire [7:0] cam_data,
 input wire cam_href,cam_vsync,inout wire cam_scl,cam_sda,
 output wire [1:0] observed_color,
 output wire hdmi_out_clk_p,hdmi_out_clk_n,
 output wire [2:0] hdmi_out_data_p,hdmi_out_data_n,
 output wire cam_reset_n,output wire green_permitted,camera_live);
 wire rst_n,p_rst_n,reset_release,configured,failed;
 wire pixel_valid,frame_start,frame_done,frame_good;
 wire [15:0] pixel,pixel_x,pixel_y;
 reset_sync sys_reset(clk,reset_n,rst_n);
 reset_sync pix_reset(cam_pclk,reset_n,p_rst_n);
 // Preserve the verified module-side pull-up/open-drain reset connection.
 assign cam_reset_n=reset_release ? 1'bz : 1'b0;
 ov5640_frontend #(.CLK_HZ(CLK_HZ),.TEST_PATTERN(0),
  .VSYNC_ACTIVE_HIGH(0),.SWAP_BYTES(1)) camera(
  .clk(clk),.reset_n(reset_n),.cam_pclk(cam_pclk),.cam_data(cam_data),
  .cam_href(cam_href),.cam_vsync(cam_vsync),.cam_scl(cam_scl),.cam_sda(cam_sda),
  .cam_reset_n(reset_release),.cam_pwdn(),.configured(configured),.failed(failed),
  .error_code(),.chip_id(),.config_index(),.fail_verify_index(),.fail_read_data(),
  .pixel_enabled(),.pixel_valid(pixel_valid),.pixel(pixel),.pixel_x(pixel_x),.pixel_y(pixel_y),
  .frame_start(frame_start),.frame_done(frame_done),.frame_good(frame_good),
  .last_lines(),.last_line_pixels(),.last_pixels(),.frame_count(),.bad_frame_count());
 // Identical display module and RGB565 byte order to the board-confirmed color fix.
 hdmi_preview display(.clk125(clk),.reset_n(reset_n),.pclk(cam_pclk),
 .pixel_valid(pixel_valid),.pixel(pixel),.pixel_x(pixel_x),.pixel_y(pixel_y),
 .frame_done(frame_done),.frame_good(frame_good),
 .hdmi_out_clk_p(hdmi_out_clk_p),.hdmi_out_clk_n(hdmi_out_clk_n),
 .hdmi_out_data_p(hdmi_out_data_p),.hdmi_out_data_n(hdmi_out_data_n));
 traffic_color_gate #(.CLK_HZ(CLK_HZ)) gate(
  .clk(clk),.rst_n(rst_n),.pclk(cam_pclk),.p_rst_n(p_rst_n),
  .configured(configured),.failed(failed),.pixel_valid(pixel_valid),.pixel(pixel),
  .pixel_x(pixel_x),.pixel_y(pixel_y),.frame_start(frame_start),
  .frame_done(frame_done),.frame_good(frame_good),
  .observed_color(observed_color),.camera_live(camera_live),.green_permitted(green_permitted));
endmodule
