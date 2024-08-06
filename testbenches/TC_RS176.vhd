-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS176
-- Module      : Input IF
-- Revision    : 2.0
-- Date        : 04 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Tests the masking capabilities of the external self-test circuits
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-176
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 24 Fev 2018
--    - CABelchior (1.0): Initial Release
-- Revision 1.1 - 27 Apr 2019
--    - VSA (1.1): CCN03 changes
-- Revision 2.0 - 04 Dec 2019
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- Notes:
-- 
-- sim -tc TC_RS176 -numstdoff -nocov
-- log -r /*
--
--  176 Two dedicated inputs exist to signal a failure on CH1 and CH2 external self-test circuits. 
--      When each input is asserted, all of the input bits associated with that channel are masked.
--
--      ATTENTION: This two input signals are subjected to debouncing (x2) in the same fashion of the 
--      other digital inputs. @See SAS Figure 8
-----------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;
USE WORK.txt_util_p.ALL;

ARCHITECTURE TC_RS176 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Type Definitions
   --------------------------------------------------------

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------

   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------

   -- Self-Test fault outputs
   SIGNAL x_fault_st_ch1_s                        : STD_LOGIC_VECTOR(13 DOWNTO 0);
   SIGNAL x_fault_st_ch2_s                        : STD_LOGIC_VECTOR(8 DOWNTO 0);

   --------------------------------------------------------
   -- Drive Probes
   --------------------------------------------------------

   --------------------------------------------------------
   -- User Signals
   --------------------------------------------------------
   SIGNAL s_usr_sigout_s                          : tfy_user_out;
   SIGNAL s_usr_sigin_s                           : tfy_user_in;
   SIGNAL st_ch1_in_ctrl_s                        : ST_BEHAVIOR_CH1;
   SIGNAL st_ch2_in_ctrl_s                        : ST_BEHAVIOR_CH2;
   SIGNAL pwm_func_model_data_s                   : pwm_func_model_inputs := C_PWM_FUNC_MODEL_INPUTS_INIT;

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
         report_fname   => "TC_RS176.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS176",
         test_module    => "Input IF",
         tc_revision    => "2.0",
         tc_date        => "04 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Tests the masking capabilities of the external self-test circuits",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_top_tb",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s
      );

      --------------------------------------------------------
      -- Link Spy Probes
      --------------------------------------------------------
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/fault_st_ch1_s",              "x_fault_st_ch1_s", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/fault_st_ch2_s",              "x_fault_st_ch2_s", 0);

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
         "Indicate to UUT that the external self-test circuits has a failure on CH1");

      uut_in.force_fault_ch1_s    <= '1';
      uut_in.force_fault_ch2_s    <= '0';
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.1",
         "Check if all CH1 inputs were marked as have failed its self-test (excluding spare signals)");

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_1_BIT,  '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_2_BIT,  '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_3_BIT,  '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_4_BIT,  '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_5_BIT,  '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_6_BIT,  '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_7_BIT,  '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_8_BIT,  '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_9_BIT,  '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_10_BIT, '1', alarm_code_i);

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_11_BIT, '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_12_BIT, '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_13_BIT, '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_14_BIT, '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_15_BIT, '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_16_BIT, '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_17_BIT, '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_18_BIT, '0', alarm_code_i); -- Spare signal

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.2",
         "Check if all CH2 inputs were NOT marked as have failed its self-test");

      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_1_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_2_BIT,  '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_3_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_4_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_5_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_6_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_7_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_8_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_9_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_10_BIT, '0', alarm_code_i);

      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_11_BIT, '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_12_BIT, '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_13_BIT, '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_14_BIT, '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_15_BIT, '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_16_BIT, '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_17_BIT, '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_18_BIT, '0', alarm_code_i); -- Spare signal

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2", 
         "Check if all input bits associated with CH1 are masked (Expected: TRUE)");

          tfy_check( relative_time => now,         received        => x_fault_st_ch1_s = "11111111111111",
                     expected      => TRUE,        equality        => TRUE,
                     report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3", 
         "Check if all input bits associated with CH2 are masked (Expected: FALSE)");

          tfy_check( relative_time => now,         received        => x_fault_st_ch2_s = "111111111",
                     expected      => FALSE,       equality        => TRUE,
                     report_file   => report_file,	pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.4");


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "Indicate to UUT that the external self-test circuits has a failure on CH2");

      uut_in.force_fault_ch1_s    <= '0';
      uut_in.force_fault_ch2_s    <= '1';
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.1",
         "Check if all CH1 inputs were NOT marked as have failed its self-test");

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_1_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_2_BIT,  '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_3_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_4_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_5_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_6_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_7_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_8_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_9_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_10_BIT, '0', alarm_code_i);

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_11_BIT, '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_12_BIT, '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_13_BIT, '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_14_BIT, '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_15_BIT, '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_16_BIT, '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_17_BIT, '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_18_BIT, '0', alarm_code_i); -- Spare signal

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.2",
         "Check if all CH2 inputs were marked as have failed its self-test (excluding spare signals)");

      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_1_BIT,  '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_2_BIT,  '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_3_BIT,  '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_4_BIT,  '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_5_BIT,  '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_6_BIT,  '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_7_BIT,  '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_8_BIT,  '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_9_BIT,  '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_10_BIT, '1', alarm_code_i);

      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_11_BIT, '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_12_BIT, '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_13_BIT, '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_14_BIT, '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_15_BIT, '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_16_BIT, '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_17_BIT, '0', alarm_code_i); -- Spare signal
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_18_BIT, '0', alarm_code_i); -- Spare signal

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2", 
         "Check if all input bits associated with CH1 are masked (Expected: FALSE)");

          tfy_check( relative_time => now,         received        => x_fault_st_ch1_s = "11111111111111",
                     expected      => FALSE,       equality        => TRUE,
                     report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3", 
         "Check if all input bits associated with CH2 are masked (Expected: TRUE)");

          tfy_check( relative_time => now,         received        => x_fault_st_ch2_s = "111111111",
                     expected      => TRUE,        equality        => TRUE,
                     report_file   => report_file,	pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.4");


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
         tc_name        => "TC_RS176",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "04 Dec 2019",
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

END ARCHITECTURE TC_RS176;

