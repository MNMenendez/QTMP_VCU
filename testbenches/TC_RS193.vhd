-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS193
-- Module      : Input IF
-- Revision    : 2.0
-- Date        : 30 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Verify that a valid duty cycle measurement shall decrement the corresponding error counter 
--               if the PWM channel has not already been permanently masked.
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-193
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 06 Apr 2018
--    - CABelchior (1.0): Initial Release
-- Revision 1.1 - 29 Aug 2018
--    - CABelchior (1.1): CCN2
-- Revision 1.2 - 30 May 2019
--    - CABelchior (1.2): CCN3
-- Revision 2.0 - 30 Dec 2019
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
--
-- sim -tc TC_RS193 -nocov -numstdoff
-- log -r /*
--
-- 193   A duty cycle measurement that is valid according to requirements 37.01->37.08, i.e. not invalid, 
--       shall decrement the corresponding error counter if the PWM channel has not already been permanently 
--       masked. 


LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;
USE WORK.txt_util_p.ALL;

ARCHITECTURE TC_RS193 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Type Definitions
   --------------------------------------------------------

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------

   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------

   -- PWM Counter Error Module
   SIGNAL x_pwm_error_counter_u0                  : STD_LOGIC_VECTOR(13 DOWNTO 0);
   SIGNAL x_pwm_mask_o_u0                         : STD_LOGIC;
   SIGNAL x_pwm_fault_o_u0                        : STD_LOGIC;
   SIGNAL x_pwm_error_counter_u1                  : STD_LOGIC_VECTOR(13 DOWNTO 0);
   SIGNAL x_pwm_mask_o_u1                         : STD_LOGIC;
   SIGNAL x_pwm_fault_o_u1                        : STD_LOGIC;

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
      VARIABLE IDX: NATURAL;

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
         report_fname   => "TC_RS193.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS193",
         test_module    => "Input IF",
         tc_revision    => "2.0",
         tc_date        => "30 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Verify that a valid duty cycle measurement shall decrement the corresponding error counter",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_top_tb",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s
      );

      --------------------------------------------------------
      -- Link Spy Probes
      --------------------------------------------------------

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u0/pwm_counter_error_u/counter_r", "x_pwm_error_counter_u0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u0/pwm_counter_error_u/mask_o", "x_pwm_mask_o_u0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u0/pwm_counter_error_u/fault_o", "x_pwm_fault_o_u0", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u1/pwm_counter_error_u/counter_r", "x_pwm_error_counter_u1", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u1/pwm_counter_error_u/mask_o", "x_pwm_mask_o_u1", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm_dc_thr_u1/pwm_counter_error_u/fault_o", "x_pwm_fault_o_u1", 0);

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
         "Verify that a valid PWM duty cycle measurement shall decrement the corresponding error counter when the PWM channel has not already been permanently masked (REQ 193)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.1");
      tfy_wr_step( report_file, now, "2.1",
         "Set the PWM Module with a valid configuration for both channels"); 

      pwm_func_model_data_s  <= ( time_high_1 => 1.80 ms,
                                  time_high_2 => 1.80 ms,
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);

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

      pwm_func_model_data_s  <= ( time_high_1 => 1.80 ms,
                                  time_high_2 => 1.80 ms,
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.05 ms,
                                  period_2    => 2.05 ms);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.3");
      tfy_wr_step( report_file, now, "2.3",
         "Wait until the PWM error counter reached a number below its maximum"); 

      WAIT UNTIL x_pwm_error_counter_u0 = "00000000001111";

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.4");
      tfy_wr_step( report_file, now, "2.4",
         "Set the PWM Module with a valid configuration for both channels"); 

      pwm_func_model_data_s  <= ( time_high_1 => 1.80 ms,
                                  time_high_2 => 1.80 ms,
                                  offset      => 0 us,
                                  on_off      => '1', 
                                  period_1    => 2.00 ms,
                                  period_2    => 2.00 ms);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.5");
      tfy_wr_step( report_file, now, "2.5",
         "Wait enough time to the PWM error counter return to its minimum"); 

      WAIT UNTIL x_pwm_error_counter_u0 = "00000000000000";

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_PWM_CH1_BIT, '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PWM_CH2_BIT, '0', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PWM_GREEN_BIT,'1', led_code_i);
      Report_LED_IF  ("-", C_LED_PWM_RED_BIT,  '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("2.5.2", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.3",
         "Check if Master Controller is in 'No Power' position (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_o = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.4",
         "Check if PWM CH1 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u0 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.5",
         "Check if PWM CH1 is NOT masked and NOT faulted (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u0 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_pwm_fault_o_u0 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.6",
         "Check if PWM CH2 error counter is '00000000000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_error_counter_u1 = "00000000000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.7",
         "Check if PWM CH2 is NOT masked and NOT faulted (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_pwm_mask_o_u1 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_pwm_fault_o_u1 = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

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
         tc_name        => "TC_RS193",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "30 Dec 2019",
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

END ARCHITECTURE TC_RS193;

