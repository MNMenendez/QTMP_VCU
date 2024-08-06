-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS141_143_152_197_164
-- Module      : VCU Timing System
-- Revision    : 2.0
-- Date        : 14 Jan 2020
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Check state dependant outputs in all VCU states at OpMode NORMAL
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-141
--    FPGA-REQ-143
--    FPGA-REQ-152
--    FPGA-REQ-197
--    FPGA-REQ-164
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 14 Jan 2020
--    - CABelchior (1.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- Notes:
--
-- sim -tc TC_RS141_143_152_197_164 -numstdoff -nocov
-- log -r /*
--
-- 140   Visible Warning Light Output (110Vdc Digital)
-- 141   This output has two active modes of operation, flashing at a fixed frequency or permanently on. Drawing 4044 3100 r8 defines when each of these states is active.
-- 
-- 142   Buzzer Warning Output (6-38Vdc Digital):
-- 143   This output, when active, is sounding the buzzer with a consistent sound. The volume is factory set.
-- 
-- 151   TMS Penalty Brake Output Status (110Vdc Digital):
-- 152   This output shall be set to logic level ‘1’ when the penalty brake is being asserted, otherwise set to logic level ‘0’.
-- 
-- 196   TMS Warning Light Status 
-- 197   This output is asserted when the VCU warning light output is either flashing OR solid. It is de-asserted otherwise.
-- 
-- 163   Penalty Brake Output 1 and 2 (Dry Contact)
-- 164   These outputs are active low.
--
--
-- NOTE 1: 
-- Explanation about the terms used in this test case:
--
-- - VCUT_IDLE,             -> Idle
-- - VCUT_NO_WARNING,       -> No Warning
-- - VCUT_1ST_WARNING,      -> 1st Stage Warning
-- - VCUT_2ST_WARNING,      -> 2nd Stage Warning
-- - VCUT_BRK_NORST,        -> Brake Application No Reset
-- - VCUT_BRK_NORST_ERR,    -> Brake Application No Reset Error
-- - VCUT_TRN_STOP_NORST,   -> Train Stopped No Reset
-- - VCUT_NORMAL,           -> Normal Permanent Light Reset Allowed
-- - VCUT_DEPRESSED,        -> Depressed Permanent Light Reset Allowed
-- - VCUT_SPD_LIMIT_TEST    -> Speed Limit Test
--
-- NOTE 2: 
-- The steps 8 to 11 exists just to test the flashing mode of Warning Light
-----------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;

ARCHITECTURE TC_RS141_143_152_197_164 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------
   CONSTANT C_TIMER_DEFAULT       : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(89999, 17);   -- 45s timer
   
   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------
   SIGNAL x_vcut_curst_r                          : vcut_st_t;

      -- Top-Level of the VCU Timing System HLB
   --------------------------------------------------------

   --  Timing
   SIGNAL x_pulse500us_i                          : STD_LOGIC;      -- Internal 500us synch pulse

   --  Raw Inputs
   SIGNAL x_vigi_pb_raw_i                         : STD_LOGIC;      -- Vigilance Push

   --  PWM Processed Inputs
   SIGNAL x_mc_no_pwr_i                           : STD_LOGIC;      -- MC = No Power

   -- VCU Timing System FSM
   --------------------------------------------------------
   SIGNAL x_init_tmr_s                            : STD_LOGIC;             -- Initialize Timer (indicates the reset)
   SIGNAL x_timer_ctr_r                           : UNSIGNED(16 DOWNTO 0); -- Centralized VCU Timer » T1 | T2 | T3 | T4

   SIGNAL x_init_ctmr_s                           : STD_LOGIC;             -- Initialize Timer
   SIGNAL x_ctmr_ctr_r                            : UNSIGNED(11 DOWNTO 0); -- Cab Timer

   --------------------------------------------------------
   -- User Signals
   --------------------------------------------------------
   SIGNAL s_usr_sigout_s                          : tfy_user_out;
   SIGNAL s_usr_sigin_s                           : tfy_user_in;
   SIGNAL pwm_func_model_data_s                   : pwm_func_model_inputs := C_PWM_FUNC_MODEL_INPUTS_INIT;   
   SIGNAL st_ch1_in_ctrl_s                        : ST_BEHAVIOR_CH1;
   SIGNAL st_ch2_in_ctrl_s                        : ST_BEHAVIOR_CH2;

   SIGNAL minor_flt_report_s                      : STD_LOGIC := '0';

   SIGNAL penalty_brake_s                         : STD_LOGIC := '0';
   SIGNAL penalty_brake_status_s                  : STD_LOGIC := '0';
   SIGNAL warning_light_s                         : STD_LOGIC := '0';
   SIGNAL warning_light_status_s                  : STD_LOGIC := '0';
   SIGNAL buzzer_s                                : STD_LOGIC := '0';

   SIGNAL prev_output_s                           : STD_LOGIC := '0';

BEGIN

   p_steps: PROCESS

      --------------------------------------------------------
      -- Common Test Case variable declarations
      --------------------------------------------------------
      VARIABLE pass                              : BOOLEAN := true;

      --------------------------------------------------------
      -- Other Testcase Variables
      --------------------------------------------------------
      VARIABLE ta, tb, tc, td, te, tf, tg        : TIME;
      VARIABLE dt                                : TIME;

      --------------------------------------------------------
      -- Procedures & Functions
      --------------------------------------------------------

      PROCEDURE Set_Speed_Cases(spd_cases : NATURAL) IS
      BEGIN
         uut_in.spd_over_spd_s     <= C_SPEED_VALUES(spd_cases)(7);
         uut_in.spd_h110kmh_s      <= C_SPEED_VALUES(spd_cases)(6);
         uut_in.spd_h90kmh_s       <= C_SPEED_VALUES(spd_cases)(5);
         uut_in.spd_h75kmh_s       <= C_SPEED_VALUES(spd_cases)(4);
         uut_in.spd_h25kmh_a_s     <= C_SPEED_VALUES(spd_cases)(3);
         uut_in.spd_h25kmh_b_s     <= C_SPEED_VALUES(spd_cases)(3);
         uut_in.spd_h23kmh_a_s     <= C_SPEED_VALUES(spd_cases)(2);
         uut_in.spd_h23kmh_b_s     <= C_SPEED_VALUES(spd_cases)(2);
         uut_in.spd_h3kmh_s        <= C_SPEED_VALUES(spd_cases)(1);
         uut_in.spd_l3kmh_s        <= C_SPEED_VALUES(spd_cases)(0);
      END PROCEDURE Set_Speed_Cases;

      PROCEDURE Reset_UUT (Step : STRING) IS 
      BEGIN
         -------------------------------------------------
         tfy_wr_step( report_file, now, Step, 
            "Configure and reset UUT to clear all persistent errors");

         -------------------------------------------------
         tfy_wr_step( report_file, now, Step & ".1", 
            "Configure all functional models to normal behavior");
         st_ch1_in_ctrl_s        <= (OTHERS => C_ST_FUNC_MODEL_ARRAY_INIT);
         st_ch2_in_ctrl_s        <= (OTHERS => C_ST_FUNC_MODEL_ARRAY_INIT);
         fb_func_model_behaviour <= C_OUT_FB_FUNC_MODEL_BEHAVIOUR_INIT;
         pwm_func_model_data_s   <= C_PWM_FUNC_MODEL_INPUTS_INIT;

         -------------------------------------------------
         tfy_wr_step( report_file, now, Step & ".2", 
            "Set all dual channel inputs to '0'");
         uut_in.vigi_pb_ch1_s          <= '0';
         uut_in.vigi_pb_ch2_s          <= '0';
   
         uut_in.zero_spd_ch1_s         <= '0';
         uut_in.zero_spd_ch2_s         <= '0';
         
         uut_in.hcs_mode_ch1_s         <= '0';
         uut_in.hcs_mode_ch2_s         <= '0';
         
         uut_in.bcp_75_ch1_s           <= '0';
         uut_in.bcp_75_ch2_s           <= '0';
         
         uut_in.not_isol_ch1_s         <= '0';
         uut_in.not_isol_ch2_s         <= '0';
         
         uut_in.cab_act_ch1_s          <= '0';
         uut_in.cab_act_ch2_s          <= '0';
         
         uut_in.spd_lim_override_ch1_s <= '0';
         uut_in.spd_lim_override_ch2_s <= '0';
         
         uut_in.driverless_ch1_s       <= '0';
         uut_in.driverless_ch2_s       <= '0';
         
         uut_in.spd_lim_ch1_s          <= '0';
         uut_in.spd_lim_ch2_s          <= '0';

         -------------------------------------------------
         tfy_wr_step( report_file, now, Step & ".3", 
            "Set all single channel inputs to '0'");
         uut_in.horn_low_s             <= '0';
         uut_in.horn_high_s            <= '0';
         uut_in.hl_low_s               <= '0';
         uut_in.w_wiper_pb_s           <= '0';
         uut_in.ss_bypass_pb_s         <= '0';

         -------------------------------------------------
         tfy_wr_step( report_file, now, Step & ".4", 
            "Set all feedback inputs for digital outputs to 'Z'");
         uut_in.light_out_fb_s               <= 'Z';

         uut_in.tms_pb_fb_s                  <= 'Z';
         uut_in.tms_spd_lim_overridden_fb_s  <= 'Z';
         uut_in.tms_rst_fb_s                 <= 'Z';
         uut_in.tms_penalty_stat_fb_s        <= 'Z';
         uut_in.tms_major_fault_fb_s         <= 'Z';
         uut_in.tms_minor_fault_fb_s         <= 'Z';
         uut_in.tms_depressed_fb_s           <= 'Z';
         uut_in.tms_suppressed_fb_s          <= 'Z';
         uut_in.tms_vis_warn_stat_fb_s       <= 'Z';
         uut_in.tms_spd_lim_stat_fb_s        <= 'Z';
      
         uut_in.buzzer_out_fb_s              <= 'Z';
      
         uut_in.penalty2_fb_s                <= 'Z';
         uut_in.penalty1_fb_s                <= 'Z';
         uut_in.rly_fb3_3V_s                 <= 'Z';
         uut_in.rly_fb2_3V_s                 <= 'Z';
         uut_in.rly_fb1_3V_s                 <= 'Z';

         -------------------------------------------------
         tfy_wr_step( report_file, now, Step & ".5", 
            "Set analog speed to [0 - 3 km/h]");
         Set_Speed_Cases(1);               -- Analog Speed -> 0 – 3 km/h

         -------------------------------------------------
         tfy_wr_step( report_file, now, Step & ".6", 
            "Set power supply 1&2 failure status to '1', i.e. OK");
         uut_in.ps1_stat_s        <= '1';  -- Power supply 1 Status OK
         uut_in.ps2_stat_s        <= '1';  -- Power supply 1 Status OK

         -------------------------------------------------
         tfy_wr_step( report_file, now, Step & ".7", 
            "Set CH1 and CH2 external self-test circuitry signal to '0'");
         uut_in.force_fault_ch1_s <= '0';  -- External CH1 self-test circuitry OK
         uut_in.force_fault_ch2_s <= '0';  -- External CH2 self-test circuitry OK

         -------------------------------------------------
         tfy_wr_step( report_file, now, Step & ".8", 
            "Reset UUT and wait for 10ms for system power-up");
         uut_in.arst_n_s     <= '0';       -- Reset UUT
         wait_for_clk_cycles(30, Clk);
         uut_in.arst_n_s     <= '1';
         WAIT FOR 10 ms;                   -- System Power Up

      END PROCEDURE Reset_UUT;

   BEGIN

      --------------------------------------------------------
      -- Testcase Start Sequence
      --------------------------------------------------------
      tfy_tc_start(
         report_fname   => "TC_RS141_143_152_197_164.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS141_143_152_197_164",
         test_module    => "VCU Timing System",
         tc_revision    => "2.0",
         tc_date        => "14 Jan 2020",
         tester_name    => "CABelchior",
         tc_description => "Check VCU FSM transitions at OpMode NORMAL",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_top_tb",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s
      );   

      --------------------------------------------------------
      -- Link Spy Probes
      --------------------------------------------------------

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/vcut_curst_r", "x_vcut_curst_r", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/pulse500us_i",       "x_pulse500us_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vigi_pb_raw_i",      "x_vigi_pb_raw_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/mc_no_pwr_i",        "x_mc_no_pwr_i", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/init_tmr_s",   "x_init_tmr_s", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/timer_ctr_r",  "x_timer_ctr_r", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/init_ctmr_s",  "x_init_ctmr_s", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/ctmr_ctr_r",   "x_ctmr_ctr_r", 0);

      --------------------------------------------------------
      -- Link Drive Probes
      --------------------------------------------------------

      --------------------------------------------------------
      -- Initializations
      --------------------------------------------------------
      tfy_wr_console(" [*] Simulation Init");
      uut_in                   <= f_uutinit('Z');
      uut_inout.SDAInout       <= 'Z';
      uut_in.arst_n_s          <= '0';
      s_usr_sigin_s.bfm_pass   <= TRUE;

      --------------------------------------------------------
      -- Testcase Steps
      --------------------------------------------------------

      --==============
      -- Step 1
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 1: Initialize FPGA Components ----------------#");
      tfy_wr_step( report_file, now, "1", 
         "Initialize all component inputs and reset FPGA");

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("1.1");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "1.2", 
         "Generate a 16MHz square, 50% duty-cycle signal on Clk input (performed in testbench)");

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("1.3", FALSE, minor_flt_report_s);
      WAIT FOR 1 ms;


      --==============
      -- Step 2
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2: -------------------------------------------#");
      tfy_wr_step( report_file, now, "2",
         "Verify the related output for VCU state NO_WARNING");

      WAIT FOR 50 ms;
      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NO_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "Check if 'penalty_brake_status_s' is solid on '0' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_status_s;
      WAIT ON penalty_brake_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_status_s;
      WAIT ON penalty_brake_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => penalty_brake_status_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DO_5_GREEN_BIT, '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2",
         "Check if 'penalty_brake_s' is solid on '0' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_s;
      WAIT ON penalty_brake_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_s;
      WAIT ON penalty_brake_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => penalty_brake_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_PEN_1_GREEN_BIT, '0', led_code_i);
      Report_LED_IF  ("-", C_LED_PEN_2_GREEN_BIT, '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3",
         "Check if 'buzzer_s' is solid on '0' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= buzzer_s;
      WAIT ON buzzer_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => buzzer_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= buzzer_s;
      WAIT ON buzzer_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => buzzer_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => buzzer_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_BUZZER_GREEN_BIT, '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4",
         "Check if 'warning_light_status_s' is solid on '0' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= warning_light_status_s;
      WAIT ON warning_light_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => warning_light_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= warning_light_status_s;
      WAIT ON warning_light_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => warning_light_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => warning_light_status_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DO_10_GREEN_BIT, '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5",
         "Check if 'warning_light_s' is solid on '0' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= warning_light_s;
      WAIT ON warning_light_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => warning_light_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= warning_light_s;
      WAIT ON warning_light_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => warning_light_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => warning_light_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DO_1_GREEN_BIT, '0', led_code_i);


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "Verify the related output for VCU state 1ST_WARNING");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      WAIT FOR 50 ms;
      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1",
         "Check if 'penalty_brake_status_s' is solid on '0' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_status_s;
      WAIT ON penalty_brake_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_status_s;
      WAIT ON penalty_brake_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => penalty_brake_status_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DO_5_GREEN_BIT, '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2",
         "Check if 'penalty_brake_s' is solid on '0' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_s;
      WAIT ON penalty_brake_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_s;
      WAIT ON penalty_brake_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => penalty_brake_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_PEN_1_GREEN_BIT, '0', led_code_i);
      Report_LED_IF  ("-", C_LED_PEN_2_GREEN_BIT, '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3",
         "Check if 'buzzer_s' is solid on '0' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= buzzer_s;
      WAIT ON buzzer_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => buzzer_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= buzzer_s;
      WAIT ON buzzer_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => buzzer_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => buzzer_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_BUZZER_GREEN_BIT, '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4",
         "Check if 'warning_light_status_s' is solid on '1' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= warning_light_status_s;
      WAIT ON warning_light_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => warning_light_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= warning_light_status_s;
      WAIT ON warning_light_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => warning_light_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => warning_light_status_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DO_10_GREEN_BIT, '1', led_code_i);


      --==============
      -- Step 4
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------------#");
      tfy_wr_step( report_file, now, "4",
         "Verify the related output for VCU state 2ST_WARNING");

      WAIT UNTIL falling_edge(x_init_tmr_s) FOR 5 sec;

      WAIT FOR 50 ms;
      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_2ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1",
         "Check if 'penalty_brake_status_s' is solid on '0' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_status_s;
      WAIT ON penalty_brake_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_status_s;
      WAIT ON penalty_brake_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => penalty_brake_status_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DO_5_GREEN_BIT, '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2",
         "Check if 'penalty_brake_s' is solid on '0' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_s;
      WAIT ON penalty_brake_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_s;
      WAIT ON penalty_brake_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => penalty_brake_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_PEN_1_GREEN_BIT, '0', led_code_i);
      Report_LED_IF  ("-", C_LED_PEN_2_GREEN_BIT, '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3",
         "Check if 'buzzer_s' is solid on '1' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= buzzer_s;
      WAIT ON buzzer_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => buzzer_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= buzzer_s;
      WAIT ON buzzer_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => buzzer_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => buzzer_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_BUZZER_GREEN_BIT, '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4",
         "Check if 'warning_light_status_s' is solid on '1' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= warning_light_status_s;
      WAIT ON warning_light_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => warning_light_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= warning_light_status_s;
      WAIT ON warning_light_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => warning_light_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => warning_light_status_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DO_10_GREEN_BIT, '1', led_code_i);


      --==============
      -- Step 5
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5: -------------------------------------------#");
      tfy_wr_step( report_file, now, "5",
         "Verify the related output for VCU state BRK_NORST");

      WAIT UNTIL falling_edge(x_init_tmr_s) FOR 10 sec;

      WAIT FOR 50 ms;
      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_BRK_NORST,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);


      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1",
         "Check if 'penalty_brake_status_s' is solid on '1' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_status_s;
      WAIT ON penalty_brake_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_status_s;
      WAIT ON penalty_brake_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => penalty_brake_status_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DO_5_GREEN_BIT, '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2",
         "Check if 'penalty_brake_s' is solid on '1' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_s;
      WAIT ON penalty_brake_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_s;
      WAIT ON penalty_brake_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => penalty_brake_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_PEN_1_GREEN_BIT, '1', led_code_i);
      Report_LED_IF  ("-", C_LED_PEN_2_GREEN_BIT, '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3",
         "Check if 'buzzer_s' is solid on '0' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= buzzer_s;
      WAIT ON buzzer_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => buzzer_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= buzzer_s;
      WAIT ON buzzer_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => buzzer_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => buzzer_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_BUZZER_GREEN_BIT, '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4",
         "Check if 'warning_light_status_s' is solid on '1' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= warning_light_status_s;
      WAIT ON warning_light_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => warning_light_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= warning_light_status_s;
      WAIT ON warning_light_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => warning_light_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => warning_light_status_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DO_10_GREEN_BIT, '1', led_code_i);


      --==============
      -- Step 6
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6: -------------------------------------------#");
      tfy_wr_step( report_file, now, "6",
         "Verify the related output for VCU state TRN_STOP_NORST");

      Set_Speed_Cases(1);
      uut_in.zero_spd_ch1_s       <= '1'; 
      uut_in.zero_spd_ch2_s       <= '1';
      WAIT UNTIL falling_edge(x_init_tmr_s) FOR 1 sec;

      WAIT FOR 50 ms;
      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_TRN_STOP_NORST,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1",
         "Check if 'penalty_brake_status_s' is solid on '1' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_status_s;
      WAIT ON penalty_brake_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_status_s;
      WAIT ON penalty_brake_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => penalty_brake_status_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DO_5_GREEN_BIT, '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2",
         "Check if 'penalty_brake_s' is solid on '1' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_s;
      WAIT ON penalty_brake_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_s;
      WAIT ON penalty_brake_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => penalty_brake_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_PEN_1_GREEN_BIT, '1', led_code_i);
      Report_LED_IF  ("-", C_LED_PEN_2_GREEN_BIT, '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3",
         "Check if 'buzzer_s' is solid on '0' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= buzzer_s;
      WAIT ON buzzer_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => buzzer_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= buzzer_s;
      WAIT ON buzzer_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => buzzer_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => buzzer_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_BUZZER_GREEN_BIT, '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4",
         "Check if 'warning_light_status_s' is solid on '1' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= warning_light_status_s;
      WAIT ON warning_light_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => warning_light_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= warning_light_status_s;
      WAIT ON warning_light_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => warning_light_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => warning_light_status_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DO_10_GREEN_BIT, '1', led_code_i);


      --==============
      -- Step 7
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 7: -------------------------------------------#");
      tfy_wr_step( report_file, now, "7",
         "Verify the related output for VCU state NORMAL");

      WAIT UNTIL falling_edge(x_init_tmr_s) FOR 4 sec;

      WAIT FOR 50 ms;
      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NORMAL,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.1",
         "Check if 'penalty_brake_status_s' is solid on '1' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_status_s;
      WAIT ON penalty_brake_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_status_s;
      WAIT ON penalty_brake_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => penalty_brake_status_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.1.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DO_5_GREEN_BIT, '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.2",
         "Check if 'penalty_brake_s' is solid on '1' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_s;
      WAIT ON penalty_brake_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= penalty_brake_s;
      WAIT ON penalty_brake_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => penalty_brake_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => penalty_brake_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.2.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_PEN_1_GREEN_BIT, '1', led_code_i);
      Report_LED_IF  ("-", C_LED_PEN_2_GREEN_BIT, '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.3",
         "Check if 'buzzer_s' is solid on '0' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= buzzer_s;
      WAIT ON buzzer_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => buzzer_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= buzzer_s;
      WAIT ON buzzer_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => buzzer_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => buzzer_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.3.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_BUZZER_GREEN_BIT, '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.4",
         "Check if 'warning_light_status_s' is solid on '1' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= warning_light_status_s;
      WAIT ON warning_light_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => warning_light_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= warning_light_status_s;
      WAIT ON warning_light_status_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => warning_light_status_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => warning_light_status_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.4.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DO_10_GREEN_BIT, '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.5",
         "Check if 'warning_light_s' is solid on '1' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= warning_light_s;
      WAIT ON warning_light_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => warning_light_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= warning_light_s;
      WAIT ON warning_light_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => warning_light_s = prev_output_s,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => warning_light_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.5.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DO_1_GREEN_BIT, '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("7.6");


      --==============
      -- Step 8
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 8: -------------------------------------------#");
      tfy_wr_step( report_file, now, "8",
         "Check if 'warning_light_s' is flashing at freq. equal to 1Hz (50% Duty) for VCU state 1ST_WARNING");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      WAIT FOR 50 ms;
      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.1",
         "Check if 'warning_light_s' is flashing (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= warning_light_s;
      WAIT ON warning_light_s FOR 500 ms;

      ta := now;
      tfy_check( relative_time => now,         received        => warning_light_s = NOT(prev_output_s),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= warning_light_s;
      WAIT ON warning_light_s FOR 500 ms;

      tb := now;
      tfy_check( relative_time => now,         received        => warning_light_s = NOT(prev_output_s),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= warning_light_s;
      WAIT ON warning_light_s FOR 500 ms;

      tc := now;
      tfy_check( relative_time => now,         received        => warning_light_s = NOT(prev_output_s),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; dt := tb - ta;
      tfy_check(relative_time  => now, 
                received       => dT,
                expected_min   => (500 ms)*0.998,
                expected_max   => (500 ms)*1.002,
                report_file    => report_file,
                pass           => pass);

      WAIT FOR 10 ms; dt := tc - tb;
      tfy_check(relative_time  => now, 
                received       => dT,
                expected_min   => (500 ms)*0.998,
                expected_max   => (500 ms)*1.002,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 9
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 9: -------------------------------------------#");
      tfy_wr_step( report_file, now, "9",
         "Check if 'warning_light_s' is flashing at freq. equal to 1Hz (50% Duty) for VCU state 2ST_WARNING");

      WAIT UNTIL falling_edge(x_init_tmr_s) FOR 5 sec;

      WAIT FOR 50 ms;
      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_2ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.1",
         "Check if 'warning_light_s' is flashing (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= warning_light_s;
      WAIT ON warning_light_s FOR 500 ms;

      ta := now;
      tfy_check( relative_time => now,         received        => warning_light_s = NOT(prev_output_s),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= warning_light_s;
      WAIT ON warning_light_s FOR 500 ms;

      tb := now;
      tfy_check( relative_time => now,         received        => warning_light_s = NOT(prev_output_s),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= warning_light_s;
      WAIT ON warning_light_s FOR 500 ms;

      tc := now;
      tfy_check( relative_time => now,         received        => warning_light_s = NOT(prev_output_s),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; dt := tb - ta;
      tfy_check(relative_time  => now, 
                received       => dT,
                expected_min   => (500 ms)*0.998,
                expected_max   => (500 ms)*1.002,
                report_file    => report_file,
                pass           => pass);

      WAIT FOR 10 ms; dt := tc - tb;
      tfy_check(relative_time  => now, 
                received       => dT,
                expected_min   => (500 ms)*0.998,
                expected_max   => (500 ms)*1.002,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 10
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 10: -------------------------------------------#");
      tfy_wr_step( report_file, now, "10",
         "Check if 'warning_light_s' is flashing at freq. equal to 1Hz (50% Duty) for VCU state BRK_NORST");

      WAIT UNTIL falling_edge(x_init_tmr_s) FOR 10 sec;

      WAIT FOR 50 ms;
      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_BRK_NORST,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.1",
         "Check if 'warning_light_s' is flashing (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= warning_light_s;
      WAIT ON warning_light_s FOR 500 ms;

      ta := now;
      tfy_check( relative_time => now,         received        => warning_light_s = NOT(prev_output_s),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= warning_light_s;
      WAIT ON warning_light_s FOR 500 ms;

      tb := now;
      tfy_check( relative_time => now,         received        => warning_light_s = NOT(prev_output_s),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= warning_light_s;
      WAIT ON warning_light_s FOR 500 ms;

      tc := now;
      tfy_check( relative_time => now,         received        => warning_light_s = NOT(prev_output_s),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; dt := tb - ta;
      tfy_check(relative_time  => now, 
                received       => dT,
                expected_min   => (500 ms)*0.998,
                expected_max   => (500 ms)*1.002,
                report_file    => report_file,
                pass           => pass);

      WAIT FOR 10 ms; dt := tc - tb;
      tfy_check(relative_time  => now, 
                received       => dT,
                expected_min   => (500 ms)*0.998,
                expected_max   => (500 ms)*1.002,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 11
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 11: -------------------------------------------#");
      tfy_wr_step( report_file, now, "11",
         "Check if 'warning_light_s' is flashing at freq. equal to 1Hz (50% Duty) for VCU state TRN_STOP_NORST");

      Set_Speed_Cases(1);
      uut_in.zero_spd_ch1_s       <= '1'; 
      uut_in.zero_spd_ch2_s       <= '1';
      WAIT UNTIL falling_edge(x_init_tmr_s) FOR 1 sec;

      WAIT FOR 50 ms;
      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_TRN_STOP_NORST,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.1",
         "Check if 'warning_light_s' is flashing (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output_s <= warning_light_s;
      WAIT ON warning_light_s FOR 500 ms;

      ta := now;
      tfy_check( relative_time => now,         received        => warning_light_s = NOT(prev_output_s),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= warning_light_s;
      WAIT ON warning_light_s FOR 500 ms;

      tb := now;
      tfy_check( relative_time => now,         received        => warning_light_s = NOT(prev_output_s),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output_s <= warning_light_s;
      WAIT ON warning_light_s FOR 500 ms;

      tc := now;
      tfy_check( relative_time => now,         received        => warning_light_s = NOT(prev_output_s),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; dt := tb - ta;
      tfy_check(relative_time  => now, 
                received       => dT,
                expected_min   => (500 ms)*0.998,
                expected_max   => (500 ms)*1.002,
                report_file    => report_file,
                pass           => pass);

      WAIT FOR 10 ms; dt := tc - tb;
      tfy_check(relative_time  => now, 
                received       => dT,
                expected_min   => (500 ms)*0.998,
                expected_max   => (500 ms)*1.002,
                report_file    => report_file,
                pass           => pass);


      --------------------------------------------------------
      -- END
      --------------------------------------------------------
      WAIT FOR 2 ms;
      --------------------------------------------------------
      -- Testcase End Sequence
      --------------------------------------------------------

      tfy_tc_end(
         tc_pass        => pass,
         report_file    => report_file,
         tc_name        => "TC_RS141_143_152_197_164",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "14 Jan 2020",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s    
      );

   END PROCESS p_steps;

   s_usr_sigin_s.test_select  <= test_select;
   s_usr_sigin_s.clk          <= Clk;
   test_done                  <= s_usr_sigout_s.test_done;
   pwm_func_model_data        <= pwm_func_model_data_s;
   st_ch1_in_ctrl_o           <= st_ch1_in_ctrl_s; 
   st_ch2_in_ctrl_o           <= st_ch2_in_ctrl_s; 
   
   minor_flt_report_s         <= uut_out.tms_minor_fault_s AND uut_out.disp_minor_fault_s;

   penalty_brake_s            <= NOT (uut_out.penalty1_out_s AND uut_out.penalty2_out_s);
   penalty_brake_status_s     <= uut_out.tms_penalty_stat_s;
   warning_light_s            <= uut_out.light_out_s;
   warning_light_status_s     <= uut_out.tms_vis_warn_stat_s;
   buzzer_s                   <= uut_out.buzzer_out_s;
END ARCHITECTURE TC_RS141_143_152_197_164;

