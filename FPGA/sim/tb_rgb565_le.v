`timescale 1ns/1ps
module tb_rgb565_le;
reg clk=0,rst=0,enable=0,href=0,vsync=1;
reg [7:0] data=0;
wire valid,done,good;wire [15:0] pixel,x,y;
integer count=0;
always #5 clk=~clk;
dvp_rgb565_capture #(.WIDTH(3),.HEIGHT(1),.VSYNC_ACTIVE_HIGH(0),.SWAP_BYTES(1)) dut(
.pclk(clk),.rst_n(rst),.enable(enable),.data(data),.href(href),.vsync(vsync),
.pixel_valid(valid),.pixel(pixel),.pixel_x(x),.pixel_y(y),.frame_done(done),.frame_good(good));
always @(posedge clk)begin
 #1;
 if(valid)begin
 case(count)
 0:if(pixel!==16'hf800)$fatal(1,"red mismatch");
 1:if(pixel!==16'h07e0)$fatal(1,"green mismatch");
 2:if(pixel!==16'h001f)$fatal(1,"blue mismatch");
 default:$fatal(1,"extra pixel");
 endcase
 if(x!==count || y!==0)$fatal(1,"coordinate mismatch");
 count=count+1;
 end
end
task byte_in(input [7:0] b);begin @(negedge clk);href=1;data=b;end endtask
initial begin
 repeat(3)@(negedge clk);rst=1;enable=1;
 vsync=0;repeat(3)@(negedge clk);
 vsync=1;repeat(3)@(negedge clk);
 // Sensor 0x4300=0x6f: low byte, high byte per RGB565 pixel.
 byte_in(8'h00);byte_in(8'hf8);
 byte_in(8'he0);byte_in(8'h07);
 byte_in(8'h1f);byte_in(8'h00);
 @(negedge clk);href=0;repeat(3)@(negedge clk);
 vsync=0;@(posedge clk);#2;
 if(!done || !good || count!=3)$fatal(1,"frame validation failed");
 $display("PASS: RGB565 low-byte-first red/green/blue, coordinates and valid frame");
 $finish;
end
endmodule
