// Control-regression-only stub; never included by synthesis source_files.tcl.
module hdmi_preview(input wire clk125,reset_n,pclk,pixel_valid,
input wire [15:0] pixel,pixel_x,pixel_y,input wire frame_done,frame_good,
output wire hdmi_out_clk_p,hdmi_out_clk_n,
output wire [2:0] hdmi_out_data_p,hdmi_out_data_n);
assign hdmi_out_clk_p=0;assign hdmi_out_clk_n=1;
assign hdmi_out_data_p=0;assign hdmi_out_data_n=7;
endmodule
