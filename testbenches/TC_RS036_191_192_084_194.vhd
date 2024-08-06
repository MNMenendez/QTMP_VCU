-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS036_191_192_084_194
-- Module      : Input IF
-- Revision    : 2.0
-- Date        : 09 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Verify the permanent masking capabilities for all error conditions of the PWM module.
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-36
--    FPGA-REQ-191
--    FPGA-REQ-192
--    FPGA-REQ-84
--    FPGA-REQ-194
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 06 Apr 2018
--    - CABelchior (1.0): Initial Release
-- Revision 1.1 - 29 Aug 2018
--    - CABelchior (1.1): CCN2
-- Revision 1.2 - 30 May 2019
--    - CABelchior (1.2): CCN3
-- Revision 2.0 - 09 Dec 2019
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
--
-- sim -tc TC_RS036_191_192_084_194 -nocov -numstdoff
-- log -r /*
--
-- 36    Any condition causing either or both PWM being masked permanently shall result in a minor error 
--       status flag being asserted.
--
-- 191   Each PWM channel shall have an error counter associated with it. When this counter has a non-zero 
--       value the corresponding PWM channel shall be masked.
-- 
-- 192   When a PWM error counter reaches 16383, the corresponding PWM channel shall be masked permanently.
--
-- 84    The dedicated PWM LED shall stay green when both PWM inputs are not faulted, orange if either input 
--       is faulted and red when both inputs are faulted.
--
-- 194   If the PWM is in the faulted stated, i.e. permanently masked on both channels, the PWM shall be 
--       considered in a 'No Power' position for the purposes of the vigilance timing cycle.

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;
USE WORK.txt_util_p.ALL;

ARCHITECTURE TC_RS036_191_192_084_194 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Type Definitions

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------
   CONSTANT C_PWM_INITIAL         : pwm_func_model_inputs := ( time_high_1 => 2.00 ms * ( 70.00 / 100.00 ),
                                                               time_high_2 => 2.00 ms * ( 70.00 / 100.00 ),
                                                               offset      => 0 us,
                                                               on_off      => '1', 
                                                               period_1    => 2.00 ms,
                                                               period_2    => 2.00 ms);

   CONSTANT C_PWM_INV_PERIOD      : pwm_func_model_inputs := ( time_high_1 => 2.00 ms * ( 70.00 / 100.00 ),
                                                               time_high_2 => 2.00 ms * ( 70.00 / 100.00 ),
                                                               offset      => 0 us,
                                                               on_off      => '1', 
                                                               period_1    => 2.05 ms,
                                                               period_2    => 2.05 ms);

   CONSTANT C_PWM_INV_OFFSET      : pwm_func_model_inputs := ( time_high_1 => 2.00 ms * ( 70.00 / 100.00 ),
                                                               time_high_2 => 2.00 ms * ( 70.00 / 100.00 ),
                                                               offset      => 25 us,
                                                               on_off      => '1', 
                                                               period_1    => 2.00 ms,
                                                               period_2    => 2.00 ms);

   CONSTANT C_PWM_INV_DUTYDIFF    : pwm_func_model_inputs := ( time_high_1 => 2.00 ms * ( 50.00 / 100.00 ),
                                                               time_high_2 => 2.00 ms * ( 70.00 / 100.00 ),
                                                               offset      => 25 us,
                                                               on_off      => '1', 
                                                               period_1    => 2.00 ms,
                                                               period_2    => 2.00 ms);

   CONSTANT C_PWM_INV_VALUE       : pwm_func_model_inputs := ( time_high_1 => 2.00 ms * ( 96.00 / 100.00 ),
                                                               time_high_2 => 2.00 ms * ( 96.00 / 100.00 ),
                                                               offset      => 25 us,
                                                               on_off      => '1', 
                                                               period_1    => 2.00 ms,
                                                               period_2    => 2.00 ms);

   CONSTANT C_PWM_INV_CH1         : pwm_func_model_inputs := ( time_high_1 => 2.00 ms * ( 00.00 / 100.00 ),
                                                               time_high_2 => 2.00 ms * ( 70.00 / 100.00 ),
                                                               offset      => 0 us,
                                                               on_off      => '1', 
                                                               period_1    => 2.00 ms,
                                                               period_2    => 2.00 ms);

   CONSTANT C_PWM_INV_CH2         : pwm_func_model_inputs := ( time_high_1 => 2.00 ms * ( 70.00 / 100.00 ),
                                                               time_high_2 => 2.00 ms * ( 00.00 / 100.00 ),
                                                               offset      => 0 us,
                                                               on_off      => '1', 
                                                               period_1    => 2.00 ms,
                                                               period_2    => 2.00 ms);

   CONSTANT C_PWM_INV_CH1CH2      : pwm_func_model_inputs := ( time_high_1 => 2.00 ms * ( 00.00 / 100.00 ),
                                                               time_high_2 => 2.00 ms * ( 00.00 / 100.00 ),
                                                               offset      => 0 us,
                                                               on_off      => '1', 
                                                               period_1    => 2.00 ms,
                                                               period_2    => 2.00 ms);

   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------
   SIGNAL x_opmode_curst_r                        : opmode_st_t;
   SIGNAL x_vcut_curst_r                          : vcut_st_t;

   -- PWM Capture Module
   SIGNAL x_pwm_update_o_u0                       : STD_LOGIC;
   SIGNAL x_pwm_det_fault_o_u0                    : STD_LOGIC;
   SIGNAL x_pwm_update_o_u1                       : STD_LOGIC;
   SIGNAL x_pwm_det_fault_o_u1                    : STD_LOGIC;

   -- PWM Compare Module
   SIGNAL x_pwm_compare_fault_o                   : STD_LOGIC;

   -- PWM Counter Error Module
   SIGNAL x_pwm_error_counter_u0                  : STD_LOGIC_VECTOR(13 DOWNTO 0);
   SIGNAL x_pwm_mask_o_u0                         : STD_LOGIC;
   SIGNAL x_pwm_fault_o_u0                        : STD_LOGIC;
   SIGNAL x_pwm_error_counter_u1                  : STD_LOGIC_VECTOR(13 DOWNTO 0);
   SIGNAL x_pwm_mask_o_u1                         : STD_LOGIC;
   SIGNAL x_pwm_fault_o_u1                        : STD_LOGIC;

   -- PWM Interpret DC Value Module
   SIGNAL x_pwm_duty_valid_o_u0                   : STD_LOGIC;
   SIGNAL x_pwm_duty_valid_o_u1                   : STD_LOGIC;

   -- PWM Demand Phase Detect
   SIGNAL x_mc_no_pwr_o                           : STD_LOGIC;


   --------------------------------------------------------
   -- Drive Probes
   --------------------------------------------------------

   --------------------------------------------------------
   -- User Signals
   --------------------------------------------------------
   SIGNAL s_usr_sigout_s                          : tfy_user_out;
   SIGNAL s_usr_sigin_s                           : tfy_user_in;
   SIGNAL pwm_func_model_data_s                   : pwm_func_model_inputs := C_PWM_INITIAL;   
   SIGNAL st_ch1_in_ctrl_s                        : ST_BEHAVIOR_CH1;
   SIGNAL st_ch2_in_ctrl_s                        : ST_BEHAVIOR_CH2;

   SIGNAL minor_flt_report_s                      : STD_LOGIC := '0';

   SIGNAL event_latch_rst_r                       : STD_LOGIC := '0';
   SIGNAL event_pwm_event_latch_r                 : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');

BEGIN

   p_steps: PROCESS

      --------------------------------------------------------
      -- Common Test Case variable declarations
      --------------------------------------------------------
      VARIABLE pass                              : BOOLEAN := true;

      --------------------------------------------------------
      -- Other Testcase Variables
      --------------------------------------------------------
      VARIABLE t0 : TIME;
      VARIABLE dt : TIME;

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

      PROCEDURE Reset_Checker (Step : STRING) IS 
      BEGIN
         -------------------------------------------------
         tfy_wr_step( report_file, now, Step, 
            "Reset event checker");
         WAIT FOR 1 us;
         event_latch_rst_r <= '1';
         wait_for_clk_cycles(1, Clk);
         event_latch_rst_r <= '0';
         WAIT FOR 1 us;
      END PROCEDURE Reset_Checker;

      PROCEDURE Reset_UUT (Step : STRING) IS 
      BEGIN
         -------------------------------------------------
         tfy_wr_step( report_file, now, Step, 
            "Configure and reset UUT to clear all persistent errors");

         -------------------------------------------------
         tfy_wr_step( report_file, now, Step & ".1", 
            "Configure all functional models to normal behavior");
         st_ch1_in_ctrl_s  <= (OTHERS => C_ST_FUNC_MODEL_ARRAY_INIT);
         st_ch2_in_ctrl_s  <= (OTHERS => C_ST_FUNC_MODEL_ARRAY_INIT);
         fb_func_model_behaviour <= C_OUT_FB_FUNC_MODEL_BEHAVIOUR_INIT;
         pwm_func_model_data_s   <= C_PWM_INITIAL;

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
         report_fname   => "TC_RS036_191_192_084_194.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS036_191_192_084_194",
         test_module    => "Input IF",
         tc_revision    => "2.0",
         tc_date        => "09 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Verify the permanent masking capabilities for all error conditions of the PWM module.",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_top_tb",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s
      );

      --------------------------------------------------------
      -- Link Spy Probes
      --------------------------------------------------------
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_fsm_i0/opmode_curst_r",   "x_opmode_curst_r", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/vcut_curst_r", "x_vcut_curst_r", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pwm_input_i0/pwm_capture_u0/pwm_update_o", "x_pwm_update_o_u0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pwm_input_i0/pwm_capture_u0/pwm_fault_o", "x_pwm_det_fault_o_u0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pwm_input_i0/pwm_capture_u1/pwm_update_o", "x_pwm_update_o_u1", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pwm_input_i0/pwm_capture_u1/pwm_fault_o", "x_pwm_det_fault_o_u1", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pwm_input_i0/pwm_compare_u0/pwm_compare_fault_o", "x_pwm_compare_fault_o", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u0/pwm_counter_error_u/counter_r", "x_pwm_error_counter_u0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u0/pwm_counter_error_u/mask_o", "x_pwm_mask_o_u0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u0/pwm_counter_error_u/fault_o", "x_pwm_fault_o_u0", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u1/pwm_counter_error_u/counter_r", "x_pwm_error_counter_u1", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u1/pwm_counter_error_u/mask_o", "x_pwm_mask_o_u1", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u1/pwm_counter_error_u/fault_o", "x_pwm_fault_o_u1", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u0/pwm_duty_valid_o", "x_pwm_duty_valid_o_u0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u1/pwm_duty_valid_o", "x_pwm_duty_valid_o_u1", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/mc_no_pwr_o", "x_mc_no_pwr_o", 0);

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

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("1.4");


      --==============
      -- Step 2
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2: -------------------------------------------#");
      tfy_wr_step( report_file, now, "2",
         "Verify the a permanent mask capability of both PWM channels due to invalid period (REQ 34)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.1");
      tfy_wr_step( report_file, now, "2.1",
         "Set the PWM Module with a valid configuration for both channels"); 

      pwm_func_model_data_s  <= C_PWM_INITIAL;

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_PWM_CH1_BIT, '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PWM_CH2_BIT, '0', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PWM_GREEN_BIT,'1', led_code_i);
      Report_LED_IF  ("-", C_LED_PWM_RED_BIT,  '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("2.1.2", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.3",
         "Check if Master Controller is in 'No Power' position (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.4",
         "Check if PWM CH1 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.5",
         "Check if PWM CH1 is NOT masked and NOT faulted (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.6",
         "Check if PWM CH2 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.7",
         "Check if PWM CH2 is NOT masked and NOT faulted (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.2");
      tfy_wr_step( report_file, now, "2.2",
         "Configure PWM Module with an invalid period for both channels"); 

      pwm_func_model_data_s  <= C_PWM_INV_PERIOD;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.3");
      tfy_wr_step( report_file, now, "2.3",
         "Wait until the PWM error counter reached its maximum"); 

      WAIT UNTIL x_pwm_error_counter_u0 = "11111111111111" FOR 34 sec;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.4");
      tfy_wr_step( report_file, now, "2.4",
         "Set the PWM Module with a valid configuration for both channels"); 

      pwm_func_model_data_s  <= C_PWM_INITIAL;

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.5");
      tfy_wr_step( report_file, now, "2.5",
         "Check the effect of the permanent mask capability"); 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_PWM_CH1_BIT, '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PWM_CH2_BIT, '1', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PWM_GREEN_BIT,'0', led_code_i);
      Report_LED_IF  ("-", C_LED_PWM_RED_BIT,  '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("2.5.2", TRUE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.3",
         "Check if Master Controller is in 'No Power' position (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.4",
         "Check if PWM CH1 error counter is '11111111111111' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "11111111111111",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.5",
         "Check if PWM CH1 IS masked and IS faulted (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.6",
         "Check if PWM CH2 error counter is '11111111111111' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "11111111111111",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.7",
         "Check if PWM CH2 IS masked and IS faulted (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.5.8");

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("2.5.9");
      WAIT FOR 1 ms;


      --==============
      -- Step 3
      --==============
      -- Note: this step will fail when run with C_CLK_DERATE_BITS: NATURAL != 0;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "Verify the a permanent mask capability of both PWM channels due to invalid differential propagation delay (REQ 35)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.1");
      tfy_wr_step( report_file, now, "3.1",
         "Set the PWM Module with a valid configuration for both channels"); 

      pwm_func_model_data_s   <= C_PWM_INITIAL;
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.2");
      tfy_wr_step( report_file, now, "3.2",
         "Configure PWM Module with an invalid differential propagation delay"); 

      pwm_func_model_data_s  <= C_PWM_INV_OFFSET;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.3");
      tfy_wr_step( report_file, now, "3.3",
         "Wait until the PWM error counter reached its maximum"); 

      WAIT UNTIL x_pwm_error_counter_u0 = "11111111111111" FOR 34 sec;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.4");
      tfy_wr_step( report_file, now, "3.4",
         "Set the PWM Module with a valid configuration for both channels"); 

      pwm_func_model_data_s   <= C_PWM_INITIAL;

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.5");
      tfy_wr_step( report_file, now, "3.5",
         "Check the effect of the permanent mask capability"); 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_PWM_CH1_BIT, '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PWM_CH2_BIT, '1', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PWM_GREEN_BIT,'0', led_code_i);
      Report_LED_IF  ("-", C_LED_PWM_RED_BIT,  '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("3.5.2", TRUE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5.3",
         "Check if Master Controller is in 'No Power' position (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5.4",
         "Check if PWM CH1 error counter is '11111111111111' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "11111111111111",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5.5",
         "Check if PWM CH1 IS masked and IS faulted (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5.6",
         "Check if PWM CH2 error counter is '11111111111111' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "11111111111111",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5.7",
         "Check if PWM CH2 IS masked and IS faulted (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.5.8");

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("3.5.9");
      WAIT FOR 1 ms;


      --==============
      -- Step 4
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------------#");
      tfy_wr_step( report_file, now, "4",
         "Verify the a permanent mask capability of both PWM channels due to invalid difference in duty cycle (REQ 81)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.1");
      tfy_wr_step( report_file, now, "4.1",
         "Set the PWM Module with a valid configuration for both channels"); 

      pwm_func_model_data_s  <= C_PWM_INITIAL;

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.2");
      tfy_wr_step( report_file, now, "4.2",
         "Configure PWM Module with an invalid difference in duty cycle"); 

      pwm_func_model_data_s  <= C_PWM_INV_DUTYDIFF;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.3");
      tfy_wr_step( report_file, now, "4.3",
         "Wait until the PWM error counter reached its maximum"); 

      WAIT UNTIL x_pwm_error_counter_u0 = "11111111111111" FOR 34 sec;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.4");
      tfy_wr_step( report_file, now, "4.4",
         "Set the PWM Module with a valid configuration for both channels"); 

      pwm_func_model_data_s  <= C_PWM_INITIAL;

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.5");
      tfy_wr_step( report_file, now, "4.5",
         "Check the effect of the permanent mask capability"); 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_PWM_CH1_BIT, '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PWM_CH2_BIT, '1', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PWM_GREEN_BIT,'0', led_code_i);
      Report_LED_IF  ("-", C_LED_PWM_RED_BIT,  '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("4.5.2", TRUE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5.3",
         "Check if Master Controller is in 'No Power' position (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5.4",
         "Check if PWM CH1 error counter is '11111111111111' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "11111111111111",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5.5",
         "Check if PWM CH1 IS masked and IS faulted (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5.6",
         "Check if PWM CH2 error counter is '11111111111111' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "11111111111111",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5.7",
         "Check if PWM CH2 IS masked and IS faulted (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.5.8");

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("4.5.9");
      WAIT FOR 1 ms;


      --==============
      -- Step 5
      --==============
      -- Note: se essa falha for apenas em um canal, o erro indicado é outro, nomeadamente o REQ 81
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5: -------------------------------------------#");
      tfy_wr_step( report_file, now, "5",
         "Verify the a permanent mask capability of both PWM channels due to invalid duty cycle limits (REQ 82)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.1");
      tfy_wr_step( report_file, now, "5.1",
         "Set the PWM Module with a valid configuration for both channels"); 

      pwm_func_model_data_s  <= C_PWM_INITIAL;

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.2");
      tfy_wr_step( report_file, now, "5.2",
         "Configure PWM Module with an invalid duty cycle"); 

      pwm_func_model_data_s  <= C_PWM_INV_VALUE;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.3");
      tfy_wr_step( report_file, now, "5.3",
         "Wait until the PWM error counter reached its maximum"); 

      WAIT UNTIL x_pwm_error_counter_u0 = "11111111111111" FOR 34 sec;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.4");
      tfy_wr_step( report_file, now, "5.4",
         "Set the PWM Module with a valid configuration for both channels"); 

      pwm_func_model_data_s  <= C_PWM_INITIAL;

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.5");
      tfy_wr_step( report_file, now, "5.5",
         "Check the effect of the permanent mask capability"); 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_PWM_CH1_BIT, '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PWM_CH2_BIT, '1', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PWM_GREEN_BIT,'0', led_code_i);
      Report_LED_IF  ("-", C_LED_PWM_RED_BIT,  '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("1.3", TRUE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5.3",
         "Check if Master Controller is in 'No Power' position (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5.4",
         "Check if PWM CH1 error counter is '11111111111111' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "11111111111111",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5.5",
         "Check if PWM CH1 IS masked and IS faulted (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5.6",
         "Check if PWM CH2 error counter is '11111111111111' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "11111111111111",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5.7",
         "Check if PWM CH2 IS masked and IS faulted (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.5.8");

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("5.5.9");
      WAIT FOR 1 ms;


      --==============
      -- Step 6
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6: -------------------------------------------#");
      tfy_wr_step( report_file, now, "6",
         "Verify the a permanent mask capability of PWM channel 1 due to stopping in transitioning (REQ 80)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6.1");
      tfy_wr_step( report_file, now, "6.1",
         "Set the PWM Module with a valid configuration for both channels"); 

      pwm_func_model_data_s  <= C_PWM_INITIAL;

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6.2");
      tfy_wr_step( report_file, now, "6.2",
         "Configure PWM Module with CH1 not transitioning"); 

      pwm_func_model_data_s  <= C_PWM_INV_CH1;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6.3");
      tfy_wr_step( report_file, now, "6.3",
         "Wait until the PWM error counter reached its maximum"); 

      WAIT UNTIL x_pwm_error_counter_u0 = "11111111111111" FOR 34 sec;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6.4");
      tfy_wr_step( report_file, now, "6.4",
         "Set the PWM Module with a valid configuration for both channels"); 

      pwm_func_model_data_s  <= C_PWM_INITIAL;

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6.5");
      tfy_wr_step( report_file, now, "6.5",
         "Check the effect of the permanent mask capability"); 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.5.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_PWM_CH1_BIT, '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PWM_CH2_BIT, '0', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PWM_GREEN_BIT,'1', led_code_i);
      Report_LED_IF  ("-", C_LED_PWM_RED_BIT,  '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("6.5.2", TRUE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.5.3",
         "Check if Master Controller is in 'No Power' position (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.5.4",
         "Check if PWM CH1 error counter is '11111111111111' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "11111111111111",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.5.5",
         "Check if PWM CH1 IS masked and IS faulted (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.5.6",
         "Check if PWM CH2 error counter is '11111111111111' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "11111111111111",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.5.7",
         "Check if PWM CH2 IS masked and IS faulted (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("6.5.8");

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("6.5.9");
      WAIT FOR 1 ms;


      --==============
      -- Step 7
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 7: -------------------------------------------#");
      tfy_wr_step( report_file, now, "7",
         "Verify the a permanent mask capability of PWM channel 2 due to stopping in transitioning (REQ 80)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 7.1");
      tfy_wr_step( report_file, now, "7.1",
         "Set the PWM Module with a valid configuration for both channels"); 

      pwm_func_model_data_s  <= C_PWM_INITIAL;

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 7.2");
      tfy_wr_step( report_file, now, "7.2",
         "Configure PWM Module with CH2 not transitioning"); 

      pwm_func_model_data_s  <= C_PWM_INV_CH2;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 7.3");
      tfy_wr_step( report_file, now, "7.3",
         "Wait until the PWM error counter reached its maximum"); 

      WAIT UNTIL x_pwm_error_counter_u1 = "11111111111111";

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 7.4");
      tfy_wr_step( report_file, now, "7.4",
         "Set the PWM Module with a valid configuration for both channels"); 

      pwm_func_model_data_s  <= C_PWM_INITIAL;

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 7.5");
      tfy_wr_step( report_file, now, "7.5",
         "Check the effect of the permanent mask capability"); 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.5.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_PWM_CH1_BIT, '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PWM_CH2_BIT, '1', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PWM_GREEN_BIT,'1', led_code_i);
      Report_LED_IF  ("-", C_LED_PWM_RED_BIT,  '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("7.5.2", TRUE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.5.3",
         "Check if Master Controller is in 'No Power' position (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.5.4",
         "Check if PWM CH1 error counter is '11111111111111' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "11111111111111",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.5.5",
         "Check if PWM CH1 IS masked and IS faulted (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.5.6",
         "Check if PWM CH2 error counter is '11111111111111' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "11111111111111",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.5.7",
         "Check if PWM CH2 IS masked and IS faulted (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("7.5.8");

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("7.5.9");
      WAIT FOR 1 ms;


      --==============
      -- Step 8
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 8: -------------------------------------------#");
      tfy_wr_step( report_file, now, "8",
         "Verify the a permanent mask capability of both PWM channels due to stopping in transitioning (REQ 80)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 8.1");
      tfy_wr_step( report_file, now, "8.1",
         "Set the PWM Module with a valid configuration for both channels"); 

      pwm_func_model_data_s  <= C_PWM_INITIAL;

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 8.2");
      tfy_wr_step( report_file, now, "8.2",
         "Configure PWM Module with CH1 and CH2 not transitioning"); 

      pwm_func_model_data_s  <= C_PWM_INV_CH1CH2;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 8.3");
      tfy_wr_step( report_file, now, "8.3",
         "Wait until the PWM error counter reached its maximum"); 

      WAIT UNTIL x_pwm_error_counter_u1 = "11111111111111";

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 8.4");
      tfy_wr_step( report_file, now, "8.4",
         "Set the PWM Module with a valid configuration for both channels"); 

      pwm_func_model_data_s  <= C_PWM_INITIAL;

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 8.5");
      tfy_wr_step( report_file, now, "8.5",
         "Check the effect of the permanent mask capability"); 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.5.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_PWM_CH1_BIT, '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PWM_CH2_BIT, '1', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PWM_GREEN_BIT,'0', led_code_i);
      Report_LED_IF  ("-", C_LED_PWM_RED_BIT,  '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("8.5.2", TRUE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.5.3",
         "Check if Master Controller is in 'No Power' position (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.5.4",
         "Check if PWM CH1 error counter is '11111111111111' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "11111111111111",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.5.5",
         "Check if PWM CH1 IS masked and IS faulted (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.5.6",
         "Check if PWM CH2 error counter is '11111111111111' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "11111111111111",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.5.7",
         "Check if PWM CH2 IS masked and IS faulted (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("8.5.8");

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("8.5.9");
      WAIT FOR 1 ms;




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
         tc_name        => "TC_RS036_191_192_084_194",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "09 Dec 2019",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s    
      );

   END PROCESS p_steps;

    p_event_latch: PROCESS(event_latch_rst_r, x_pwm_det_fault_o_u0, x_pwm_det_fault_o_u1, x_pwm_compare_fault_o, x_pwm_duty_valid_o_u0, x_pwm_duty_valid_o_u1)
    BEGIN
        IF rising_edge(event_latch_rst_r) THEN
            event_pwm_event_latch_r(0) <= '0';
            event_pwm_event_latch_r(1) <= '0';
            event_pwm_event_latch_r(2) <= '0';
            event_pwm_event_latch_r(3) <= '0';
            event_pwm_event_latch_r(4) <= '0';
        ELSE
            IF rising_edge(x_pwm_det_fault_o_u0) THEN
                event_pwm_event_latch_r(0) <= '1';
            END IF;

            IF rising_edge(x_pwm_det_fault_o_u1) THEN
                event_pwm_event_latch_r(1) <= '1';
            END IF;

            IF rising_edge(x_pwm_compare_fault_o) THEN
                event_pwm_event_latch_r(2) <= '1';
            END IF;

            IF falling_edge(x_pwm_duty_valid_o_u0) THEN
                event_pwm_event_latch_r(3) <= '1';
            END IF;

            IF falling_edge(x_pwm_duty_valid_o_u1) THEN
                event_pwm_event_latch_r(4) <= '1';
            END IF;

        END IF;
    END PROCESS p_event_latch;

   s_usr_sigin_s.test_select  <= test_select;
   s_usr_sigin_s.clk          <= Clk;
   test_done                  <= s_usr_sigout_s.test_done;
   pwm_func_model_data        <= pwm_func_model_data_s;
   st_ch1_in_ctrl_o           <= st_ch1_in_ctrl_s; 
   st_ch2_in_ctrl_o           <= st_ch2_in_ctrl_s; 

   minor_flt_report_s         <= uut_out.tms_minor_fault_s AND uut_out.disp_minor_fault_s;


END ARCHITECTURE TC_RS036_191_192_084_194;

