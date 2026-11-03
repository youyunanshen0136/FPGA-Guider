`timescale 1ns/1ps
// ��ȷ��MG310P20_7.4V/G01052599��LF=Moto_A��LR=Moto_B��RF=Motor_D��RR=Motor_C��
// �ڲ��������ɣ�����Ӳ��������������ڴˣ������ܽŶ���Ϊcar_board_top��
// �Ӿ��ݲ����룬��ʵ�����������͵��PWM��ȫ��·���ֹ�����
module car_curve_top #(
 parameter integer CLK_HZ=125000000,
 parameter integer GAP_MS=25, LOSS_TIMEOUT_MS=250, REACQUIRE_MS=8, HISTORY_MS=200, LOSS_BUDGET_MS=300,
 parameter integer VISUAL_MODE=0,
 parameter integer ENABLE_ULTRASONIC=1,
 parameter [7:0] RUN_DUTY=100,TURN_DUTY=60,SLOW_DUTY=50,SLOW_TURN_DUTY=30,
 parameter [7:0] TURN_OUTER_DUTY=RUN_DUTY,
 parameter integer LIGHT_ONLY_DEMO=0,
 parameter integer VISION_TIMEOUT_CYCLES=CLK_HZ,
 parameter integer GREEN_FRAMES=3,
 // Ѳ�����ֵ�ƽ/����˳�����ú��߰׵�ʵ�⣬Ĭ������ԭ����ЧԼ����
 parameter integer LINE_ACTIVE_LOW=1,parameter integer LINE_REVERSE_ORDER=0,
 parameter integer LEFT_REVERSE=0,parameter integer RIGHT_REVERSE=0,
 parameter integer LEFT_ENCODER_REVERSE=0,parameter integer RIGHT_ENCODER_REVERSE=0,
 parameter integer LEFT_REAR_ENCODER_REVERSE=0,parameter integer RIGHT_REAR_ENCODER_REVERSE=0,
 parameter integer REAR_ENCODERS_CONNECTED=1,
 parameter integer ODOMETRY_CALIBRATED=0, // ������ܳ�/����ʵ�����1��ң��bit7�ű�Ϊ��У׼
 parameter integer ENCODERS_CONNECTED=1,
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
 parameter integer US_PERIOD_US=60000,parameter integer US_MAX_ECHO_US=30000,
 parameter integer US_NEAR_CONFIRM_COUNT=3, US_RECOVER_CONFIRM_COUNT=3, US_ERROR_CONFIRM_COUNT=4,
 parameter integer US_ECHO_FILTER_CYCLES=(CLK_HZ/1000000<2 ? 2 : CLK_HZ/1000000),
 parameter integer US_MIN_ECHO_US=20,
 parameter integer STALE_CYCLES=CLK_HZ/5,parameter integer RECOVER_CYCLES=CLK_HZ/10
)(
 input wire clk,input wire reset_n,input wire start_button,input wire emergency_stop,
 input wire [4:0] line_raw,input wire ultrasonic_echo,
 input wire left_encoder_a,input wire left_encoder_b,input wire right_encoder_a,input wire right_encoder_b,
 output wire ultrasonic_trig,output wire left_pwm,output wire right_pwm,
 output wire left_in1,output wire left_in2,output wire right_in1,output wire right_in2,
 output wire driver_enable,output wire status_led,output wire buzzer,
 input wire help_button,output wire telemetry_tx_pin,
 input wire left_rear_encoder_a,input wire left_rear_encoder_b,
 input wire right_rear_encoder_a,input wire right_rear_encoder_b,
 input wire vision_frame_valid,input wire [3:0] vision_frame_data,input wire vision_link_ready,
 input wire [7:0] vision_status
);
wire rst_n;
reset_sync reset_unit(clk,reset_n,rst_n);
wire start_level,start_event,help_level,help_event;
input_conditioner #(.STABLE_CYCLES(BUTTON_CYCLES)) start_filter(clk,rst_n,start_button,start_level,start_event);
input_conditioner #(.STABLE_CYCLES(BUTTON_CYCLES)) help_filter(clk,rst_n,help_button,help_level,help_event);
reg help_latched;
always @(posedge clk) if(!rst_n) help_latched<=0;else if(help_event) help_latched<=1;
wire [4:0] gray;wire line_fault,line_ready;
(* MARK_DEBUG="TRUE" *) wire [15:0] distance;
(* MARK_DEBUG="TRUE" *) wire distance_valid;
wire distance_success;
(* MARK_DEBUG="TRUE" *) wire [2:0] us_status;
(* MARK_DEBUG="TRUE" *) wire us_done;
(* MARK_DEBUG="TRUE" *) wire [31:0] echo_us;
wire healthy,sensor_fault;
(* KEEP="TRUE", MARK_DEBUG="TRUE" *) wire echo_filtered,echo_synced;
(* KEEP="TRUE", MARK_DEBUG="TRUE" *) wire [7:0] us_near_count,us_error_count,us_recover_count;
(* KEEP="TRUE", MARK_DEBUG="TRUE" *) wire obstacle_stop,us_sensor_fault,us_stale_event;
wire us_start_clear;
generate if (ENABLE_ULTRASONIC != 0) begin : with_ultrasonic
 ultrasonic #(.CLK_HZ(CLK_HZ),.PERIOD_US(US_PERIOD_US),.MAX_ECHO_US(US_MAX_ECHO_US),
 .ECHO_FILTER_CYCLES(US_ECHO_FILTER_CYCLES),.MIN_ECHO_US(US_MIN_ECHO_US)) ranger(
  .clk(clk),.rst_n(rst_n),.echo(ultrasonic_echo),.trig(ultrasonic_trig),
  .distance_mm(distance),.valid(distance_valid),.success(distance_success),
  .done(us_done),.status(us_status),.echo_us(echo_us),.busy(),
  .echo_synced(echo_synced),.echo_filtered(echo_filtered));
 ultrasonic_guard #(.STOP_DISTANCE_MM(STOP_DISTANCE_MM),.RECOVER_DISTANCE_MM(RECOVER_DISTANCE_MM),
  .NEAR_CONFIRM_COUNT(US_NEAR_CONFIRM_COUNT),.RECOVER_CONFIRM_COUNT(US_RECOVER_CONFIRM_COUNT),
  .ERROR_CONFIRM_COUNT(US_ERROR_CONFIRM_COUNT),.STALE_CYCLES(STALE_CYCLES)) guard(
  .clk(clk),.rst_n(rst_n),.done(us_done),.distance_valid(distance_valid),.distance(distance),.status(us_status),
  .obstacle_stop(obstacle_stop),.sensor_fault(us_sensor_fault),
  .near_count(us_near_count),.error_count(us_error_count),.recover_count(us_recover_count),
  .start_clear(us_start_clear),.stale_event(us_stale_event));
end else begin : without_ultrasonic
 assign ultrasonic_trig=1'b0;
 assign distance=16'hffff;
 assign distance_valid=1'b1;
 assign distance_success=1'b0;
 assign us_done=1'b0;
 assign us_status=3'd0;
 assign echo_us=32'd0;
 assign echo_filtered=1'b0;assign echo_synced=1'b0;
 assign obstacle_stop=1'b0;assign us_sensor_fault=1'b0;assign us_stale_event=1'b0;
 assign us_near_count=8'd0;assign us_error_count=8'd0;assign us_recover_count=8'd0;
 assign us_start_clear=1'b1;
end endgenerate
// Recoverable ultrasound decisions are independent of the latched line FAULT.
assign healthy=line_ready && !line_fault;
assign sensor_fault=line_fault || us_sensor_fault;
wire system_fault=sensor_fault || (VISUAL_MODE && !vision_link_ready);
(* MARK_DEBUG="TRUE" *) wire [2:0] state;
wire [15:0] green_count;
(* MARK_DEBUG="TRUE" *) wire [7:0] left_duty,right_duty,risk;
(* MARK_DEBUG="TRUE" *) wire motor_allow,alarm_request,unused_buzzer;
(* KEEP="TRUE", MARK_DEBUG="TRUE" *) reg enabled,estop_latched;
(* KEEP="TRUE", MARK_DEBUG="TRUE" *) wire us_pause=obstacle_stop || us_sensor_fault;
(* KEEP="TRUE", MARK_DEBUG="TRUE" *) reg us_resume_pending;
(* KEEP="TRUE", MARK_DEBUG="TRUE" *) wire curve_motor_allow,curve_enable;
// Use the existing disable/restart interface. Do not let a stationary blank
// line consume GAP/SEARCH deadlines. Existing FAULT and estop override pause:
// ultrasound can never acknowledge or clear a serious fault.
always @(posedge clk) begin
 if(!rst_n || !enabled) us_resume_pending<=0;
 else if(us_pause) us_resume_pending<=1;
 else if(line_ready) us_resume_pending<=0;
end
assign curve_enable=enabled && (line_fault || estop_latched ||
                              (!us_pause && !us_resume_pending));
assign motor_allow=curve_motor_allow && !us_pause && !us_resume_pending;

// �����첽��λ����̼�ͣ��ͬ����λ��������������ϼ�ͣ/��λ�ſء�
always @(posedge clk or posedge emergency_stop)
 if(emergency_stop) estop_latched<=1;
 else if(!rst_n) estop_latched<=0;
 else if(start_event && (state==6 || !enabled)) estop_latched<=0;
always @(posedge clk) begin
 if(!rst_n) enabled<=0;
 else if(start_event) begin
  if(enabled) enabled<=0; // �״ΰ�����ȷ��/���ã�����ͬ�Ļָ��˶�
  else if(healthy && (!VISUAL_MODE || vision_link_ready) &&
          (ENABLE_ULTRASONIC == 0 || us_start_clear) &&
          !emergency_stop && !estop_latched) enabled<=1;
 end
end
(* KEEP="TRUE", MARK_DEBUG="TRUE" *) wire [31:0] curve_debug;
line_curve_controller #(.CLK_HZ(CLK_HZ),.ACTIVE_LOW(LINE_ACTIVE_LOW),.REVERSE_ORDER(LINE_REVERSE_ORDER),
 .GAP_MS(GAP_MS),.LOSS_TIMEOUT_MS(LOSS_TIMEOUT_MS),.REACQUIRE_MS(REACQUIRE_MS),
 .HISTORY_MS(HISTORY_MS),.LOSS_BUDGET_MS(LOSS_BUDGET_MS),
 .CRUISE_DUTY(RUN_DUTY),.HARD_OUTER_DUTY(TURN_OUTER_DUTY),.HARD_INNER_DUTY(TURN_DUTY),.WIDE_DUTY(SLOW_DUTY)) control(
 .clk(clk),.rst_n(rst_n),.enable(curve_enable),.emergency(estop_latched),.raw(line_raw),
 .gray(gray),.ready(line_ready),.fault(line_fault),.state(state),.motor_enable(curve_motor_allow),
 .left_duty(left_duty),.right_duty(right_duty),.alarm_led(alarm_request),.risk_flags(risk),.debug_word(curve_debug));
motor_driver #(.CLK_HZ(CLK_HZ),.PWM_HZ(PWM_HZ),.LEFT_REVERSE(LEFT_REVERSE),.RIGHT_REVERSE(RIGHT_REVERSE)) motors(
 clk,rst_n,motor_allow,emergency_stop|estop_latched|us_pause,left_duty,right_duty,
 left_pwm,right_pwm,left_in1,left_in2,right_in1,right_in2,driver_enable);
(* KEEP="TRUE", MARK_DEBUG="TRUE" *) wire signed [31:0] left_count,right_count,left_speed,right_speed;
(* KEEP="TRUE", MARK_DEBUG="TRUE" *) wire [31:0] left_distance,right_distance;
wire left_invalid,right_invalid,left_sample,right_sample;
wire left_rear_invalid,right_rear_invalid,left_rear_sample,right_rear_sample;
(* MARK_DEBUG="TRUE" *) wire signed [31:0] left_rear_count,right_rear_count;
(* MARK_DEBUG="TRUE" *) wire signed [31:0] left_front_speed,right_front_speed,left_rear_speed,right_rear_speed;
wire [31:0] left_front_distance,right_front_distance,left_rear_distance,right_rear_distance;
// ������δ��ʱ��ȷ������Ч�������Ѻ㶨0�����Ѳ�ó���Ϊ0��
encoder_reader #(.REVERSE(LEFT_ENCODER_REVERSE)) left_encoder(clk,rst_n,
 ENCODERS_CONNECTED ? left_encoder_a : 1'b0,ENCODERS_CONNECTED ? left_encoder_b : 1'b0,left_count,left_invalid);
encoder_reader #(.REVERSE(RIGHT_ENCODER_REVERSE)) right_encoder(clk,rst_n,
 ENCODERS_CONNECTED ? right_encoder_a : 1'b0,ENCODERS_CONNECTED ? right_encoder_b : 1'b0,right_count,right_invalid);
speed_odometry #(.CLK_HZ(CLK_HZ),.SAMPLE_HZ(SPEED_SAMPLE_HZ),
 .MM_PER_REV(LEFT_MM_PER_REV),.COUNTS_PER_REV(LEFT_COUNTS_PER_REV)) left_meter(clk,rst_n,left_count,left_front_speed,left_front_distance,left_sample);
speed_odometry #(.CLK_HZ(CLK_HZ),.SAMPLE_HZ(SPEED_SAMPLE_HZ),
 .MM_PER_REV(RIGHT_MM_PER_REV),.COUNTS_PER_REV(RIGHT_COUNTS_PER_REV)) right_meter(clk,rst_n,right_count,right_front_speed,right_front_distance,right_sample);
// �����������������������ٶ�/���Ϊ����ƽ����Ĭ�ϱ궨ֵ�������ʵ�⡣
encoder_reader #(.REVERSE(LEFT_REAR_ENCODER_REVERSE)) left_rear_encoder(clk,rst_n,
 ENCODERS_CONNECTED && REAR_ENCODERS_CONNECTED ? left_rear_encoder_a : 1'b0,
 ENCODERS_CONNECTED && REAR_ENCODERS_CONNECTED ? left_rear_encoder_b : 1'b0,left_rear_count,left_rear_invalid);
encoder_reader #(.REVERSE(RIGHT_REAR_ENCODER_REVERSE)) right_rear_encoder(clk,rst_n,
 ENCODERS_CONNECTED && REAR_ENCODERS_CONNECTED ? right_rear_encoder_a : 1'b0,
 ENCODERS_CONNECTED && REAR_ENCODERS_CONNECTED ? right_rear_encoder_b : 1'b0,right_rear_count,right_rear_invalid);
speed_odometry #(.CLK_HZ(CLK_HZ),.SAMPLE_HZ(SPEED_SAMPLE_HZ),
 .MM_PER_REV(LEFT_REAR_MM_PER_REV),.COUNTS_PER_REV(LEFT_REAR_COUNTS_PER_REV)) left_rear_meter(
 clk,rst_n,left_rear_count,left_rear_speed,left_rear_distance,left_rear_sample);
speed_odometry #(.CLK_HZ(CLK_HZ),.SAMPLE_HZ(SPEED_SAMPLE_HZ),
 .MM_PER_REV(RIGHT_REAR_MM_PER_REV),.COUNTS_PER_REV(RIGHT_REAR_COUNTS_PER_REV)) right_rear_meter(
 clk,rst_n,right_rear_count,right_rear_speed,right_rear_distance,right_rear_sample);
wire signed [32:0] left_speed_sum=$signed({left_front_speed[31],left_front_speed})+$signed({left_rear_speed[31],left_rear_speed});
wire signed [32:0] right_speed_sum=$signed({right_front_speed[31],right_front_speed})+$signed({right_rear_speed[31],right_rear_speed});
assign left_speed=REAR_ENCODERS_CONNECTED ? left_speed_sum/33'sd2 : left_front_speed;
assign right_speed=REAR_ENCODERS_CONNECTED ? right_speed_sum/33'sd2 : right_front_speed;
assign left_distance=REAR_ENCODERS_CONNECTED ? ({1'b0,left_front_distance}+{1'b0,left_rear_distance})>>1 : left_front_distance;
assign right_distance=REAR_ENCODERS_CONNECTED ? ({1'b0,right_front_distance}+{1'b0,right_rear_distance})>>1 : right_front_distance;
// �Ƿ�AB����ֻ������ϣ����򵥴θ���ǿ��ͣ�����������ͣ���λ�����
(* MARK_DEBUG="TRUE" *) reg [31:0] left_error_count,right_error_count;
wire [32:0] left_error_sum={1'b0,left_error_count}+left_invalid+left_rear_invalid;
wire [32:0] right_error_sum={1'b0,right_error_count}+right_invalid+right_rear_invalid;
always @(posedge clk) begin
 if(!rst_n) begin left_error_count<=0;right_error_count<=0;end
 else begin
  // ͬһ������ͬʱ�쳣Ҳ��Ϊ2�Σ�ʹ��33λ��ͺ󱥺͡�
  if(left_error_sum[32]) left_error_count<=32'hffffffff;else left_error_count<=left_error_sum[31:0];
  if(right_error_sum[32]) right_error_count<=32'hffffffff;else right_error_count<=right_error_sum[31:0];
 end
end
wire wide=(gray[4]&&gray[3]&&gray[2]) || (gray[3]&&gray[2]&&gray[1]) || (gray[2]&&gray[1]&&gray[0]);
wire beep_enable;
alarm_output #(.CLK_HZ(CLK_HZ)) alarm(clk,rst_n,motor_allow,
 enabled && distance_valid && (distance<=WARN_DISTANCE_MM || wide),alarm_request|estop_latched,status_led,beep_enable);
buzzer_driver #(.CLK_HZ(CLK_HZ),.PASSIVE(BUZZER_PASSIVE),.ACTIVE_LOW(BUZZER_ACTIVE_LOW),.TONE_HZ(BUZZER_TONE_HZ)) sound(
 clk,rst_n,beep_enable,buzzer);
// flags��bit0������Ч��1ѭ��������2��ʹ�ܣ�3��ͣ���棬4�����������ã�5������6���������ϣ�7�ѱ궨��
wire [7:0] flags={(ENCODERS_CONNECTED && ODOMETRY_CALIBRATED),system_fault,help_latched,(ENCODERS_CONNECTED!=0),estop_latched,enabled,line_ready,(ENABLE_ULTRASONIC && distance_valid)};
// ԭ����������δ������ϣ�λ0����δ������1Ѳ���쳣��2��ͣ��3���ϡ�4���������ϡ�5���˹�ȷ�ϡ�
wire [7:0] blocked_reason={1'b0,(VISUAL_MODE && !vision_link_ready),(state==6),system_fault,
 (distance_valid && distance<=RECOVER_DISTANCE_MM),(estop_latched||emergency_stop),
 (!line_ready||line_fault),(us_pause||us_resume_pending||!healthy)};
telemetry_tx #(.CLK_HZ(CLK_HZ),.BAUD(UART_BAUD),.RATE_HZ(TELEMETRY_HZ)) telemetry(
 clk,rst_n,flags,state,gray,risk,blocked_reason,distance,left_duty,right_duty,
 left_speed,right_speed,left_distance,right_distance,left_error_count,right_error_count,telemetry_tx_pin, (VISUAL_MODE ? {vision_status[7],1'b1,vision_status[5:0]} : 8'd0));
// synthesis translate_off
initial if(VISUAL_MODE || STOP_DISTANCE_MM>=RECOVER_DISTANCE_MM || CLK_HZ<1000000 || CLK_HZ%1000000!=0 || BUTTON_CYCLES<1 || LINE_FILTER_CYCLES<1 ||
 LINE_LOST_CYCLES<=LINE_FILTER_CYCLES || LEFT_COUNTS_PER_REV<1 || RIGHT_COUNTS_PER_REV<1)
 $fatal(1,"Invalid car_top hardware parameters");
// synthesis translate_on
endmodule


