`timescale 1ns/1ps
module tb_web_telemetry;
reg clk=0;
always #4 clk=~clk;
line_ultrasonic_stop_top #(.TELEMETRY_HZ(1000000)) dut(.clk(clk),.reset_button(1'b0),.start_button(1'b0),.stop_button(1'b0),.gray(5'b00100),.us_echo(1'b0),.help_btn_n(1'b1));
task sample;
begin
 force dut.web_telemetry.active=0;
 force dut.web_telemetry.timer=124;
 @(posedge clk);#1;
 release dut.web_telemetry.active;
 release dut.web_telemetry.timer;
end
endtask
initial begin
 force dut.core.rst_n=1;
 force dut.core.enabled=1;
 force dut.core.system_fault=0;
 force dut.core.estop_latched=0;
 force dut.core.us_pause=0;
 force dut.core.us_resume_pending=0;
 force dut.stop_request=0;
 force dut.camera_live=1;
 force dut.camera_green=0;
 force dut.voice_go_authorized=1;
 force dut.telemetry_color=1;
 force dut.traffic_phase=2;
 repeat(30) @(negedge clk);
 sample();
 if(dut.web_telemetry.snapshot[48+:8]!==2 || dut.web_telemetry.snapshot[96+:8]!==0 || dut.web_telemetry.snapshot[304+:8]!==8'h5f) $fatal(1,"red wait packet incorrect");
 @(negedge clk);force dut.camera_green=1;force dut.telemetry_color=2;
 sample();
 if(dut.web_telemetry.snapshot[48+:8]!==3 || dut.web_telemetry.snapshot[96+:8]!==60 || dut.web_telemetry.snapshot[304+:8]!==8'h6f) $fatal(1,"green drive packet incorrect");
 @(negedge clk);force dut.traffic_phase=3;
 sample();
 if(dut.web_telemetry.snapshot[48+:8]!==4 || dut.web_telemetry.snapshot[96+:8]!==0) $fatal(1,"finish packet incorrect");
 @(negedge clk);force dut.stop_request=1;
 sample();
 if(dut.web_telemetry.snapshot[48+:8]!==5) $fatal(1,"estop packet incorrect");
 $display("PASS tb_web_telemetry: red wait, green drive, PWM, visual byte, finish, estop snapshot");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
