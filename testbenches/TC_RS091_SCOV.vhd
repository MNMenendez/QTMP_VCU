-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS091_SCOV
-- Module      : VCU Timing System
-- Revision    : 1.0
-- Date        : 04 Feb 2020
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Check speed limit function behavior as per scenario (Coverage)
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-91
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 04 Feb 2020
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- Notes:
--
-- sim -tc TC_RS091_SCOV -numstdoff -nocov
-- log -r /*
--
-- 91    The speed limit function shall behave according to drawing 4044 3101 r2.
--
-- 195   The speed limit status output shall be asserted in accordance with drawing 4044 3101 r2
--
--
-- SCOV – Increase code coverage for speed_limiter.vhd
--
--      2.1: Set Trip Cock Signal (spd_lim_chX_i) to '1'
--      2.2: Set Trip Cock Signal (spd_lim_chX_i) to '0'
--      2.3: Set Zero Speed Signal (zero_spd_chX_i) to '1'
--      2.4: Set Trip Cock Signal (spd_lim_chX_i) to '1'
--      2.5: Set Trip Cock Signal (spd_lim_chX_i) to '0'
--      2.6: Zero Speed Signal (zero_spd_chX_i) to '0'
--
-- Speed Limit Timer Period   500s 
-- Override Masking Period    30s 
--
-- Aditional notes: 
-- ----------------------
-- minor_flt_report_s         <= tms_minor_fault_o AND disp_minor_fault_o;
-- major_flt_report_s         <= tms_major_fault_o AND disp_major_fault_o;
--
-- spd_lim_timer_status_s     <= tms_spd_lim_stat_o;
-- spd_lim_exceeded_s         <= NOT (rly_out2_3V_o AND rly_out3_3V_o);
-- spd_lim_overridden_s       <= tms_spd_lim_overridden_o;
--
-- A change in signal 'Analog Speed' may cause an IMMEDIATE change in signal 'Speed Limit Exceeded'
--
-----------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;

ARCHITECTURE TC_RS091_SCOV OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------
   CONSTANT C_SPEED_LIMIT_TIME    : TIME := 500 sec; -- 500sec on 4044 3101 r2 [speed_limiter.vhd -> C_SPEED_LIMITER_TIMEOUT]
   CONSTANT C_OVERRIDE_TIME       : TIME := 30 sec;
   
   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------

   SIGNAL x_pulse500ms_s                          : STD_LOGIC;      -- Internal 500ms synch pulse

   --------------------------------------------------------
   -- User Signals
   --------------------------------------------------------
   SIGNAL s_usr_sigout_s                          : tfy_user_out;
   SIGNAL s_usr_sigin_s                           : tfy_user_in;
   SIGNAL pwm_func_model_data_s                   : pwm_func_model_inputs := C_PWM_FUNC_MODEL_INPUTS_INIT;   
   SIGNAL st_ch1_in_ctrl_s                        : ST_BEHAVIOR_CH1;
   SIGNAL st_ch2_in_ctrl_s                        : ST_BEHAVIOR_CH2;

   SIGNAL minor_flt_report_s                      : STD_LOGIC := '0';
   SIGNAL major_flt_report_s                      : STD_LOGIC := '0';

   SIGNAL spd_lim_timer_status_s                  : STD_LOGIC := '0';
   SIGNAL spd_lim_exceeded_s                      : STD_LOGIC := '0';
   SIGNAL spd_lim_overridden_s                    : STD_LOGIC := '0';

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
         report_fname   => "TC_RS091_SCOV.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS091_SCOV",
         test_module    => "VCU Timing System",
         tc_revision    => "1.0",
         tc_date        => "04 Feb 2020",
         tester_name    => "CABelchior",
         tc_description => "Check speed limit function behavior as per scenario (Coverage)",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_top_tb",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s
      );   

      --------------------------------------------------------
      -- Link Spy Probes
      --------------------------------------------------------
      init_signal_spy("/hcmt_cpld_top_tb/UUT/pulse500ms_s", "x_pulse500ms_s", 0);

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
         "Verify the 25km/h Vigilance System when speed limit function IS active - scenario 3"); 

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "Set Trip Cock Signal (spd_lim_chX_i) to '1', and wait at least 160ms"); -- input filtering

      uut_in.spd_lim_ch1_s <= '1';
      uut_in.spd_lim_ch2_s <= '1';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.1",
         "Check the status of Speed Limit related outputs (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => spd_lim_timer_status_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2",
         "Set Trip Cock Signal (spd_lim_chX_i) to '0', and wait at least 160ms"); -- input filtering

      uut_in.spd_lim_ch1_s <= '0';
      uut_in.spd_lim_ch2_s <= '0';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.1",
         "Check the status of Speed Limit related outputs (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => spd_lim_timer_status_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3",
         "Set Zero Speed Signal (zero_spd_chX_i) to '1', and wait at least 160ms"); -- input filtering

      uut_in.zero_spd_ch1_s <= '1';
      uut_in.zero_spd_ch2_s <= '1';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.1",
         "Check the status of Speed Limit related outputs (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => spd_lim_timer_status_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4",
         "Set Trip Cock Signal (spd_lim_chX_i) to '1', and wait at least 160ms"); -- input filtering

      uut_in.spd_lim_ch1_s <= '1';
      uut_in.spd_lim_ch2_s <= '1';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.1",
         "Check the status of Speed Limit related outputs (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => spd_lim_timer_status_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5",
         "Set Trip Cock Signal (spd_lim_chX_i) to '0', and wait at least 160ms"); -- input filtering

      uut_in.spd_lim_ch1_s <= '0';
      uut_in.spd_lim_ch2_s <= '0';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.1",
         "Check the status of Speed Limit related outputs (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => spd_lim_timer_status_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.6",
         "Set Zero Speed Signal (zero_spd_chX_i) to '0', and wait for the rising edge of 'spd_lim_timer_status_s'");

      uut_in.zero_spd_ch1_s <= '0';
      uut_in.zero_spd_ch2_s <= '0';
      WAIT UNTIL rising_edge(spd_lim_timer_status_s) FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.6.1",
         "Check the status of Speed Limit related outputs (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => spd_lim_timer_status_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);



      --------------------------------------------------------
      -- END
      --------------------------------------------------------
      WAIT FOR 20 ms;
      --------------------------------------------------------
      -- Testcase End Sequence
      --------------------------------------------------------

      tfy_tc_end(
         tc_pass        => pass,
         report_file    => report_file,
         tc_name        => "TC_RS091_SCOV",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "04 Feb 2020",
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
   major_flt_report_s         <= uut_out.tms_major_fault_s AND uut_out.disp_major_fault_s;

   spd_lim_timer_status_s     <= uut_out.tms_spd_lim_stat_s;
   spd_lim_exceeded_s         <= NOT (uut_out.rly_out2_3V_s AND uut_out.rly_out3_3V_s);
   spd_lim_overridden_s       <= uut_out.tms_spd_lim_overridden_s;

END ARCHITECTURE TC_RS091_SCOV;
