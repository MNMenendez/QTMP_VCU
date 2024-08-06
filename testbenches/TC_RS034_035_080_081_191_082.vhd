-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS034_035_080_081_191_082
-- Module      : Input IF
-- Revision    : 2.0
-- Date        : 09 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Check all error conditions of the PWM module and their respective influences on PWM's error counters and masking flags.
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-34
--    FPGA-REQ-35
--    FPGA-REQ-80
--    FPGA-REQ-81
--    FPGA-REQ-191
--    FPGA-REQ-82
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
-- sim -tc TC_RS034_035_080_081_191_082 -numstdoff -nocov
-- log -r /*
--
-- 34    To measure the periodicity of the PWM, the CPLD shall sample each PWM signal and measure the 
--       period between two rising edges. Allowing for a PWM clock frequency error, it is expected that 
--       the period measured shall be 2mS +- 40uS. A measured period that falls outside these limits will 
--       result in incrementing the corresponding PWM channels error counter. 
--       >> PWM Capture Module
-- System tolerance:    2ms +- 40us 
-- Sampling tolerance:  ~ +- 10us
--
-- 35    The CPLD shall continuously compare the signal profiles of both PWM input signals taking into 
--       account the maximum differential propagation delay of 15us.
--       >> PWM Compare Module
-- System tolerance:    15us 
-- Sampling tolerance:  ~ +- 5us
--
-- 80    A conflicting comparison where either PWM input stopped transitioning shall result in incrementing 
--       of the PWM error counter.
--       >> PWM Compare Module
--
-- 81    A conflicting comparison in the width of the transitions of both PWM inputs shall result in masking 
--       of both PWM inputs since there is no reliable reference source, and incrementing both pwm error 
--       counters. The admissible margin is 23.5us.
--       >> PWM Compare Module
-- System tolerance:    23.5us
-- Sampling tolerance:  ~ +- 5us
--
-- 37    If no comparison errors are detected between the two PWM inputs, the Duty-Cycle thresholds for the 
--       operations modes shall be as follows:
-- 37.01 (0-5%):           Invalid
-- 37.08 (95%-100%) :      Invalid
--
-- NOTE: All thresholds should account a tolerance of +-0.3% to account for precision losses due to digitization.
--
-- 82    The invalid ranges shall result in the corresponding error counter being incremented.
--
-- 191   Each PWM channel shall have an error counter associated with it. When this counter has a non-zero 
--       value the corresponding PWM channel shall be masked.
--

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;
USE WORK.txt_util_p.ALL;

ARCHITECTURE TC_RS034_035_080_081_191_082 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Type Definitions
   --------------------------------------------------------

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------

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
   SIGNAL pwm_func_model_data_s                   : pwm_func_model_inputs := C_PWM_FUNC_MODEL_INPUTS_INIT;   
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

         pwm_func_model_data_s  <= ( time_high_1 => 1 ms,
                                     time_high_2 => 1 ms,
                                     offset      => 0 ns,
                                     on_off      => '1', 
                                     period_1    => 2 ms,
                                     period_2    => 2 ms);

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
         report_fname   => "TC_RS034_035_080_081_191_082.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS034_035_080_081_191_082",
         test_module    => "Input IF",
         tc_revision    => "2.0",
         tc_date        => "09 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Check all error conditions of the PWM module and their respective influences on PWM's error counters and masking flags.",
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

      -- 34    To measure the periodicity of the PWM, the CPLD shall sample each PWM signal and measure the 
      --       period between two rising edges. Allowing for a PWM clock frequency error, it is expected that 
      --       the period measured shall be 2mS +- 40uS. A measured period that falls outside these limits will 
      --       result in incrementing the corresponding PWM channels error counter. 
      --       >> PWM Capture Module

      -- System tolerance:    2ms +- 40us 
      -- Sampling tolerance:  ~ +- 10us

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2: -------------------------------------------#");
      tfy_wr_step( report_file, now, "2",
         "Check the PWM period variation limits (REQ 34)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.1");
      tfy_wr_step( report_file, now, "2.1",
         "Configure PWM Module with a period of 2.040ms - 10us"); 

      pwm_func_model_data_s  <= ( time_high_1 => 1.00 ms,
                                  time_high_2 => 1.00 ms,
                                  offset      => 0 ns,
                                  on_off      => '1', 
                                  period_1    => 2.030 ms,
                                  period_2    => 2.030 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.1",
         "Check if PWM Capture module found an error on CH1 (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(0) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.2",
         "Check if PWM CH1 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.3",
         "Check if PWM CH1 is NOT masked (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.4",
         "Check if PWM Capture module found an error on CH2 (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.5",
         "Check if PWM CH2 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.6",
         "Check if PWM CH2 is NOT masked (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("2.1.7");
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.2");
      tfy_wr_step( report_file, now, "2.2",
         "Configure PWM Module with a period of 2.040ms + 10us"); 

      pwm_func_model_data_s  <= ( time_high_1 => 1.00 ms,
                                  time_high_2 => 1.00 ms,
                                  offset      => 0 ns,
                                  on_off      => '1', 
                                  period_1    => 2.050 ms,
                                  period_2    => 2.050 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.1",
         "Check if PWM Capture module found an error on CH1 (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(0) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.2",
         "Check if PWM CH1 error counter is '00000000000000' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "00000000000000",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.3",
         "Check if PWM CH1 is NOT masked (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '0',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.4",
         "Check if PWM Capture module found an error on CH2 (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(1) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.5",
         "Check if PWM CH2 error counter is '00000000000000' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "00000000000000",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.6",
         "Check if PWM CH2 is NOT masked (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '0',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.2.7");

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("2.2.8");
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.3");
      tfy_wr_step( report_file, now, "2.3",
         "Configure PWM Module with a period of 1.960ms + 10us"); 

      pwm_func_model_data_s  <= ( time_high_1 => 1.00 ms,
                                  time_high_2 => 1.00 ms,
                                  offset      => 0 ns,
                                  on_off      => '1', 
                                  period_1    => 1.970 ms,
                                  period_2    => 1.970 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.1",
         "Check if PWM Capture module found an error on CH1 (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(0) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.2",
         "Check if PWM CH1 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.3",
         "Check if PWM CH1 is NOT masked (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.4",
         "Check if PWM Capture module found an error on CH2 (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.5",
         "Check if PWM CH2 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.6",
         "Check if PWM CH2 is NOT masked (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("2.3.7");
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.4");
      tfy_wr_step( report_file, now, "2.4",
         "Configure PWM Module with a period of 1.960ms - 10us"); 

      pwm_func_model_data_s  <= ( time_high_1 => 1.00 ms,
                                  time_high_2 => 1.00 ms,
                                  offset      => 0 ns,
                                  on_off      => '1', 
                                  period_1    => 1.950 ms,
                                  period_2    => 1.950 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.1",
         "Check if PWM Capture module found an error on CH1 (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(0) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.2",
         "Check if PWM CH1 error counter is '00000000000000' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "00000000000000",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.3",
         "Check if PWM CH1 is NOT masked (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '0',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.4",
         "Check if PWM Capture module found an error on CH2 (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(1) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.5",
         "Check if PWM CH2 error counter is '00000000000000' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "00000000000000",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.6",
         "Check if PWM CH2 is NOT masked (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '0',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);


      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.4.7");

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("2.4.8");
      WAIT FOR 1 ms;


      --==============
      -- Step 3
      --==============

      -- 35    The CPLD shall continuously compare the signal profiles of both PWM input signals taking into 
      --       account the maximum differential propagation delay of 15us.
      --       >> PWM Compare Module

      -- System tolerance:    15us 
      -- Sampling tolerance:  ~ +- 5us

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "Check the PWM maximum differential propagation delay (REQ 35)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.1");
      tfy_wr_step( report_file, now, "3.1",
         "Configure PWM Module with an offset of 15us - 5us"); 

      pwm_func_model_data_s  <= ( time_high_1 => 1.00 ms,
                                  time_high_2 => 1.00 ms,
                                  offset      => 10 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.1",
         "Check if PWM Compare module found an error (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(2) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.2",
         "Check if PWM CH1 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.3",
         "Check if PWM CH1 is NOT masked (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.4",
         "Check if PWM CH2 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.5",
         "Check if PWM CH2 is NOT masked (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("3.1.6");
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.2");
      tfy_wr_step( report_file, now, "3.2",
         "Configure PWM Module with an offset of 15us + 5us"); 

      pwm_func_model_data_s  <= ( time_high_1 => 1.00 ms,
                                  time_high_2 => 1.00 ms,
                                  offset      => 20 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.1",
         "Check if PWM Compare module found an error (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(2) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.2",
         "Check if PWM CH1 error counter is '00000000000000' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "00000000000000",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.3",
         "Check if PWM CH1 is NOT masked (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '0',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.4",
         "Check if PWM CH2 error counter is '00000000000000' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "00000000000000",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.5",
         "Check if PWM CH2 is NOT masked (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '0',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.2.6");

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("3.2.7");
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------      
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.3");
      tfy_wr_step( report_file, now, "3.3",
         "Configure PWM Module with an offset of -15us + 5us"); 

      pwm_func_model_data_s  <= ( time_high_1 => 1.00 ms,
                                  time_high_2 => 1.00 ms,
                                  offset      => -10 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.1",
         "Check if PWM Compare module found an error (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(2) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.2",
         "Check if PWM CH1 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.3",
         "Check if PWM CH1 is NOT masked (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.4",
         "Check if PWM CH2 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.5",
         "Check if PWM CH2 is NOT masked (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("3.3.6");
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------      
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.4");
      tfy_wr_step( report_file, now, "3.4",
         "Configure PWM Module with an offset of -15us - 5us"); 

      pwm_func_model_data_s  <= ( time_high_1 => 1.00 ms,
                                  time_high_2 => 1.00 ms,
                                  offset      => -20 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.1",
         "Check if PWM Compare module found an error (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(2) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.2",
         "Check if PWM CH1 error counter is '00000000000000' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "00000000000000",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.3",
         "Check if PWM CH1 is NOT masked (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '0',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.4",
         "Check if PWM CH2 error counter is '00000000000000' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "00000000000000",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.5",
         "Check if PWM CH2 is NOT masked (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '0',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.4.6");

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("3.4.7");
      WAIT FOR 1 ms;


      --==============
      -- Step 4
      --==============

      -- 80    A conflicting comparison where either PWM input stopped transitioning shall result in incrementing 
      --       of the PWM error counter.
      --       >> PWM Compare Module

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------------#");
      tfy_wr_step( report_file, now, "4",
         "Check PWM when one Input stops transitioning (REQ 80)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.1");
      tfy_wr_step( report_file, now, "4.1",
         "Disable the PWM CH1 (CH2 time high = 1ms)");

      pwm_func_model_data_s  <= ( time_high_1 => 0.0 ms,
                                  time_high_2 => 1.0 ms,
                                  offset      => 0 ns,
                                  on_off      => '1', 
                                  period_1    => 2.0 ms,
                                  period_2    => 2.0 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.1",
         "Check if PWM Compare module found an error (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(2) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.2",
         "Check if PWM CH1 error counter is '00000000000000' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "00000000000000",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.3",
         "Check if PWM CH1 is NOT masked (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '0',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.4",
         "Check if PWM CH2 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.5",
         "Check if PWM CH2 is NOT masked (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.1.6");

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("4.1.7");
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.2");
      tfy_wr_step( report_file, now, "4.2",
         "Disable the PWM CH2 (CH1 time high = 1ms)");

      pwm_func_model_data_s  <= ( time_high_1 => 1.0 ms,
                                  time_high_2 => 0.0 ms,
                                  offset      => 0 ns,
                                  on_off      => '1', 
                                  period_1    => 2.0 ms,
                                  period_2    => 2.0 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.1",
         "Check if PWM Compare module found an error (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(2) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.2",
         "Check if PWM CH1 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.3",
         "Check if PWM CH1 is NOT masked (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.4",
         "Check if PWM CH2 error counter is '00000000000000' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "00000000000000",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.5",
         "Check if PWM CH2 is NOT masked (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '0',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.2.6");

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("4.2.7");
      WAIT FOR 1 ms;


      --==============
      -- Step 5
      --==============

      -- 81    A conflicting comparison in the width of the transitions of both PWM inputs shall result in masking 
      --       of both PWM inputs since there is no reliable reference source, and incrementing both pwm error 
      --       counters. The admissible margin is 23.5us.
      --       >> PWM Compare Module

      -- System tolerance:    23.5us
      -- Sampling tolerance:  ~ +- 5us

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5: -------------------------------------------#");
      tfy_wr_step( report_file, now, "5",
         "Check PWM when channels 1 and 2 have different duty cycles (REQ 81)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.1");
      tfy_wr_step( report_file, now, "5.1",
         "Configure PWM Module for CH1-Width = 1.000ms and CH2-Width = 1.0235ms - 5us");

      pwm_func_model_data_s  <= ( time_high_1 => 1.000 ms,
                                  time_high_2 => 1.0185 ms, 
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.0 ms,
                                  period_2    => 2.0 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.1",
         "Check if PWM Compare module found an error (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(2) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.2",
         "Check if PWM CH1 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.3",
         "Check if PWM CH1 is NOT masked (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.4",
         "Check if PWM CH2 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.5",
         "Check if PWM CH2 is NOT masked (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("5.1.6");
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.2");
      tfy_wr_step( report_file, now, "5.2",
         "Configure PWM Module for CH1-Width = 1.000ms and CH2-Width = 1.0235ms + 5us");

      pwm_func_model_data_s  <= ( time_high_1 => 1.000 ms,
                                  time_high_2 => 1.0285 ms, 
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.0 ms,
                                  period_2    => 2.0 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.1",
         "Check if PWM Compare module found an error (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(2) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.2",
         "Check if PWM CH1 error counter is '00000000000000' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "00000000000000",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.3",
         "Check if PWM CH1 is NOT masked (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '0',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.4",
         "Check if PWM CH2 error counter is '00000000000000' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "00000000000000",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.5",
         "Check if PWM CH2 is NOT masked (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '0',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.2.6");

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("5.2.7");
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.3");
      tfy_wr_step( report_file, now, "5.3",
         "Configure PWM Module for CH1-Width = 1.0235ms - 5us and CH2-Width = 1.000ms");

      pwm_func_model_data_s  <= ( time_high_1 => 1.0185 ms,
                                  time_high_2 => 1.000 ms, 
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.0 ms,
                                  period_2    => 2.0 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.1",
         "Check if PWM Compare module found an error (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(2) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.2",
         "Check if PWM CH1 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.3",
         "Check if PWM CH1 is NOT masked (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.4",
         "Check if PWM CH2 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.5",
         "Check if PWM CH2 is NOT masked (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("5.3.6");
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.4");
      tfy_wr_step( report_file, now, "5.4",
         "Configure PWM Module for CH1-Width = 1.0235ms + 5us and CH2-Width = 1.000ms");

      pwm_func_model_data_s  <= ( time_high_1 => 1.0285 ms,
                                  time_high_2 => 1.000 ms, 
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.0 ms,
                                  period_2    => 2.0 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.1",
         "Check if PWM Compare module found an error (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(2) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.2",
         "Check if PWM CH1 error counter is '00000000000000' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "00000000000000",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.3",
         "Check if PWM CH1 is NOT masked (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '0',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.4",
         "Check if PWM CH2 error counter is '00000000000000' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "00000000000000",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.5",
         "Check if PWM CH2 is NOT masked (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '0',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.4.6");

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("5.4.7");
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.5");
      tfy_wr_step( report_file, now, "5.5",
         "Force a fault due to transitions width when there is a valid offset (code coverage)");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5.1",
         "Configure PWM Module for CH1-Width = 1.0235ms + 5us and CH2-Width = 1.000ms with an valid offset of -10us");

      pwm_func_model_data_s  <= ( time_high_1 => 1.0285 ms,
                                  time_high_2 => 1.000 ms, 
                                  offset      => -10 us,
                                  on_off      => '1', 
                                  period_1    => 2.0 ms,
                                  period_2    => 2.0 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5.2",
         "Check if PWM Compare module found an error (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(2) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.5.3");

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("5.5.4");
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5.5",
         "Configure PWM Module for CH1-Width = 1.000ms + 5us and CH2-Width = 1.0235ms with an valid offset of +10us");

      pwm_func_model_data_s  <= ( time_high_1 => 1.000 ms,
                                  time_high_2 => 1.0285 ms, 
                                  offset      => +10 us,
                                  on_off      => '1', 
                                  period_1    => 2.0 ms,
                                  period_2    => 2.0 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5.6",
         "Check if PWM Compare module found an error (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(2) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.5.7");

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("5.5.8");
      WAIT FOR 1 ms;


      --==============
      -- Step 6
      --==============

      -- 37    If no comparison errors are detected between the two PWM inputs, the Duty-Cycle thresholds for the 
      --       operations modes shall be as follows:
      -- 37.01 (0-5%):           Invalid
      -- 37.08 (95%-100%) :      Invalid
      --
      -- NOTE: All thresholds should account a tolerance of +-0.3% to account for precision losses due to digitization.

      -- 82    The invalid ranges shall result in the corresponding error counter being incremented.

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6: -------------------------------------------#");
      tfy_wr_step( report_file, now, "6",
         "Check the PWM duty cycle limits (REQ 82)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6.1");
      tfy_wr_step( report_file, now, "6.1",
         "Configure PWM Module with duty cycle greater than 5%");

      pwm_func_model_data_s  <= ( time_high_1 => 0.106 ms,   -- 5.3%
                                  time_high_2 => 0.106 ms,   -- 5.3%
                                  offset      => 0 ns,
                                  on_off      => '1', 
                                  period_1    => 2.000 ms,
                                  period_2    => 2.000 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1.1",
         "Check if PWM Compare module found an error (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(2) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1.2",
         "Check if PWM Capture module found an error on CH1 (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(0) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1.3",
         "Check if PWM Interpret DC Value Module found an invalid DC level on CH1 (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(3) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1.4",
         "Check if PWM CH1 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1.5",
         "Check if PWM CH1 is NOT masked (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      ---------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1.6",
         "Check if PWM Capture module found an error on CH2 (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1.7",
         "Check if PWM Interpret DC Value Module found an invalid DC level on CH2 (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(4) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1.8",
         "Check if PWM CH2 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1.9",
         "Check if PWM CH2 is NOT masked (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("6.1.10");
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6.2");
      tfy_wr_step( report_file, now, "6.2",
         "Configure PWM Module with duty cycle less than 5%");

      pwm_func_model_data_s  <= ( time_high_1 => 0.094 ms,   -- 4.7%
                                  time_high_2 => 0.094 ms,   -- 4.7%
                                  offset      => 0 ns,
                                  on_off      => '1', 
                                  period_1    => 2.000 ms,
                                  period_2    => 2.000 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2.1",
         "Check if PWM Compare module found an error (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(2) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2.2",
         "Check if PWM Capture module found an error on CH1 (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(0) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2.3",
         "Check if PWM Interpret DC Value Module found an invalid DC level on CH1 (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(3) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2.4",
         "Check if PWM CH1 error counter is '00000000000000' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "00000000000000",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2.5",
         "Check if PWM CH1 is NOT masked (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '0',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      ---------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2.6",
         "Check if PWM Capture module found an error on CH2 (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2.7",
         "Check if PWM Interpret DC Value Module found an invalid DC level on CH2 (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(4) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2.8",
         "Check if PWM CH2 error counter is '00000000000000' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "00000000000000",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2.9",
         "Check if PWM CH2 is NOT masked (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '0',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("6.2.10");

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("6.2.11");
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6.3");
      tfy_wr_step( report_file, now, "6.3",
         "Configure PWM Module with duty cycle less than 95%");

      pwm_func_model_data_s  <= ( time_high_1 => 1.894 ms,   -- 94.7%
                                  time_high_2 => 1.894 ms,   -- 94.7%
                                  offset      => 0 ns,
                                  on_off      => '1', 
                                  period_1    => 2.000 ms,
                                  period_2    => 2.000 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.1",
         "Check if PWM Compare module found an error (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(2) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.2",
         "Check if PWM Capture module found an error on CH1 (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(0) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.3",
         "Check if PWM Interpret DC Value Module found an invalid DC level on CH1 (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(3) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.4",
         "Check if PWM CH1 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.5",
         "Check if PWM CH1 is NOT masked (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      ---------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.6",
         "Check if PWM Capture module found an error on CH2 (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.7",
         "Check if PWM Interpret DC Value Module found an invalid DC level on CH2 (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(4) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.8",
         "Check if PWM CH2 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.9",
         "Check if PWM CH2 is NOT masked (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("6.3.10");
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6.4");
      tfy_wr_step( report_file, now, "6.4",
         "Configure PWM Module with duty cycle greater than 95%");

      pwm_func_model_data_s  <= ( time_high_1 => 1.906 ms,   -- 95.3%
                                  time_high_2 => 1.906 ms,   -- 95.3%
                                  offset      => 0 ns,
                                  on_off      => '1', 
                                  period_1    => 2.000 ms,
                                  period_2    => 2.000 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4.1",
         "Check if PWM Compare module found an error (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(2) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4.2",
         "Check if PWM Capture module found an error on CH1 (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(0) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4.3",
         "Check if PWM Interpret DC Value Module found an invalid DC level on CH1 (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(3) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4.4",
         "Check if PWM CH1 error counter is '00000000000000' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "00000000000000",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4.5",
         "Check if PWM CH1 is NOT masked (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '0',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      ---------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4.6",
         "Check if PWM Capture module found an error on CH2 (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4.7",
         "Check if PWM Interpret DC Value Module found an invalid DC level on CH2 (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_pwm_event_latch_r(4) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4.8",
         "Check if PWM CH2 error counter is '00000000000000' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "00000000000000",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4.9",
         "Check if PWM CH2 is NOT masked (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '0',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '0',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("6.4.10");

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("6.4.11");
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
         tc_name        => "TC_RS034_035_080_081_191_082",
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

END ARCHITECTURE TC_RS034_035_080_081_191_082;

