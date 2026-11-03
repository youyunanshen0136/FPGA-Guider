`timescale 1ns/1ps
module tb_zebra_sequence;
reg clk=0,reset=1,stop=0,green=1,live=1;
reg [1:0] color=2;reg [4:0] sensors=5'b00100;
always #500 clk=~clk;
wire [5:0] voice;
line_ultrasonic_stop_top #(.CLK_HZ(1000000),.BUTTON_CYCLES(2),
.ZEBRA_WAIT_CYCLES(20),.VOICE_PULSE_CYCLES(3),.VOICE_GAP_CYCLES(8),
.TRAFFIC_STRAIGHT_CYCLES(300),.MAX_RUN_CYCLES(2000000)) dut(
.clk(clk),.reset_button(reset),.start_button(1'b0),.stop_button(stop),
.gray(5'b00100),.us_echo(1'b0),.estop_n(1'b1),.help_btn_n(1'b1),.esp_rx(1'b1),
.cam_pclk(clk),.cam_data(8'd0),.cam_href(1'b0),.cam_vsync(1'b1),.voice_gpio(voice));
integer cycle=0,zebra_at=-1,zebra_count=0,green_count=0,red_count=0;
reg [5:0] previous=0;
always @(posedge clk)begin
 #1;cycle=cycle+1;
 if(voice[2] && !previous[2])begin zebra_at=cycle;zebra_count=zebra_count+1;end
 if((voice[3]&&!previous[3]) || (voice[4]&&!previous[4]))begin
  if(zebra_at<0 || cycle-zebra_at<20)$fatal(1,"light speech before zebra dwell");
 end
 if(voice[4] && !previous[4])begin
  green_count=green_count+1;
  if(!dut.traffic_drive)$fatal(1,"green GPIO and drive authorization are not simultaneous");
 end
 if(voice[3] && !previous[3])begin
  red_count=red_count+1;
  if(dut.traffic_drive)$fatal(1,"red speech while moving");
 end
 if(green_count==0 && dut.traffic_active && dut.traffic_drive)$fatal(1,"moved before first green speech");
 previous=voice;
end
task tick(input integer n);repeat(n)@(negedge clk);endtask
initial begin
 force dut.core.enabled=1;
 force dut.core.gray=sensors;
 force dut.core.us_pause=0;force dut.core.us_resume_pending=0;
 force dut.core.us_sensor_fault=0;force dut.core.obstacle_stop=0;
 force dut.core.us_start_clear=1;force dut.core.line_fault=0;
 force dut.core.estop_latched=0;force dut.stop_request=stop;
 force dut.camera_green=green;force dut.camera_live=live;force dut.telemetry_color=color;
 tick(30);reset=0;tick(15);
 // Already green on arrival must still stop, announce zebra, dwell, then speak green.
 sensors=5'b11111;tick(5);
 if(zebra_count!=1 || dut.traffic_drive)$fatal(1,"initial green bypassed zebra stop");
 tick(35);
 if(green_count!=1 || !dut.traffic_drive)$fatal(1,"initial green announcement or drive missing");
 tick(8);green=0;color=1;#1;
 if(dut.traffic_drive)$fatal(1,"red did not stop immediately");
 tick(25);if(red_count!=1)$fatal(1,"red announcement missing");
 green=1;color=2;tick(25);
 if(green_count!=2 || !dut.traffic_drive)$fatal(1,"red-to-green restart missing");
 live=0;#1;if(dut.traffic_drive)$fatal(1,"camera loss did not stop");
 tick(5);live=1;tick(25);
 if(green_count!=3 || !dut.traffic_drive)$fatal(1,"camera recovery did not require fresh green speech");
 stop=1;#1;if(dut.traffic_drive)$fatal(1,"stop did not override speech");
 tick(5);if(voice!=0)$fatal(1,"stop did not cancel outputs");
 // New run with red at entry: zebra first, dwell, red, then green.
 reset=1;stop=0;green=0;color=1;sensors=5'b00100;
 tick(20);reset=0;tick(12);sensors=5'b11111;tick(40);
 if(zebra_count!=2 || red_count!=2 || dut.traffic_drive)$fatal(1,"initial red sequence failed");
 green=1;color=2;tick(25);
 if(green_count!=4 || !dut.traffic_drive)$fatal(1,"initial red then green failed");
 $display("PASS: initial green/red both stop and announce zebra, dwell, synchronize green GPIO/drive, red/camera/stop overrides");
 $finish;
end
initial begin #10000000;$fatal(1,"watchdog");end
endmodule
