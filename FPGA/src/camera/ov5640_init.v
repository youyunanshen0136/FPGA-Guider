`timescale 1ns/1ps
// B register profile, with bounded per-operation retries and post-write readback.
// A retry repeats only the current bus transaction; failed configuration stays closed.
module ov5640_init #(
 parameter integer CLK_HZ=125000000, BUS_HZ=100000,
 parameter integer MS_CYCLES=CLK_HZ/1000, parameter TEST_PATTERN=1,
 parameter integer MAX_RETRIES=2
)(input wire clk,rst_n,output reg cam_reset_n,cam_pwdn,
 inout wire cam_scl,cam_sda,output reg configured,failed,
 output reg [3:0] error_code,output reg [15:0] chip_id,
 output reg [2:0] fail_verify_index,output reg [7:0] fail_read_data,
 output reg [9:0] config_index);
localparam BOOT=0,POWER=1,RESETWAIT=2,ISSUE=3,WAITBUS=4,DELAY=5,
 SETTLE=6,FAIL=7,RETRYWAIT=8,FINISH=9;
localparam ID_HI=0,ID_LO=1,WRITE=2,VERIFY=3;
reg [3:0] state;
reg [31:0] timer;
reg [1:0] op;
reg [2:0] verify_index;
reg [7:0] retries;
reg start,read_en;
reg [15:0] addr;
reg [7:0] data;
wire done,bus_error,busy;
wire [7:0] read_data;
wire [23:0] word;
wire last;
reg [15:0] verify_addr;
reg [7:0] verify_expected;
always @* begin
 case(verify_index)
  0: begin verify_addr=16'h3808;verify_expected=8'h01;end
  1: begin verify_addr=16'h3809;verify_expected=8'h40;end
  2: begin verify_addr=16'h380a;verify_expected=8'h00;end
  3: begin verify_addr=16'h380b;verify_expected=8'hf0;end
  // Preserve B's RGB565 profile: 0x6f, NOT A's 0x61.
  4: begin verify_addr=16'h4300;verify_expected=8'h6f;end
  5: begin verify_addr=16'h501f;verify_expected=8'h01;end
  default: begin verify_addr=16'h503d;verify_expected=TEST_PATTERN?8'h80:8'h00;end
 endcase
end
wire id_bad=(op==ID_HI && read_data!=8'h56) || (op==ID_LO && read_data!=8'h40);
wire verify_bad=op==VERIFY && read_data!=verify_expected;
wire operation_bad=bus_error || id_bad || verify_bad;
wire [3:0] failure_code=bus_error ? (op<WRITE?4'd1:op==WRITE?4'd3:4'd4) :
                       (op<WRITE?4'd2:4'd5);
ov5640_reg_rom #(.TEST_PATTERN(TEST_PATTERN)) rom(config_index,word,last);
sccb_master #(.CLK_HZ(CLK_HZ),.BUS_HZ(BUS_HZ)) bus(
 .clk(clk),.rst_n(rst_n),.start(start),.read_en(read_en),.reg_addr(addr),.wr_data(data),
 .rd_data(read_data),.busy(busy),.done(done),.error(bus_error),.scl(cam_scl),.sda(cam_sda));
always @(posedge clk) begin
 if(!rst_n) begin
  state<=BOOT;timer<=0;op<=ID_HI;verify_index<=0;retries<=0;
  start<=0;read_en<=0;addr<=0;data<=0;
  cam_reset_n<=0;cam_pwdn<=1;configured<=0;failed<=0;error_code<=0;chip_id<=0;config_index<=0;
  fail_verify_index<=0;fail_read_data<=0;
 end else begin
  start<=0;
  case(state)
   BOOT: if(timer>=20*MS_CYCLES-1) begin timer<=0;cam_pwdn<=0;state<=POWER;end else timer<=timer+1;
   POWER: if(timer>=5*MS_CYCLES-1) begin timer<=0;cam_reset_n<=1;state<=RESETWAIT;end else timer<=timer+1;
   RESETWAIT: if(timer>=25*MS_CYCLES-1) begin timer<=0;state<=ISSUE;end else timer<=timer+1;
   ISSUE: if(!busy) begin
    read_en<=op!=WRITE;
    addr<=op==ID_HI?16'h300a:op==ID_LO?16'h300b:op==VERIFY?verify_addr:word[23:8];
    data<=word[7:0];start<=1;state<=WAITBUS;
   end
   WAITBUS: if(done) begin
    if(op==ID_HI) chip_id[15:8]<=read_data;
    if(op==ID_LO) chip_id[7:0]<=read_data;
    if(operation_bad) begin
     if(retries<MAX_RETRIES) begin retries<=retries+1'b1;timer<=0;state<=RETRYWAIT;end
     else begin
      error_code<=failure_code;failed<=1;configured<=0;state<=FAIL;
      fail_verify_index<=verify_index;fail_read_data<=read_data;
     end
    end else begin
     retries<=0;
     case(op)
      ID_HI: begin op<=ID_LO;state<=ISSUE;end
      ID_LO: begin op<=WRITE;state<=ISSUE;end
      WRITE: if(last) begin timer<=0;state<=SETTLE;end
       else if(config_index==1) begin timer<=0;config_index<=config_index+1'b1;state<=DELAY;end
       else begin config_index<=config_index+1'b1;state<=ISSUE;end
      VERIFY: if(verify_index==6) begin configured<=1;state<=FINISH;end
       else begin verify_index<=verify_index+1'b1;state<=ISSUE;end
     endcase
    end
   end
   DELAY: if(timer>=10*MS_CYCLES-1) begin timer<=0;state<=ISSUE;end else timer<=timer+1;
   SETTLE: if(timer>=20*MS_CYCLES-1) begin timer<=0;op<=VERIFY;verify_index<=0;state<=ISSUE;end else timer<=timer+1;
   RETRYWAIT: if(timer>=MS_CYCLES-1) begin timer<=0;state<=ISSUE;end else timer<=timer+1;
   FINISH: configured<=1;
   FAIL: begin failed<=1;configured<=0;end
   default: begin failed<=1;configured<=0;error_code<=15;state<=FAIL;end
  endcase
 end
end
// synthesis translate_off
initial if(MS_CYCLES<1 || MAX_RETRIES<0 || MAX_RETRIES>255) $fatal(1,"Invalid camera init parameters");
// synthesis translate_on
endmodule
