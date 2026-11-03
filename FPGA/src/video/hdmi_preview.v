`timescale 1ns/1ps
// Independent live-view framebuffer. Display-only: never authorizes motor motion.
// Single buffer can tear during updates; network capture uses its separate frozen buffer.
module hdmi_preview(input wire clk125,reset_n,pclk,pixel_valid,
 input wire [15:0] pixel,pixel_x,pixel_y,input wire frame_done,frame_good,
 output wire hdmi_out_clk_p,hdmi_out_clk_n,
 output wire [2:0] hdmi_out_data_p,hdmi_out_data_n);
 wire feedback,feedback_buf,px_raw,ser_raw,px,ser,locked;
 MMCME2_BASE #(.CLKIN1_PERIOD(8.0),.DIVCLK_DIVIDE(5),.CLKFBOUT_MULT_F(40.25),
 .CLKOUT0_DIVIDE_F(40.0),.CLKOUT1_DIVIDE(8)) clocks(
 .CLKIN1(clk125),.CLKFBIN(feedback_buf),.CLKFBOUT(feedback),.CLKOUT0(px_raw),
 .CLKOUT1(ser_raw),.LOCKED(locked),.PWRDWN(1'b0),.RST(!reset_n));
 BUFG fb(.I(feedback),.O(feedback_buf));BUFG pb(.I(px_raw),.O(px));BUFG sb(.I(ser_raw),.O(ser));
 wire px_board_ready,px_lock_ready;
 reset_sync pr(px,reset_n,px_board_ready);
 reset_sync lock_reset(px,locked,px_lock_ready);
 wire pix_reset_n=px_board_ready && px_lock_ready;
 wire cam_reset_n;reset_sync cr(pclk,reset_n,cam_reset_n);
 (* ram_style="block" *) reg [15:0] display_ram[0:76799];
 wire [16:0] write_address=pixel_y*17'd320+pixel_x;
 // Register RAM controls without asynchronous reset; prior contents remain hidden
 // until a complete good frame has overwritten the buffer after reset.
 reg write_enable;reg [16:0] address_pipe;reg [15:0] pixel_pipe;
 always @(posedge pclk)begin
 write_enable<=cam_reset_n && pixel_valid && pixel_x<320 && pixel_y<240;
 address_pipe<=write_address;pixel_pipe<=pixel;
 if(write_enable)display_ram[address_pipe]<=pixel_pipe;
 end
 reg heartbeat;
 always @(posedge pclk or negedge cam_reset_n)
 if(!cam_reset_n)heartbeat<=0;else if(frame_done && frame_good)heartbeat<=~heartbeat;
 (* ASYNC_REG="TRUE" *) reg [2:0] heartbeat_sync;
 reg hb_seen;reg [24:0] age;
 always @(posedge px) if(!pix_reset_n)begin heartbeat_sync<=0;hb_seen<=0;age<=25156250;end
 else begin heartbeat_sync<={heartbeat_sync[1:0],heartbeat};hb_seen<=heartbeat_sync[2];
 if(heartbeat_sync[2]!=hb_seen)age<=0;else if(age<25156250)age<=age+1;end
 reg [9:0] x,y;reg de,hs,vs;reg [15:0] sample;
 wire active=x<640 && y<480;
 wire [16:0] read_address=(y>>1)*17'd320+(x>>1);
 always @(posedge px)begin
 if(!pix_reset_n)begin x<=0;y<=0;de<=0;hs<=1;vs<=1;end
 else begin
 if(x==799)begin x<=0;if(y==524)y<=0;else y<=y+1;end else x<=x+1;
 de<=active;hs<=!(x>=656 && x<752);vs<=!(y>=490 && y<492);
 end
 if(active)sample<=display_ram[read_address];
 end
 wire [15:0] visible_sample=age<25156250 ? sample : 16'd0;
 wire [7:0] red={visible_sample[15:11],visible_sample[15:13]},green={visible_sample[10:5],visible_sample[10:9]},blue={visible_sample[4:0],visible_sample[4:2]};
 wire [9:0] tr,tg,tb;
 tmds_encode er(px,!pix_reset_n,de,1'b0,1'b0,red,tr);
 tmds_encode eg(px,!pix_reset_n,de,1'b0,1'b0,green,tg);
 tmds_encode eb(px,!pix_reset_n,de,hs,vs,blue,tb);
 tmds_lane lr(px,ser,!pix_reset_n,tr,hdmi_out_data_p[2],hdmi_out_data_n[2]);
 tmds_lane lg(px,ser,!pix_reset_n,tg,hdmi_out_data_p[1],hdmi_out_data_n[1]);
 tmds_lane lb(px,ser,!pix_reset_n,tb,hdmi_out_data_p[0],hdmi_out_data_n[0]);
 wire clock_out;
 ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) co(.C(px),.CE(1'b1),.D1(1'b1),.D2(1'b0),.Q(clock_out),.R(!pix_reset_n),.S(1'b0));
 OBUFDS #(.IOSTANDARD("TMDS_33")) cb(.I(clock_out),.O(hdmi_out_clk_p),.OB(hdmi_out_clk_n));
endmodule

module tmds_encode(input wire clk,rst,de,c0,c1,input wire [7:0] data,output reg [9:0] symbol);
 integer i,ones,balance;reg use_xnor;reg [8:0] q;reg signed [5:0] disparity;
 always @* begin
 ones=0;for(i=0;i<8;i=i+1)ones=ones+data[i];
 use_xnor=(ones>4 || (ones==4 && !data[0]));q[0]=data[0];
 for(i=1;i<8;i=i+1)q[i]=use_xnor ? ~(q[i-1]^data[i]) : q[i-1]^data[i];
 q[8]=!use_xnor;ones=0;for(i=0;i<8;i=i+1)ones=ones+q[i];balance=2*ones-8;
 end
 always @(posedge clk)begin
 if(rst)begin symbol<=10'b1101010100;disparity<=0;end
 else if(!de)begin disparity<=0;case({c1,c0})
 0:symbol<=10'b1101010100;1:symbol<=10'b0010101011;
 2:symbol<=10'b0101010100;3:symbol<=10'b1010101011;endcase end
 else if(disparity==0 || ones==4)begin
 symbol<={~q[8],q[8],q[8]?q[7:0]:~q[7:0]};disparity<=disparity+(q[8]?balance:-balance);
 end else if((disparity>0 && balance>0)||(disparity<0 && balance<0))begin
 symbol<={1'b1,q[8],~q[7:0]};disparity<=disparity+(q[8]?2:0)-balance;
 end else begin symbol<={1'b0,q[8],q[7:0]};disparity<=disparity+balance-(q[8]?0:2);end
 end
endmodule

module tmds_lane(input wire px,ser,rst,input wire [9:0] data,output wire p,n);
 wire out,s1,s2;
 OSERDESE2 #(.DATA_RATE_OQ("DDR"),.DATA_RATE_TQ("SDR"),.DATA_WIDTH(10),.SERDES_MODE("MASTER"),.TRISTATE_WIDTH(1)) master(
 .CLK(ser),.CLKDIV(px),.RST(rst),.OCE(1'b1),.OQ(out),
 .D1(data[0]),.D2(data[1]),.D3(data[2]),.D4(data[3]),.D5(data[4]),.D6(data[5]),.D7(data[6]),.D8(data[7]),
 .SHIFTIN1(s1),.SHIFTIN2(s2),.T1(1'b0),.T2(1'b0),.T3(1'b0),.T4(1'b0),.TCE(1'b0),.TBYTEIN(1'b0));
 OSERDESE2 #(.DATA_RATE_OQ("DDR"),.DATA_RATE_TQ("SDR"),.DATA_WIDTH(10),.SERDES_MODE("SLAVE"),.TRISTATE_WIDTH(1)) slave(
 .CLK(ser),.CLKDIV(px),.RST(rst),.OCE(1'b1),.SHIFTOUT1(s1),.SHIFTOUT2(s2),
 .D1(1'b0),.D2(1'b0),.D3(data[8]),.D4(data[9]),.D5(1'b0),.D6(1'b0),.D7(1'b0),.D8(1'b0),
 .SHIFTIN1(1'b0),.SHIFTIN2(1'b0),.T1(1'b0),.T2(1'b0),.T3(1'b0),.T4(1'b0),.TCE(1'b0),.TBYTEIN(1'b0));
 OBUFDS #(.IOSTANDARD("TMDS_33")) ob(.I(out),.O(p),.OB(n));
endmodule

