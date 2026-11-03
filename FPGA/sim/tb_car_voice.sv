`timescale 1ns/1ps
module tb_car_voice;
reg clk=0,rst=0,en=0,stop=0,estop=0,near=0,clear=1,fault=0;
reg traffic=0,finished=0,live=0,green=0,pause=0,lost=0;
reg [1:0] color=0;reg [4:0] gray=5'b00100;
wire [5:0] gpio;reg [5:0] prev=0;
integer count[0:5];integer i;
always #5 clk=~clk;
car_voice_controller #(.CLK_HZ(100),.PULSE_CYCLES(2),.GAP_CYCLES(5),.ZEBRA_WAIT_CYCLES(8)) dut(
.clk(clk),.rst_n(rst),.enabled(en),.stop_request(stop),.estop(estop),
.obstacle_stop(near),.start_clear(clear),.sensor_fault(fault),
.traffic_active(traffic),.finished(finished),.camera_live(live),.color(color),
.green_permitted(green),.us_pause(pause),.line_fault(lost),.gray(gray),.voice_gpio(gpio));
always @(posedge clk) begin
 #1;
 for(integer n=0;n<6;n=n+1)if(gpio[n] && !prev[n])count[n]=count[n]+1;
 if(gpio!=0 && (gpio & (gpio-1))!=0)$fatal(1,"overlapping speech outputs");
 prev=gpio;
end
task cycles(input integer n);repeat(n)@(negedge clk);endtask
initial begin
 for(i=0;i<6;i=i+1)count[i]=0;
 cycles(3);rst=1;cycles(3);en=1;cycles(20);
 if(count[0]!=0 || count[1]!=0)$fatal(1,"startup phantom obstacle/clear");
 near=1;clear=0;cycles(30);
 if(count[0]!=1)$fatal(1,"obstacle must announce once");
 near=0;clear=1;cycles(30);
 if(count[1]!=1)$fatal(1,"first clear must announce once");
 repeat(5)begin clear=0;cycles(4);clear=1;cycles(20);end
 if(count[1]!=1)$fatal(1,"clear jitter repeated removal announcement");
 near=1;clear=0;cycles(30);near=0;clear=1;cycles(30);
 if(count[0]!=2 || count[1]!=2)$fatal(1,"new obstacle episode not rearmed");
 traffic=1;live=1;color=1;cycles(40);
 if(count[2]!=1 || count[3]!=1)$fatal(1,"zebra/red missing");
 color=2;green=1;cycles(30);
 if(count[4]!=1)$fatal(1,"green missing");
 traffic=0;green=0;lost=1;gray=0;cycles(30);
 if(count[5]!=1)$fatal(1,"line lost missing");
 stop=1;near=1;cycles(25);
 if(gpio!=0 || count[0]!=2)$fatal(1,"stop must suppress speech and stale obstacle");
 stop=0;en=0;cycles(25);
 if(count[1]!=2)$fatal(1,"disabled phantom clear");
 $display("PASS: six voice events, serialized outputs, exactly one clear per obstacle, clear jitter suppression, stop cancellation");
 $finish;
end
endmodule
