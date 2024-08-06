-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS037_085
-- Module      : Input IF
-- Revision    : 2.0
-- Date        : 09 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Verify the interpretation of PWM Duty-Cycle thresholds
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-37
--    FPGA-REQ-85
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
-- sim -tc TC_RS037_085 -nocov -numstdoff
-- log -r /*
--
-- 37	    If no comparison errors are detected between the two PWM inputs, the Duty-Cycle thresholds for the 
--          operations modes shall be as follows:
-- 37.01    (0-5%): Invalid
-- 37.02    (5%-10%) : Emergency Brake
-- 37.03	(10%-18.89%) : Maximum Brake
-- 37.04	(43.33%) : Minimum Brake
-- 37.05	(43.33%-56.67%) : Off (Coast)
-- 37.06	(56.67%) : Minimum Power
-- 37.07	(90%-95%) : Maximum Power
-- 37.08	(95%-100%) : Invalid
--
-- 85    The Master Controller is in a 'No Power' position if the PWM DC is less than 56.67% except if the 
--       DC range is invalid.
--
-- NOTE: All thresholds should account a tolerance of +-0.3% to account for precision losses due to digitization.
--
-- NOTE: Implementation should consider a fixed PWM frequency of 500Hz for determining all related thresholds.
--
-- NOTE: Master Controller can be interchangeably defined as 'MC'.
-- 

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;
USE WORK.txt_util_p.ALL;

ARCHITECTURE TC_RS037_085 OF hcmt_cpld_tc_top IS

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

   -- PWM Interpret DC Value Module u0
   SIGNAL x_dc_inv_s_u0                           : STD_LOGIC;
   SIGNAL x_embrk_s_u0                            : STD_LOGIC;
   SIGNAL x_mxbrk_s_u0                            : STD_LOGIC;
   SIGNAL x_mnbrk_s_u0                            : STD_LOGIC;
   SIGNAL x_offcoast_s_u0                         : STD_LOGIC;

   SIGNAL x_pwm_duty_o_u0                         : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL x_pwm_duty_valid_o_u0                   : STD_LOGIC;


   -- PWM Interpret DC Value Module u1
   SIGNAL x_dc_inv_s_u1                           : STD_LOGIC;
   SIGNAL x_embrk_s_u1                            : STD_LOGIC;
   SIGNAL x_mxbrk_s_u1                            : STD_LOGIC;
   SIGNAL x_mnbrk_s_u1                            : STD_LOGIC;
   SIGNAL x_offcoast_s_u1                         : STD_LOGIC;

   SIGNAL x_pwm_duty_o_u1                         : STD_LOGIC_VECTOR(9 DOWNTO 0);   
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
   SIGNAL event_pwm_event_latch_r                 : STD_LOGIC_VECTOR(1 DOWNTO 0) := (OTHERS => '0');
  
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
         report_fname   => "TC_RS037_085.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS037_085",
         test_module    => "Input IF",
         tc_revision    => "2.0",
         tc_date        => "09 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Verify the interpretation of PWM Duty-Cycle thresholds",
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

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u0/dc_inv_s",   "x_dc_inv_s_u0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u0/embrk_s",    "x_embrk_s_u0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u0/mxbrk_s",    "x_mxbrk_s_u0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u0/mnbrk_s",    "x_mnbrk_s_u0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u0/offcoast_s", "x_offcoast_s_u0", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u0/pwm_duty_o",       "x_pwm_duty_o_u0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u0/pwm_duty_valid_o", "x_pwm_duty_valid_o_u0", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u1/dc_inv_s",   "x_dc_inv_s_u1", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u1/embrk_s",    "x_embrk_s_u1", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u1/mxbrk_s",    "x_mxbrk_s_u1", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u1/mnbrk_s",    "x_mnbrk_s_u1", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u1/offcoast_s", "x_offcoast_s_u1", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u1/pwm_duty_o",       "x_pwm_duty_o_u1", 0);
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
         "Verify the interpretation of PWM signal with a Duty-Cycle equal to 5.00% - 0.3%");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "Configure PWM Module with a Duty-Cycle equal to 5.00% - 0.3%");         

      pwm_func_model_data_s  <= ( time_high_1 => 2.00 ms * ( (5.00-0.3) / 100.0 ),
                                  time_high_2 => 2.00 ms * ( (5.00-0.3) / 100.0 ),
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);
      
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2",
         "Check if MC is in a 'No Power' condition (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.3"); 
      tfy_wr_step( report_file, now, "2.3",
         "Verify the internal PWM operations modes flags");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.1",
         "Check if the 'Invalid' flag of both PWM channels are equal to '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => (x_dc_inv_s_u0 AND x_dc_inv_s_u1)     = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.2",
         "Check if the 'Emergency Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_embrk_s_u0 AND x_embrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.3",
         "Check if the 'Maximum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mxbrk_s_u0 AND x_mxbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.4",
         "Check if the 'Minimum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mnbrk_s_u0 AND x_mnbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.5",
         "Check if the 'Off (Coast)' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_offcoast_s_u0 AND x_offcoast_s_u1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "Verify the interpretation of PWM signal with a Duty-Cycle equal to 5.00% + 0.3%");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1",
         "Configure PWM Module with a Duty-Cycle equal to 5.00% + 0.3%");         

      pwm_func_model_data_s  <= ( time_high_1 => 2.00 ms * ( (5.00+0.3) / 100.0 ),
                                  time_high_2 => 2.00 ms * ( (5.00+0.3) / 100.0 ),
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);
      
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2",
         "Check if MC is in a 'No Power' condition (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.3"); 
      tfy_wr_step( report_file, now, "3.3",
         "Verify the internal PWM operations modes flags");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.1",
         "Check if the 'Invalid' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_dc_inv_s_u0 AND x_dc_inv_s_u1)     = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.2",
         "Check if the 'Emergency Brake' flag of both PWM channels are equal to '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => (x_embrk_s_u0 AND x_embrk_s_u1)       = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.3",
         "Check if the 'Maximum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mxbrk_s_u0 AND x_mxbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.4",
         "Check if the 'Minimum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mnbrk_s_u0 AND x_mnbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.5",
         "Check if the 'Off (Coast)' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_offcoast_s_u0 AND x_offcoast_s_u1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      --==============
      -- Step 4
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------------#");
      tfy_wr_step( report_file, now, "4",
         "Verify the interpretation of PWM signal with a Duty-Cycle equal to 10.00% - 0.3%");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1",
         "Configure PWM Module with a Duty-Cycle equal to 10.00% - 0.3%");         

      pwm_func_model_data_s  <= ( time_high_1 => 2.00 ms * ( (10.00-0.3) / 100.0 ),
                                  time_high_2 => 2.00 ms * ( (10.00-0.3) / 100.0 ),
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);
      
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2",
         "Check if MC is in a 'No Power' condition (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.3"); 
      tfy_wr_step( report_file, now, "4.3",
         "Verify the internal PWM operations modes flags");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.1",
         "Check if the 'Invalid' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_dc_inv_s_u0 AND x_dc_inv_s_u1)     = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.2",
         "Check if the 'Emergency Brake' flag of both PWM channels are equal to '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => (x_embrk_s_u0 AND x_embrk_s_u1)       = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.3",
         "Check if the 'Maximum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mxbrk_s_u0 AND x_mxbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.4",
         "Check if the 'Minimum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mnbrk_s_u0 AND x_mnbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.5",
         "Check if the 'Off (Coast)' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_offcoast_s_u0 AND x_offcoast_s_u1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      --==============
      -- Step 5
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5: -------------------------------------------#");
      tfy_wr_step( report_file, now, "5",
         "Verify the interpretation of PWM signal with a Duty-Cycle equal to 10.00% + 0.3%");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1",
         "Configure PWM Module with a Duty-Cycle equal to 10.00% + 0.3%");         

      pwm_func_model_data_s  <= ( time_high_1 => 2.00 ms * ( (10.00+0.3) / 100.0 ),
                                  time_high_2 => 2.00 ms * ( (10.00+0.3) / 100.0 ),
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);
      
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2",
         "Check if MC is in a 'No Power' condition (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.3"); 
      tfy_wr_step( report_file, now, "5.3",
         "Verify the internal PWM operations modes flags");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.1",
         "Check if the 'Invalid' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_dc_inv_s_u0 AND x_dc_inv_s_u1)     = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.2",
         "Check if the 'Emergency Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_embrk_s_u0 AND x_embrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.3",
         "Check if the 'Maximum Brake' flag of both PWM channels are equal to '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => (x_mxbrk_s_u0 AND x_mxbrk_s_u1)       = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.4",
         "Check if the 'Minimum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mnbrk_s_u0 AND x_mnbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.5",
         "Check if the 'Off (Coast)' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_offcoast_s_u0 AND x_offcoast_s_u1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      --==============
      -- Step 6
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6: -------------------------------------------#");
      tfy_wr_step( report_file, now, "6",
         "Verify the interpretation of PWM signal with a Duty-Cycle equal to 18.89% - 0.3%");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1",
         "Configure PWM Module with a Duty-Cycle equal to 18.89% - 0.3%");         

      pwm_func_model_data_s  <= ( time_high_1 => 2.00 ms * ( (18.89-0.3) / 100.0 ),
                                  time_high_2 => 2.00 ms * ( (18.89-0.3) / 100.0 ),
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);
      
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2",
         "Check if MC is in a 'No Power' condition (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6.3"); 
      tfy_wr_step( report_file, now, "6.3",
         "Verify the internal PWM operations modes flags");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.1",
         "Check if the 'Invalid' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_dc_inv_s_u0 AND x_dc_inv_s_u1)     = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.2",
         "Check if the 'Emergency Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_embrk_s_u0 AND x_embrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.3",
         "Check if the 'Maximum Brake' flag of both PWM channels are equal to '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => (x_mxbrk_s_u0 AND x_mxbrk_s_u1)       = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.4",
         "Check if the 'Minimum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mnbrk_s_u0 AND x_mnbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.5",
         "Check if the 'Off (Coast)' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_offcoast_s_u0 AND x_offcoast_s_u1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      --==============
      -- Step 7
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 7: -------------------------------------------#");
      tfy_wr_step( report_file, now, "7",
         "Verify the interpretation of PWM signal with a Duty-Cycle equal to 18.89% + 0.3%");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.1",
         "Configure PWM Module with a Duty-Cycle equal to 18.89% + 0.3%");         

      pwm_func_model_data_s  <= ( time_high_1 => 2.00 ms * ( (18.89+0.3) / 100.0 ),
                                  time_high_2 => 2.00 ms * ( (18.89+0.3) / 100.0 ),
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);
      
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.2",
         "Check if MC is in a 'No Power' condition (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 7.3"); 
      tfy_wr_step( report_file, now, "7.3",
         "Verify the internal PWM operations modes flags");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.3.1",
         "Check if the 'Invalid' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_dc_inv_s_u0 AND x_dc_inv_s_u1)     = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.3.2",
         "Check if the 'Emergency Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_embrk_s_u0 AND x_embrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.3.3",
         "Check if the 'Maximum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mxbrk_s_u0 AND x_mxbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.3.4",
         "Check if the 'Minimum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mnbrk_s_u0 AND x_mnbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.3.5",
         "Check if the 'Off (Coast)' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_offcoast_s_u0 AND x_offcoast_s_u1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      --==============
      -- Step 8
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 8: -------------------------------------------#");
      tfy_wr_step( report_file, now, "8",
         "Verify the interpretation of PWM signal with a Duty-Cycle equal to 43.33% - 0.3%");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.1",
         "Configure PWM Module with a Duty-Cycle equal to 43.33% - 0.3%");         

      pwm_func_model_data_s  <= ( time_high_1 => 2.00 ms * ( (43.33-0.3) / 100.0 ),
                                  time_high_2 => 2.00 ms * ( (43.33-0.3) / 100.0 ),
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);
      
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.2",
         "Check if MC is in a 'No Power' condition (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 8.3"); 
      tfy_wr_step( report_file, now, "8.3",
         "Verify the internal PWM operations modes flags");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.3.1",
         "Check if the 'Invalid' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_dc_inv_s_u0 AND x_dc_inv_s_u1)     = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.3.2",
         "Check if the 'Emergency Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_embrk_s_u0 AND x_embrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.3.3",
         "Check if the 'Maximum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mxbrk_s_u0 AND x_mxbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.3.4",
         "Check if the 'Minimum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mnbrk_s_u0 AND x_mnbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.3.5",
         "Check if the 'Off (Coast)' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_offcoast_s_u0 AND x_offcoast_s_u1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      --==============
      -- Step 9
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 9: -------------------------------------------#");
      tfy_wr_step( report_file, now, "9",
         "Verify the interpretation of PWM signal with a Duty-Cycle equal to 43.33%");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.1",
         "Configure PWM Module with a Duty-Cycle equal to 43.33%");         

      pwm_func_model_data_s  <= ( time_high_1 => 2.00 ms * ( (43.33) / 100.0 ),
                                  time_high_2 => 2.00 ms * ( (43.33) / 100.0 ),
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);
      
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.2",
         "Check if MC is in a 'No Power' condition (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 9.3"); 
      tfy_wr_step( report_file, now, "9.3",
         "Verify the internal PWM operations modes flags");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.3.1",
         "Check if the 'Invalid' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_dc_inv_s_u0 AND x_dc_inv_s_u1)     = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.3.2",
         "Check if the 'Emergency Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_embrk_s_u0 AND x_embrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.3.3",
         "Check if the 'Maximum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mxbrk_s_u0 AND x_mxbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.3.4",
         "Check if the 'Minimum Brake' flag of both PWM channels are equal to '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => (x_mnbrk_s_u0 AND x_mnbrk_s_u1)       = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.3.5",
         "Check if the 'Off (Coast)' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_offcoast_s_u0 AND x_offcoast_s_u1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      --==============
      -- Step 10
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 10: -------------------------------------------#");
      tfy_wr_step( report_file, now, "10",
         "Verify the interpretation of PWM signal with a Duty-Cycle equal to 43.33% + 0.3%");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.1",
         "Configure PWM Module with a Duty-Cycle equal to 43.33% + 0.3%");         

      pwm_func_model_data_s  <= ( time_high_1 => 2.00 ms * ( (43.33+0.3) / 100.0 ),
                                  time_high_2 => 2.00 ms * ( (43.33+0.3) / 100.0 ),
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);
      
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.2",
         "Check if MC is in a 'No Power' condition (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 10.3"); 
      tfy_wr_step( report_file, now, "10.3",
         "Verify the internal PWM operations modes flags");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.3.1",
         "Check if the 'Invalid' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_dc_inv_s_u0 AND x_dc_inv_s_u1)     = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.3.2",
         "Check if the 'Emergency Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_embrk_s_u0 AND x_embrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.3.3",
         "Check if the 'Maximum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mxbrk_s_u0 AND x_mxbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.3.4",
         "Check if the 'Minimum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mnbrk_s_u0 AND x_mnbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.3.5",
         "Check if the 'Off (Coast)' flag of both PWM channels are equal to '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => (x_offcoast_s_u0 AND x_offcoast_s_u1) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      --==============
      -- Step 11
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 11: -------------------------------------------#");
      tfy_wr_step( report_file, now, "11",
         "Verify the interpretation of PWM signal with a Duty-Cycle equal to 56.67% - 0.3%");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.1",
         "Configure PWM Module with a Duty-Cycle equal to 56.67% - 0.3%");         

      pwm_func_model_data_s  <= ( time_high_1 => 2.00 ms * ( (56.67-0.3) / 100.0 ),
                                  time_high_2 => 2.00 ms * ( (56.67-0.3) / 100.0 ),
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);
      
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.2",
         "Check if MC is in a 'No Power' condition (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 11.3"); 
      tfy_wr_step( report_file, now, "11.3",
         "Verify the internal PWM operations modes flags");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.3.1",
         "Check if the 'Invalid' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_dc_inv_s_u0 AND x_dc_inv_s_u1)     = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.3.2",
         "Check if the 'Emergency Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_embrk_s_u0 AND x_embrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.3.3",
         "Check if the 'Maximum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mxbrk_s_u0 AND x_mxbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.3.4",
         "Check if the 'Minimum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mnbrk_s_u0 AND x_mnbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.3.5",
         "Check if the 'Off (Coast)' flag of both PWM channels are equal to '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => (x_offcoast_s_u0 AND x_offcoast_s_u1) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      --==============
      -- Step 12
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 12: -------------------------------------------#");
      tfy_wr_step( report_file, now, "12",
         "Verify the interpretation of PWM signal with a Duty-Cycle equal to 56.67%");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.1",
         "Configure PWM Module with a Duty-Cycle equal to 56.67%");         

      pwm_func_model_data_s  <= ( time_high_1 => 2.00 ms * ( (56.67) / 100.0 ),
                                  time_high_2 => 2.00 ms * ( (56.67) / 100.0 ),
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);
      
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.2",
         "Check if MC is in a 'No Power' condition (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 12.3"); 
      tfy_wr_step( report_file, now, "12.3",
         "Verify the internal PWM operations modes flags");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.3.1",
         "Check if the 'Invalid' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_dc_inv_s_u0 AND x_dc_inv_s_u1)     = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.3.2",
         "Check if the 'Emergency Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_embrk_s_u0 AND x_embrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.3.3",
         "Check if the 'Maximum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mxbrk_s_u0 AND x_mxbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.3.4",
         "Check if the 'Minimum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mnbrk_s_u0 AND x_mnbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.3.5",
         "Check if the 'Off (Coast)' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_offcoast_s_u0 AND x_offcoast_s_u1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      --==============
      -- Step 13
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 13: -------------------------------------------#");
      tfy_wr_step( report_file, now, "13",
         "Verify the interpretation of PWM signal with a Duty-Cycle equal to 56.67% + 0.3%");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.1",
         "Configure PWM Module with a Duty-Cycle equal to 56.67% + 0.3%");         

      pwm_func_model_data_s  <= ( time_high_1 => 2.00 ms * ( (56.67+0.3) / 100.0 ),
                                  time_high_2 => 2.00 ms * ( (56.67+0.3) / 100.0 ),
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);
      
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.2",
         "Check if MC is in a 'No Power' condition (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 13.3"); 
      tfy_wr_step( report_file, now, "13.3",
         "Verify the internal PWM operations modes flags");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.3.1",
         "Check if the 'Invalid' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_dc_inv_s_u0 AND x_dc_inv_s_u1)     = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.3.2",
         "Check if the 'Emergency Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_embrk_s_u0 AND x_embrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.3.3",
         "Check if the 'Maximum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mxbrk_s_u0 AND x_mxbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.3.4",
         "Check if the 'Minimum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mnbrk_s_u0 AND x_mnbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.3.5",
         "Check if the 'Off (Coast)' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_offcoast_s_u0 AND x_offcoast_s_u1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      --==============
      -- Step 14
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 14: -------------------------------------------#");
      tfy_wr_step( report_file, now, "14",
         "Verify the interpretation of PWM signal with a Duty-Cycle equal to 90.00% - 0.3%");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.1",
         "Configure PWM Module with a Duty-Cycle equal to 90.00% - 0.3%");         

      pwm_func_model_data_s  <= ( time_high_1 => 2.00 ms * ( (90.00-0.3) / 100.0 ),
                                  time_high_2 => 2.00 ms * ( (90.00-0.3) / 100.0 ),
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);
      
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.2",
         "Check if MC is in a 'No Power' condition (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 14.3"); 
      tfy_wr_step( report_file, now, "14.3",
         "Verify the internal PWM operations modes flags");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.3.1",
         "Check if the 'Invalid' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_dc_inv_s_u0 AND x_dc_inv_s_u1)     = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.3.2",
         "Check if the 'Emergency Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_embrk_s_u0 AND x_embrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.3.3",
         "Check if the 'Maximum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mxbrk_s_u0 AND x_mxbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.3.4",
         "Check if the 'Minimum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mnbrk_s_u0 AND x_mnbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.3.5",
         "Check if the 'Off (Coast)' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_offcoast_s_u0 AND x_offcoast_s_u1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      --==============
      -- Step 15
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 15: -------------------------------------------#");
      tfy_wr_step( report_file, now, "15",
         "Verify the interpretation of PWM signal with a Duty-Cycle equal to 90.00% + 0.3%");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.1",
         "Configure PWM Module with a Duty-Cycle equal to 90.00% + 0.3%");         

      pwm_func_model_data_s  <= ( time_high_1 => 2.00 ms * ( (90.00+0.3) / 100.0 ),
                                  time_high_2 => 2.00 ms * ( (90.00+0.3) / 100.0 ),
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);
      
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.2",
         "Check if MC is in a 'No Power' condition (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 15.3"); 
      tfy_wr_step( report_file, now, "15.3",
         "Verify the internal PWM operations modes flags");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.3.1",
         "Check if the 'Invalid' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_dc_inv_s_u0 AND x_dc_inv_s_u1)     = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.3.2",
         "Check if the 'Emergency Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_embrk_s_u0 AND x_embrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.3.3",
         "Check if the 'Maximum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mxbrk_s_u0 AND x_mxbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.3.4",
         "Check if the 'Minimum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mnbrk_s_u0 AND x_mnbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.3.5",
         "Check if the 'Off (Coast)' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_offcoast_s_u0 AND x_offcoast_s_u1) = '1',
                 expected      => FALSE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      --==============
      -- Step 16
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 16: -------------------------------------------#");
      tfy_wr_step( report_file, now, "16",
         "Verify the interpretation of PWM signal with a Duty-Cycle equal to 95.00% - 0.3%");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "16.1",
         "Configure PWM Module with a Duty-Cycle equal to 95.00% - 0.3%");         

      pwm_func_model_data_s  <= ( time_high_1 => 2.00 ms * ( (95.00-0.3) / 100.0 ),
                                  time_high_2 => 2.00 ms * ( (95.00-0.3) / 100.0 ),
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);
      
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "16.2",
         "Check if MC is in a 'No Power' condition (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 16.3"); 
      tfy_wr_step( report_file, now, "16.3",
         "Verify the internal PWM operations modes flags");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "16.3.1",
         "Check if the 'Invalid' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_dc_inv_s_u0 AND x_dc_inv_s_u1)     = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "16.3.2",
         "Check if the 'Emergency Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_embrk_s_u0 AND x_embrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "16.3.3",
         "Check if the 'Maximum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mxbrk_s_u0 AND x_mxbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "16.3.4",
         "Check if the 'Minimum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mnbrk_s_u0 AND x_mnbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "16.3.5",
         "Check if the 'Off (Coast)' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_offcoast_s_u0 AND x_offcoast_s_u1) = '1',
                 expected      => FALSE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      --==============
      -- Step 17
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 17: -------------------------------------------#");
      tfy_wr_step( report_file, now, "17",
         "Verify the interpretation of PWM signal with a Duty-Cycle equal to 95.00% + 0.3%");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "17.1",
         "Configure PWM Module with a Duty-Cycle equal to 95.00% + 0.3%");         

      pwm_func_model_data_s  <= ( time_high_1 => 2.00 ms * ( (95.00+0.3) / 100.0 ),
                                  time_high_2 => 2.00 ms * ( (95.00+0.3) / 100.0 ),
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);
      
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "17.2",
         "Check if MC is in a 'No Power' condition (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 17.3"); 
      tfy_wr_step( report_file, now, "17.3",
         "Verify the internal PWM operations modes flags");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "17.3.1",
         "Check if the 'Invalid' flag of both PWM channels are equal to '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => (x_dc_inv_s_u0 AND x_dc_inv_s_u1)     = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "17.3.2",
         "Check if the 'Emergency Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_embrk_s_u0 AND x_embrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "17.3.3",
         "Check if the 'Maximum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mxbrk_s_u0 AND x_mxbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "17.3.4",
         "Check if the 'Minimum Brake' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_mnbrk_s_u0 AND x_mnbrk_s_u1)       = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "17.3.5",
         "Check if the 'Off (Coast)' flag of both PWM channels are equal to '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_offcoast_s_u0 AND x_offcoast_s_u1) = '1',
                 expected      => FALSE,        equality        => TRUE,
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
         tc_name        => "TC_RS037_085",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "09 Dec 2019",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s    
      );

   END PROCESS p_steps;

    p_event_latch: PROCESS(event_latch_rst_r, x_pwm_duty_valid_o_u0, x_pwm_duty_valid_o_u1)
    BEGIN
        IF rising_edge(event_latch_rst_r) THEN
            event_pwm_event_latch_r(0) <= '0';
            event_pwm_event_latch_r(1) <= '0';
        ELSE
            IF falling_edge(x_pwm_duty_valid_o_u0) THEN
                event_pwm_event_latch_r(0) <= '1';
            END IF;

            IF falling_edge(x_pwm_duty_valid_o_u1) THEN
                event_pwm_event_latch_r(1) <= '1';
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

END ARCHITECTURE TC_RS037_085;

