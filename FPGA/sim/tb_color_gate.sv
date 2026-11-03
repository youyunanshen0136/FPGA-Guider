`timescale 1ns/1ps
module tb_color_gate;
 reg clk=0,pclk=0,run_pclk=1;
 always #4 clk=~clk;
 always #10 if(run_pclk) pclk=~pclk;
 reg rst_n=0,p_rst_n=0,configured=0,failed=0;
 reg pv=0,fs=0,fd=0,fg=1;
 reg [15:0] pixel=0,x=0,y=0;
 wire live,go; wire [1:0] observed;
 traffic_color_gate #(.FRAME_TIMEOUT_CYCLES(300000)) dut(
  .clk(clk),.rst_n(rst_n),.pclk(pclk),.p_rst_n(p_rst_n),
  .configured(configured),.failed(failed),.pixel_valid(pv),.pixel(pixel),
  .pixel_x(x),.pixel_y(y),.frame_start(fs),.frame_done(fd),.frame_good(fg),
  .observed_color(observed),.camera_live(live),.green_permitted(go));
 // A square of 400 pixels at any corner; every frame is a real 320x240 raster.
 task frame(input [15:0] color,input integer corner,input bit good);
  integer xx,yy,x0,y0;
  begin
   x0=(corner==1 || corner==3)?300:0;
   y0=(corner==2 || corner==3)?220:0;
   @(negedge pclk);fs=1;fg=good;
   @(negedge pclk);fs=0;pv=1;
   for(yy=0;yy<240;yy=yy+1) begin
    for(xx=0;xx<320;xx=xx+1) begin
     x=xx;y=yy;
     pixel=(corner==4 || (xx>=x0 && xx<x0+20 && yy>=y0 && yy<y0+20))?color:16'h0000;
     @(negedge pclk);
    end
   end
   pv=0;fd=1;
   @(negedge pclk);fd=0;
   repeat(8) @(negedge pclk);
  end
 endtask
 task check(input bit condition,input string msg);
  if(!condition) $fatal(1,"%s live=%b go=%b raw=%0d stable=%0d",msg,live,go,dut.raw_state,dut.traffic_state);
 endtask
 initial begin
  repeat(4) @(negedge clk);rst_n=1;p_rst_n=1;configured=1;
  repeat(4) @(negedge clk);check(!go && !live,"no frame must not permit");
  frame(16'h07e0,3,1);check(!go && live,"first bottom-right green");check(observed==2,"telemetry green CDC before permission");
  check(dut.last_green_count==400,"bottom-right count");
  frame(16'h07e0,3,1);check(!go,"second green");
  frame(16'h07e0,3,1);check(go,"third green permits");
  frame(16'hf800,0,1);check(!go,"first top-left red stops");check(observed==1,"telemetry red CDC");
  check(dut.last_red_count==400,"top-left count");
  frame(16'h07e0,1,1);check(!go,"green re-confirm 1");
  frame(16'h07e0,1,1);check(!go,"green re-confirm 2");
  frame(16'h07e0,1,1);check(go,"top-right green");
  frame(16'hf800,2,1);check(!go,"bottom-left red");
  frame(16'h07e0,4,1);frame(16'h07e0,4,1);frame(16'h07e0,4,1);
  check(go && dut.last_green_count==76800,"whole solid green frame: no shape/maximum-area restriction");
  frame(16'hffff,4,1);check(!go,"unknown white stops without five-frame delay");
  frame(16'h07e0,4,1);frame(16'h07e0,4,1);frame(16'h07e0,4,1);check(go,"green after unknown");
  frame(16'h07e0,4,0);check(!go,"bad frame stops");check(observed==0,"bad frame telemetry unknown");
  frame(16'h07e0,4,1);frame(16'h07e0,4,1);frame(16'h07e0,4,1);check(go,"green after bad frame");
  run_pclk=0;repeat(300010) @(negedge clk);check(!live && !go,"stopped PCLK watchdog");check(observed==0,"stopped PCLK telemetry unknown");
  run_pclk=1;frame(16'h07e0,4,1);check(live && go,"fresh frame recovers timeout");
  failed=1;#1;check(!go,"initialization failure closes permission");
  failed=0;configured=0;#1;check(!go,"not configured");
  $display("PASS tb_color_gate: full raster corners, square/solid colors, green confirmation, immediate red/unknown/bad stop, stopped PCLK");
  $finish;
 end
 initial begin #60000000;$fatal(1,"watchdog");end
endmodule
