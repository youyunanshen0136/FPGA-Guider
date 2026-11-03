`timescale 1ns/1ps
// Existing ASRPRO mapping: PA0 obstacle, PA1 cleared, PA2 zebra,
// PA3 red, PA5 green, PA6 line lost. Green pulse also authorizes traffic motion.
module car_voice_controller #(
 parameter integer CLK_HZ=125000000,
 parameter integer PULSE_CYCLES=CLK_HZ/10,
 parameter integer GAP_CYCLES=CLK_HZ*4,
 parameter integer ZEBRA_WAIT_CYCLES=CLK_HZ*3/2
)(input wire clk,rst_n,enabled,stop_request,estop,
 input wire obstacle_stop,start_clear,sensor_fault,
 input wire traffic_active,finished,camera_live,
 input wire [1:0] color,input wire green_permitted,us_pause,line_fault,
 input wire [4:0] gray,output wire [5:0] voice_gpio,
 output wire traffic_go_authorized);
wire running=enabled && !stop_request && !estop;
reg clear_armed;
reg [5:0] gpio_prev;
wire obstacle_spoken=voice_gpio[0] && !gpio_prev[0];
wire clear_spoken=voice_gpio[1] && !gpio_prev[1];
wire zebra_spoken=voice_gpio[2] && !gpio_prev[2];
wire green_spoken=voice_gpio[4] && !gpio_prev[4];
reg zebra_announced,green_authorized;
reg [31:0] zebra_age;
wire light_ready=zebra_announced && zebra_age>=ZEBRA_WAIT_CYCLES-1;
wire green_now=running && traffic_active && !finished && camera_live &&
               green_permitted && color==2'd2 && !us_pause;
// Authorize on the same clock edge as the actual GPIO pulse, not when queued.
assign traffic_go_authorized=green_now && (green_authorized || green_spoken);
always @(posedge clk) begin
 if(!rst_n || !running || !traffic_active || finished) begin
  zebra_announced<=0;zebra_age<=0;green_authorized<=0;
 end else begin
  if(zebra_spoken) begin zebra_announced<=1;zebra_age<=0;end
  else if(zebra_announced && zebra_age<ZEBRA_WAIT_CYCLES) zebra_age<=zebra_age+1'b1;
  if(!green_now) green_authorized<=0;
  else if(green_spoken) green_authorized<=1;
 end
end
always @(posedge clk) begin
 if(!rst_n || !running) begin clear_armed<=0;gpio_prev<=0;end
 else begin
  gpio_prev<=voice_gpio;
  // Consume exactly one clear announcement per actually emitted obstacle notice.
  // A dip in start_clear alone cannot arm another clear notice.
  if(obstacle_spoken) clear_armed<=1;
  else if(clear_spoken) clear_armed<=0;
 end
end
wire [5:0] conditions={
 running && !traffic_active && line_fault && gray==5'b00000,
 green_now && light_ready,
 running && traffic_active && !finished && light_ready && camera_live && color==2'd1,
 running && traffic_active && !finished && !zebra_announced,
 running && clear_armed && !obstacle_stop && start_clear && !sensor_fault,
 running && obstacle_stop && !sensor_fault};
localparam integer ZEBRA_GAP=(ZEBRA_WAIT_CYCLES>PULSE_CYCLES) ? ZEBRA_WAIT_CYCLES-PULSE_CYCLES : 1;
asrpro_events #(.CLK_HZ(CLK_HZ),.PULSE_CYCLES(PULSE_CYCLES),.GAP_CYCLES(GAP_CYCLES),
 .ZEBRA_GAP_CYCLES(ZEBRA_GAP)) events(
 .clk(clk),.rst_n(rst_n && running),.conditions(conditions),.gpio(voice_gpio));
endmodule
