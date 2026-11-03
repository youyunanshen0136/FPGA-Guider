`timescale 1ns/1ps
// Single register SCCB transfer. Open-drain SCL/SDA; external 2.8V pullups.
// Read sequence uses STOP then START, matching the supplied vendor driver.
module sccb_master #(
 parameter integer CLK_HZ=125000000, BUS_HZ=100000,
 parameter integer STRETCH_TICKS=400
)(input wire clk,rst_n,start,read_en,input wire [15:0] reg_addr,
 input wire [7:0] wr_data,output reg [7:0] rd_data,
 output reg busy,done,error,inout wire scl,sda);
localparam integer DIV=(CLK_HZ/(BUS_HZ*4)<1)?1:CLK_HZ/(BUS_HZ*4);
localparam IDLE=0,START0=1,START1=2,START2=3,SETBIT=4,RISE=5,
 SAMPLE=6,FALL=7,ACKSET=8,ACKRISE=9,ACKSAMPLE=10,ACKFALL=11,
 STOP0=12,STOP1=13,STOP2=14,STOP3=15;
reg [4:0] state; reg [31:0] divider,wait_count;
reg scl_low,sda_low; reg [2:0] bit_no;
reg [2:0] byte_no; reg [7:0] tx_byte,write_latch;
reg [15:0] addr_latch; reg reading,read_phase,receiving,restart;
assign scl=scl_low?1'b0:1'bz;
assign sda=sda_low?1'b0:1'bz;
always @(posedge clk) begin
 if(!rst_n) begin
  state<=IDLE; divider<=0; wait_count<=0; scl_low<=0;sda_low<=0;
  busy<=0;done<=0;error<=0;rd_data<=0;bit_no<=7;byte_no<=0;
  tx_byte<=0;write_latch<=0;addr_latch<=0;reading<=0;read_phase<=0;receiving<=0;restart<=0;
 end else begin
  done<=0;
  if(state==IDLE) begin
   divider<=0;
   if(start) begin
    busy<=1;error<=0;rd_data<=0;addr_latch<=reg_addr;write_latch<=wr_data;
    reading<=read_en;read_phase<=0;receiving<=0;restart<=0;
    byte_no<=0;tx_byte<=8'h78;bit_no<=7;state<=START0;wait_count<=0;
   end
  end else if(divider==DIV-1) begin
   divider<=0;
   case(state)
    START0: begin
     scl_low<=0;sda_low<=0;
     if(scl && sda) begin state<=START1;wait_count<=0;end
     else if(wait_count==STRETCH_TICKS) begin error<=1;state<=STOP0;restart<=0;end
     else wait_count<=wait_count+1;
    end
    START1: begin sda_low<=1;state<=START2;end
    START2: begin scl_low<=1;state<=SETBIT;end
    SETBIT: begin sda_low<=receiving?1'b0:!tx_byte[bit_no];state<=RISE;end
    RISE: begin scl_low<=0;state<=SAMPLE;wait_count<=0;end
    SAMPLE: begin
     if(scl) begin if(receiving) rd_data[bit_no]<=sda;state<=FALL;end
     else if(wait_count==STRETCH_TICKS) begin error<=1;restart<=0;state<=STOP0;end
     else wait_count<=wait_count+1;
    end
    FALL: begin
     scl_low<=1;
     if(bit_no==0) state<=ACKSET;
     else begin bit_no<=bit_no-1;state<=SETBIT;end
    end
    ACKSET: begin sda_low<=0;state<=ACKRISE;end // master NACK after one read byte
    ACKRISE: begin scl_low<=0;state<=ACKSAMPLE;wait_count<=0;end
    ACKSAMPLE: begin
     if(scl) begin if(!receiving && sda) error<=1;state<=ACKFALL;end
     else if(wait_count==STRETCH_TICKS) begin error<=1;restart<=0;state<=STOP0;end
     else wait_count<=wait_count+1;
    end
    ACKFALL: begin
     scl_low<=1; bit_no<=7;
     if(error || receiving) begin restart<=0;state<=STOP0;end
     else if(read_phase) begin receiving<=1;state<=SETBIT;end
     else case(byte_no)
      0: begin byte_no<=1;tx_byte<=addr_latch[15:8];state<=SETBIT;end
      1: begin byte_no<=2;tx_byte<=addr_latch[7:0];state<=SETBIT;end
      2: if(reading) begin restart<=1;state<=STOP0;end
         else begin byte_no<=3;tx_byte<=write_latch;state<=SETBIT;end
      default: begin restart<=0;state<=STOP0;end
     endcase
    end
    STOP0: begin scl_low<=1;sda_low<=1;state<=STOP1;end
    STOP1: begin scl_low<=0;wait_count<=0;state<=STOP2;end
    STOP2: begin
     if(scl) begin sda_low<=0;state<=STOP3;end
     else if(wait_count==STRETCH_TICKS) begin error<=1;sda_low<=0;restart<=0;state<=STOP3;end
     else wait_count<=wait_count+1;
    end
    STOP3: if(restart && !error) begin
     restart<=0;read_phase<=1;tx_byte<=8'h79;state<=START0;wait_count<=0;
    end else begin busy<=0;done<=1;state<=IDLE;end
    default: state<=IDLE;
   endcase
  end else divider<=divider+1;
 end
end
endmodule
