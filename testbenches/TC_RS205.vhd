-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS205
-- Module      : Input IF
-- Revision    : 1.0
-- Date        : 10 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Check the pause capability of all PWM error counters due to cab active input signal
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-205
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 10 Dec 2019
--    - CABelchior (1.0): Initial Release (CCN04)
-----------------------------------------------------------------
--
-- sim -tc TC_RS205 -numstdoff -nocov
-- log -r /*
--
-- 205   When the cab active input signal is indicating that the cabin is INACTIVE, i.e. cab active signal 
--       logic '1', all PWM error counters shall be paused. No incrementing or decrementing shall be allowed 
--       in inactive mode. Note that the counters shall not be reset however and should maintain their value 
--       when entering and leaving inactive mode.
--
-- PWM tick -> ~3.91us
-----------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;
USE WORK.txt_util_p.ALL;

ARCHITECTURE TC_RS205 OF hcmt_cpld_tc_top IS

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

   -- Auxiliar register for PWM Counter Error
   SIGNAL pwm_error_counter_u0_r                  : STD_LOGIC_VECTOR(13 DOWNTO 0);
   SIGNAL pwm_error_counter_u1_r                  : STD_LOGIC_VECTOR(13 DOWNTO 0);

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
         report_fname   => "TC_RS205.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS205",
         test_module    => "Input IF",
         tc_revision    => "1.0",
         tc_date        => "10 Dec 2019",
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


      --==============
      -- Step 2
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2: -------------------------------------------#");
      tfy_wr_step( report_file, now, "2",
         "Force an error due to invalid period (REQ 34");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "Configure PWM Module with an invalid period for both channels"); 

      pwm_func_model_data_s  <= ( time_high_1 => 1.80 ms,
                                  time_high_2 => 1.80 ms,
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.05 ms,
                                  period_2    => 2.05 ms);

      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2",
         "Set the dual channel input cab_act_chX_i to '1'"); 

      uut_in.cab_act_ch1_s          <= '1';
      uut_in.cab_act_ch2_s          <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3",
         "Wait until OpMode change to inactive (OPMODE_SUPPRESSED)"); 

      WAIT UNTIL x_opmode_curst_r = OPMODE_SUPPRESSED;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4",
         "Grab the current PWM CH1 and CH2 error counter values");

      pwm_error_counter_u0_r <= x_pwm_error_counter_u0;
      pwm_error_counter_u1_r <= x_pwm_error_counter_u1;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5",
         "Wait for 100 ms"); 

      WAIT FOR 100 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.6",
         "Check if PWM CH1 and CH2 error counter values maintain their values when entering inactive mode. (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = pwm_error_counter_u0_r,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = pwm_error_counter_u1_r,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.7",
         "Set the dual channel input cab_act_chX_i to '0'"); 

      uut_in.cab_act_ch1_s          <= '0';
      uut_in.cab_act_ch2_s          <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.8",
         "Wait until OpMode change back to normal (OPMODE_NORMAL)"); 

      WAIT UNTIL x_opmode_curst_r = OPMODE_NORMAL;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.9",
         "Check if PWM CH1 and CH2 error counter values maintain their values when leaving inactive mode. (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = pwm_error_counter_u0_r,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = pwm_error_counter_u1_r,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.9",
         "Wait for 100 ms"); 

      WAIT FOR 100 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.10",
         "Check if PWM CH1 and CH2 error counter were resumed after leaving inactive mode. (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => (unsigned(x_pwm_error_counter_u0) > unsigned(pwm_error_counter_u0_r)),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

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
         tc_name        => "TC_RS205",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "10 Dec 2019",
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

END ARCHITECTURE TC_RS205;

