`timescale 1ns/1ps
// ��ȷ��MG310P20_7.4V/G01052599��LF=Moto_A��LR=Moto_B��RF=Motor_D��RR=Motor_C��
// ���߱���Ӧ�������������㣻����8��Raspberry Pi GPIO����·AB��������
// BTN0=��λ��BTN1=����/ȷ�ϣ�LED0=״̬�ƣ�����ܽŰ��û����߽��߱���
module line_ultrasonic_stop_top #(
 parameter integer ENABLE_MOTORS=1,
 parameter integer MOTOR_B_ONLY=0,
 parameter integer SWAP_STEERING_OUTPUTS=1,
 parameter integer MUTE_BUZZER=0,
 parameter [15:0] BUZZER_DISTANCE_MM=400,
 parameter integer CLK_HZ=125000000,
 parameter integer TRAFFIC_STRAIGHT_CYCLES=3*CLK_HZ,
 parameter integer ZEBRA_WAIT_CYCLES=CLK_HZ*3/2,
 parameter integer VOICE_PULSE_CYCLES=CLK_HZ/10,VOICE_GAP_CYCLES=CLK_HZ*4,
 parameter integer GAP_MS=25, LOSS_TIMEOUT_MS=250, REACQUIRE_MS=8, HISTORY_MS=200, LOSS_BUDGET_MS=300,
 parameter [63:0] MAX_RUN_CYCLES=64'd20*CLK_HZ,
 parameter [7:0] RUN_DUTY=60,TURN_DUTY=0,SLOW_DUTY=40,SLOW_TURN_DUTY=25,
 parameter [7:0] TURN_OUTER_DUTY=190,
 // Ѳ�����ֵ�ƽ/����˳�����ú��߰׵�ʵ�⣬Ĭ������ԭ����ЧԼ����
 parameter integer LINE_ACTIVE_LOW=0,parameter integer LINE_REVERSE_ORDER=1,
 parameter integer LEFT_REVERSE=0,parameter integer RIGHT_REVERSE=0,
 parameter integer LEFT_REAR_REVERSE=0,parameter integer RIGHT_REAR_REVERSE=0,
 parameter integer LEFT_ENCODER_REVERSE=0,parameter integer RIGHT_ENCODER_REVERSE=0,
 parameter integer LEFT_REAR_ENCODER_REVERSE=0,parameter integer RIGHT_REAR_ENCODER_REVERSE=0,
 parameter integer REAR_ENCODERS_CONNECTED=1,
 parameter integer ODOMETRY_CALIBRATED=0, // ������ܳ�/����ʵ�����1��ң��bit7�ű�Ϊ��У׼
 
 // ���ܳ�mm��x4�����/ת��δ�궨ǰ��������׼ȷ�ٶ���̡�
 parameter integer LEFT_MM_PER_REV=210,parameter integer RIGHT_MM_PER_REV=210,
 parameter integer LEFT_COUNTS_PER_REV=80,parameter integer RIGHT_COUNTS_PER_REV=80,
 parameter integer LEFT_REAR_MM_PER_REV=LEFT_MM_PER_REV,parameter integer RIGHT_REAR_MM_PER_REV=RIGHT_MM_PER_REV,
 parameter integer LEFT_REAR_COUNTS_PER_REV=LEFT_COUNTS_PER_REV,parameter integer RIGHT_REAR_COUNTS_PER_REV=RIGHT_COUNTS_PER_REV,
 parameter integer SPEED_SAMPLE_HZ=10,
 // �Ѱ��û�ͼƬȷ�ϣ���Դ���ߵ�ƽ������Ĭ��PASSIVE=0��ACTIVE_LOW=0��
 parameter integer BUZZER_PASSIVE=0,parameter integer BUZZER_ACTIVE_LOW=0,
 parameter integer BUZZER_TONE_HZ=2000,
 parameter integer PWM_HZ=20000,parameter integer UART_BAUD=115200,
 parameter integer TELEMETRY_HZ=10,
 parameter [15:0] STOP_DISTANCE_MM=300,parameter [15:0] RECOVER_DISTANCE_MM=400,
 parameter [15:0] WARN_DISTANCE_MM=600,
 parameter integer BUTTON_CYCLES=CLK_HZ/100,
 parameter integer LINE_FILTER_CYCLES=CLK_HZ/10000,parameter integer LINE_LOST_CYCLES=CLK_HZ/50,
 parameter integer US_PERIOD_US=65000,parameter integer US_MAX_ECHO_US=30000,
 parameter integer US_NEAR_CONFIRM_COUNT=3, US_RECOVER_CONFIRM_COUNT=3, US_ERROR_CONFIRM_COUNT=4,
 parameter integer US_ECHO_FILTER_CYCLES=(CLK_HZ/1000000<2 ? 2 : CLK_HZ/1000000),
 parameter integer US_MIN_ECHO_US=20,
 parameter integer STALE_CYCLES=CLK_HZ/5,parameter integer RECOVER_CYCLES=CLK_HZ/10
)(input wire clk,input wire reset_button,input wire start_button,input wire stop_button,
 input wire [4:0] gray,input wire us_echo,input wire estop_n,input wire help_btn_n,
 input wire enc_lf_a,input wire enc_lf_b,input wire enc_lr_a,input wire enc_lr_b,
 input wire enc_rf_a,input wire enc_rf_b,input wire enc_rr_a,input wire enc_rr_b,
 input wire esp_rx,output wire esp_tx,
 output wire us_trig,output wire motor_left_pwm,output wire motor_left_in1,output wire motor_left_in2,
 output wire motor_right_pwm,output wire motor_right_in1,output wire motor_right_in2,
 output wire motor_stby,output wire buzzer_drv,output wire status_led,
 output wire motor_left_rear_pwm,output wire motor_left_rear_in1,output wire motor_left_rear_in2,
 output wire motor_right_rear_pwm,output wire motor_right_rear_in1,output wire motor_right_rear_in2,
 output wire [2:0] line_led,
 input wire cam_pclk,input wire [7:0] cam_data,input wire cam_href,cam_vsync,
 inout wire cam_scl,cam_sda,output wire cam_reset_n,
 output wire hdmi_out_clk_p,hdmi_out_clk_n,
 output wire [2:0] hdmi_out_data_p,hdmi_out_data_n,
 output wire [5:0] voice_gpio);
wire lp,rp,li1,li2,ri1,ri2,stby,core_buzzer;
wire stop_request,reset_n,core_us_trig;
wire core_lp,core_rp,core_li1,core_li2,core_ri1,core_ri2,core_stby;
wire traffic_lp,traffic_rp,traffic_li1,traffic_li2,traffic_ri1,traffic_ri2,traffic_stby;
localparam [1:0] LINE=0,GO_STRAIGHT=2,FINISHED=3;
localparam [31:0] STRAIGHT_CYCLES=TRAFFIC_STRAIGHT_CYCLES;
(* MARK_DEBUG="TRUE" *) wire camera_green,camera_live;
wire [1:0] telemetry_color;
traffic_camera #(.CLK_HZ(CLK_HZ)) vision(
 .clk(clk),.reset_n(reset_n),.cam_pclk(cam_pclk),.cam_data(cam_data),
 .cam_href(cam_href),.cam_vsync(cam_vsync),.cam_scl(cam_scl),.cam_sda(cam_sda),
 .hdmi_out_clk_p(hdmi_out_clk_p),.hdmi_out_clk_n(hdmi_out_clk_n),
 .hdmi_out_data_p(hdmi_out_data_p),.hdmi_out_data_n(hdmi_out_data_n),
 .observed_color(telemetry_color),.cam_reset_n(cam_reset_n),.green_permitted(camera_green),.camera_live(camera_live));
reg [1:0] traffic_phase;
reg [31:0] straight_timer;
// Field calibration: all five sensor LEDs off means all five detect the black line.
// Any filtered 11111 during an enabled run starts the straight sequence,
// including when the line controller has already classified it as a fault.
wire all_black_trigger=(traffic_phase==LINE && core.enabled && core.gray==5'b11111);
wire traffic_active=(traffic_phase!=LINE || all_black_trigger);
wire traffic_go=(traffic_phase==GO_STRAIGHT);
wire voice_go_authorized;
// After the original zebra trigger, color permits straight motion; ultrasound still overrides it.
wire traffic_drive=traffic_go && camera_green && voice_go_authorized && core.enabled && !stop_request &&
                   !core.estop_latched && !core.us_pause && !core.us_resume_pending;
assign us_trig=core_us_trig;
assign lp=traffic_active ? traffic_lp : (SWAP_STEERING_OUTPUTS ? core_rp : core_lp);
assign rp=traffic_active ? traffic_rp : (SWAP_STEERING_OUTPUTS ? core_lp : core_rp);
assign li1=traffic_active ? traffic_li1 : core_li1;
assign li2=traffic_active ? traffic_li2 : core_li2;
assign ri1=traffic_active ? traffic_ri1 : core_ri1;
assign ri2=traffic_active ? traffic_ri2 : core_ri2;
assign stby=traffic_active ? traffic_stby : core_stby;
motor_driver #(.CLK_HZ(CLK_HZ),.PWM_HZ(PWM_HZ),.LEFT_REVERSE(LEFT_REVERSE),
 .RIGHT_REVERSE(RIGHT_REVERSE)) traffic_motors(
 .clk(clk),.rst_n(core.rst_n),.allow(traffic_drive),.emergency(stop_request),
 .left_duty(RUN_DUTY),.right_duty(RUN_DUTY),
 .left_pwm(traffic_lp),.right_pwm(traffic_rp),
 .left_in1(traffic_li1),.left_in2(traffic_li2),
 .right_in1(traffic_ri1),.right_in2(traffic_ri2),.driver_enable(traffic_stby));
// Keep the original line controller out of its loss/fault path during the one-shot sequence.
wire [4:0] line_for_core=traffic_active ? (LINE_ACTIVE_LOW ? 5'b11011 : 5'b00100) : gray;
always @(posedge clk) begin
 if(!reset_n) begin traffic_phase<=LINE;straight_timer<=0;end
 else case(traffic_phase)
   LINE: if(all_black_trigger) traffic_phase<=GO_STRAIGHT;
  GO_STRAIGHT: if(traffic_drive) begin
   if(straight_timer>=STRAIGHT_CYCLES-1) traffic_phase<=FINISHED;
   else straight_timer<=straight_timer+1'b1;
  end
  default: traffic_phase<=FINISHED;
 endcase
end
// One clock after DONE: ILA samples the committed guard counters/decision.
(* KEEP="TRUE", MARK_DEBUG="TRUE" *) reg debug_range_event;
always @(posedge clk) begin
 if(!core.rst_n) debug_range_event<=0;
 else debug_range_event<=core.us_done || core.us_stale_event;
end
// Independent Echo observation, identical synchronization to standalone diagnostics.
(* ASYNC_REG="TRUE" *) reg echo_meta_dbg;
(* ASYNC_REG="TRUE", MARK_DEBUG="TRUE" *) reg echo_sync_dbg;
reg echo_prev_dbg,trig_prev_dbg;
(* MARK_DEBUG="TRUE" *) reg [31:0] echo_rises_dbg,trig_rises_dbg;
always @(posedge clk) begin
 if(!core.rst_n) begin
  echo_meta_dbg<=0;echo_sync_dbg<=0;echo_prev_dbg<=0;trig_prev_dbg<=0;
  echo_rises_dbg<=0;trig_rises_dbg<=0;
 end else begin
  echo_meta_dbg<=us_echo;echo_sync_dbg<=echo_meta_dbg;
  echo_prev_dbg<=echo_sync_dbg;trig_prev_dbg<=us_trig;
  if(echo_sync_dbg && !echo_prev_dbg) echo_rises_dbg<=echo_rises_dbg+1'b1;
  if(us_trig && !trig_prev_dbg) trig_rises_dbg<=trig_rises_dbg+1'b1;
 end
end
(* KEEP="TRUE", MARK_DEBUG="TRUE" *) wire [31:0] debug_status;
assign debug_status={core.blocked_reason,core.flags,core.gray,gray,core.state,stop_request,core.line_fault,core.line_ready};
// Audible range test works while stationary; motor/steering policy is unchanged.
(* KEEP="TRUE", MARK_DEBUG="TRUE" *) wire distance_beep=core.distance_valid && core.distance<=BUZZER_DISTANCE_MM;
(* KEEP="TRUE", MARK_DEBUG="TRUE" *) wire distance_buzzer;
buzzer_driver #(.CLK_HZ(CLK_HZ),.PASSIVE(BUZZER_PASSIVE),
 .ACTIVE_LOW(BUZZER_ACTIVE_LOW),.TONE_HZ(BUZZER_TONE_HZ)) distance_sound(
 .clk(clk),.rst_n(core.rst_n),.beep_enable(distance_beep),.buzzer(distance_buzzer));
assign buzzer_drv=MUTE_BUZZER ? (BUZZER_ACTIVE_LOW!=0) : distance_buzzer;
assign motor_left_pwm=ENABLE_MOTORS && !MOTOR_B_ONLY && lp;
assign motor_right_pwm=ENABLE_MOTORS && !MOTOR_B_ONLY && rp;
assign motor_left_in1=ENABLE_MOTORS && !MOTOR_B_ONLY && li1;
assign motor_left_in2=ENABLE_MOTORS && !MOTOR_B_ONLY && li2;
assign motor_right_in1=ENABLE_MOTORS && !MOTOR_B_ONLY && ri1;
assign motor_right_in2=ENABLE_MOTORS && !MOTOR_B_ONLY && ri2;
assign motor_stby=ENABLE_MOTORS && stby;
assign motor_left_rear_pwm=ENABLE_MOTORS && lp;
assign motor_left_rear_in1=ENABLE_MOTORS && (LEFT_REAR_REVERSE ? li2 : li1);
assign motor_left_rear_in2=ENABLE_MOTORS && (LEFT_REAR_REVERSE ? li1 : li2);
assign motor_right_rear_pwm=motor_right_pwm;
assign motor_right_rear_in1=RIGHT_REAR_REVERSE ? motor_right_in2 : motor_right_in1;
assign motor_right_rear_in2=RIGHT_REAR_REVERSE ? motor_right_in1 : motor_right_in2;
assign line_led={core.line_fault,core.line_ready,stby};
// 7ϵ��֧�ּĴ����ϵ�INITֵ��16���ϵ縴λ�����ͷ��ڲ�����ͬ����λ��
reg [15:0] power_on=0;
always @(posedge clk) power_on<={power_on[14:0],1'b1};
wire raw_reset_n=(&power_on) && !reset_button;
reset_sync main_reset_release(clk,raw_reset_n,reset_n);
// Dedicated bench profile: BTN2 replaces the unconnected external A1 switch.
// No auto-start; all motor starts still require the conditioned BTN1 event.
reg [31:0] run_timer=0;
reg run_timeout=0;
(* KEEP="TRUE", MARK_DEBUG="TRUE" *) wire [31:0] debug_trial={run_timeout,stop_button,run_timer[31:2]};
assign stop_request=stop_button || run_timeout;
always @(posedge clk) begin
 if(!reset_n) begin run_timer<=0;run_timeout<=0;end
 else if(traffic_active) run_timer<=0;
 else if(!run_timeout && MAX_RUN_CYCLES>0) begin
  if(core.motor_allow) begin
   if(run_timer>=MAX_RUN_CYCLES-1) run_timeout<=1;
   else run_timer<=run_timer+1'b1;
  end else run_timer<=0;
 end
end
// synthesis translate_off
initial if(MAX_RUN_CYCLES>64'hffffffff) $fatal(1,"Invalid motion timer limit");
// synthesis translate_on

car_curve_top #(
 .GAP_MS(GAP_MS),.LOSS_TIMEOUT_MS(LOSS_TIMEOUT_MS),.REACQUIRE_MS(REACQUIRE_MS),.HISTORY_MS(HISTORY_MS),.LOSS_BUDGET_MS(LOSS_BUDGET_MS),
 .RUN_DUTY(RUN_DUTY),.TURN_OUTER_DUTY(TURN_OUTER_DUTY),.TURN_DUTY(TURN_DUTY),.SLOW_DUTY(SLOW_DUTY),.SLOW_TURN_DUTY(SLOW_TURN_DUTY),
 .CLK_HZ(CLK_HZ),.VISUAL_MODE(0),.ENABLE_ULTRASONIC(1),
 .LINE_ACTIVE_LOW(LINE_ACTIVE_LOW),
 .LINE_REVERSE_ORDER(LINE_REVERSE_ORDER),
 .LEFT_REVERSE(LEFT_REVERSE),
 .RIGHT_REVERSE(RIGHT_REVERSE),
 .LEFT_ENCODER_REVERSE(LEFT_ENCODER_REVERSE),
 .RIGHT_ENCODER_REVERSE(RIGHT_ENCODER_REVERSE),
 .LEFT_MM_PER_REV(LEFT_MM_PER_REV),
 .RIGHT_MM_PER_REV(RIGHT_MM_PER_REV),
 .LEFT_COUNTS_PER_REV(LEFT_COUNTS_PER_REV),
 .RIGHT_COUNTS_PER_REV(RIGHT_COUNTS_PER_REV),
 .SPEED_SAMPLE_HZ(SPEED_SAMPLE_HZ),
 .BUZZER_PASSIVE(BUZZER_PASSIVE),
 .BUZZER_ACTIVE_LOW(BUZZER_ACTIVE_LOW),
 .BUZZER_TONE_HZ(BUZZER_TONE_HZ),
 .PWM_HZ(PWM_HZ),
 .UART_BAUD(UART_BAUD),
 .TELEMETRY_HZ(TELEMETRY_HZ),
 .STOP_DISTANCE_MM(STOP_DISTANCE_MM),
 .RECOVER_DISTANCE_MM(RECOVER_DISTANCE_MM),
 .WARN_DISTANCE_MM(WARN_DISTANCE_MM),
 .BUTTON_CYCLES(BUTTON_CYCLES),
 .LINE_FILTER_CYCLES(LINE_FILTER_CYCLES),
 .LINE_LOST_CYCLES(LINE_LOST_CYCLES),
 .US_PERIOD_US(US_PERIOD_US),
 .US_MAX_ECHO_US(US_MAX_ECHO_US),
 .US_NEAR_CONFIRM_COUNT(US_NEAR_CONFIRM_COUNT),.US_RECOVER_CONFIRM_COUNT(US_RECOVER_CONFIRM_COUNT),
 .US_ERROR_CONFIRM_COUNT(US_ERROR_CONFIRM_COUNT),.US_ECHO_FILTER_CYCLES(US_ECHO_FILTER_CYCLES),
 .US_MIN_ECHO_US(US_MIN_ECHO_US),
 .STALE_CYCLES(STALE_CYCLES),
 .RECOVER_CYCLES(RECOVER_CYCLES),
 .LEFT_REAR_ENCODER_REVERSE(LEFT_REAR_ENCODER_REVERSE),.RIGHT_REAR_ENCODER_REVERSE(RIGHT_REAR_ENCODER_REVERSE),
 .REAR_ENCODERS_CONNECTED(REAR_ENCODERS_CONNECTED),.ODOMETRY_CALIBRATED(ODOMETRY_CALIBRATED),
 .LEFT_REAR_MM_PER_REV(LEFT_REAR_MM_PER_REV),.RIGHT_REAR_MM_PER_REV(RIGHT_REAR_MM_PER_REV),
 .LEFT_REAR_COUNTS_PER_REV(LEFT_REAR_COUNTS_PER_REV),.RIGHT_REAR_COUNTS_PER_REV(RIGHT_REAR_COUNTS_PER_REV),
 .ENCODERS_CONNECTED(1)
) core(
 .vision_frame_valid(1'b0),.vision_frame_data(4'b0),.vision_link_ready(1'b1),.vision_status(8'd0),
 .clk(clk),.reset_n(reset_n),.start_button(start_button),.emergency_stop(stop_request),
 .line_raw(line_for_core),.ultrasonic_echo(us_echo),.left_encoder_a(enc_lf_a),.left_encoder_b(enc_lf_b),
 .right_encoder_a(enc_rf_a),.right_encoder_b(enc_rf_b),
 .left_rear_encoder_a(enc_lr_a),.left_rear_encoder_b(enc_lr_b),
 .right_rear_encoder_a(enc_rr_a),.right_rear_encoder_b(enc_rr_b),
 .ultrasonic_trig(core_us_trig),.left_pwm(core_lp),.right_pwm(core_rp),
 .left_in1(core_li1),.left_in2(core_li2),.right_in1(core_ri1),.right_in2(core_ri2),
 .driver_enable(core_stby),.status_led(status_led),.buzzer(core_buzzer),
 .help_button(!help_btn_n),.telemetry_tx_pin());
// esp_rxֻ�������ߣ�������Զ�̵�����ƣ�����Э��������ʵ�ֽ�������Ȩ��

// Read-only top-level telemetry: reports actual traffic override, never drives motors.
// state: 0 idle,1 line,2 wait light,3 straight,4 finished,5 estop,6 ultrasound pause,7 fault.
wire [2:0] report_state=(stop_request || core.estop_latched) ? 3'd5 :
 core.system_fault ? 3'd7 : (core.us_pause || core.us_resume_pending) ? 3'd6 :
 traffic_phase==FINISHED ? 3'd4 : !core.enabled ? 3'd0 :
 traffic_active ? (traffic_drive ? 3'd3 : 3'd2) : 3'd1;
wire [7:0] report_left= !ENABLE_MOTORS ? 8'd0 : traffic_active ?
 (traffic_drive ? RUN_DUTY : 8'd0) : (!core.motor_allow ? 8'd0 :
 (SWAP_STEERING_OUTPUTS ? core.right_duty : core.left_duty));
wire [7:0] report_right= !ENABLE_MOTORS ? 8'd0 : traffic_active ?
 (traffic_drive ? RUN_DUTY : 8'd0) : (!core.motor_allow ? 8'd0 :
 (SWAP_STEERING_OUTPUTS ? core.left_duty : core.right_duty));
wire [7:0] report_visual={1'b0,1'b1,telemetry_color,(traffic_phase!=LINE),{3{camera_live}}};
telemetry_tx #(.CLK_HZ(CLK_HZ),.BAUD(UART_BAUD),.RATE_HZ(TELEMETRY_HZ)) web_telemetry(
 .clk(clk),.rst_n(core.rst_n),.flags(core.flags),.state(report_state),.gray(core.gray),
 .risk(core.risk),.blocked_reason(core.blocked_reason),.distance_mm(core.distance),
 .left_duty(report_left),.right_duty(report_right),.left_speed(core.left_speed),.right_speed(core.right_speed),
 .left_distance(core.left_distance),.right_distance(core.right_distance),
 .left_errors(core.left_error_count),.right_errors(core.right_error_count),.tx(esp_tx),.visual_status(report_visual));

// Speech observes existing state; it does not authorize motor motion.
car_voice_controller #(.CLK_HZ(CLK_HZ),.PULSE_CYCLES(VOICE_PULSE_CYCLES),
 .GAP_CYCLES(VOICE_GAP_CYCLES),.ZEBRA_WAIT_CYCLES(ZEBRA_WAIT_CYCLES)) speech(
 .clk(clk),.rst_n(core.rst_n),.enabled(core.enabled),
 .stop_request(stop_request),.estop(core.estop_latched),
 .obstacle_stop(core.obstacle_stop),.start_clear(core.us_start_clear),.sensor_fault(core.us_sensor_fault),
 .traffic_active(traffic_active),.finished(traffic_phase==FINISHED),
 .camera_live(camera_live),.color(telemetry_color),.green_permitted(camera_green),
 .us_pause(core.us_pause || core.us_resume_pending),.line_fault(core.line_fault),.gray(core.gray),
 .voice_gpio(voice_gpio),.traffic_go_authorized(voice_go_authorized));

endmodule


