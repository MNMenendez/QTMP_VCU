-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS018_019_020_021_022_203
-- Module      : Input IF
-- Revision    : 2.0
-- Date        : 09 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Tests Dual Channel Compare Module
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-18
--    FPGA-REQ-19
--    FPGA-REQ-20
--    FPGA-REQ-21
--    FPGA-REQ-22
--    FPGA-REQ-203
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 25 Jun 2019
--    - CABelchior (1.2): CCN3
-- Revision 2.0 - 09 Dec 2019
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
--
-- sim -tc TC_RS018_019_020_021_022_203 -numstdoff -nocov
-- log -r /*
--
-- 18    During normal operation, all digital inputs classified as 'Dual Channel' present in Channel 1 shall 
--       be continuously compared with their corresponding values on channel 2. Comparison shall only be 
--       performed between two unmasked inputs.
--
-- 19    Masked 'Dual Channel' digital inputs shall be forced to use the un-masked input of the alternate channel. 
--       If both channels are masked, then both must resolve to logic-low level.
--
-- 20    For all 'Dual Channel' digital inputs, comparison between two channels shall be be performed on the 
--       input signals after the self-test pulses are filtered out.
--
-- 21    The comparison function shall take into account the maximum external propagation delay between the two 
--       channels that is likely to be incurred at the CPLD inputs.
--
-- 22    a) If there is a discrepancy between the two channels, new comparisons should be performed 
--          when finishing a self test, for a maximum duration of 10 self tests. 
--       b) If after 10 self tests the channels are still in disagreement, then both channels shall 
--          be masked and a minor fault flag set. 
--       c) If the channel values agree then normal comparison shall resume.
--       d) If during a comparison one of the channels is masked, the comparisons shall no longer be performed.
--
-- 203   If there is a discrepancy between the two channels, a previous latched value for the channel shall be used for the channel output. 
--       If no previous value has been latched, then the output for the channel shall be zero.
--
-- Dual-Channel sintaxe for this testCase:
--------------------------------------------------------
-- dual_in_chX(0) -> cab_act_chX_i
-- dual_in_chX(1) -> not_isol_chX_i
-- dual_in_chX(2) -> bcp_75_chX_i
-- dual_in_chX(3) -> hcs_mode_chX_i
-- dual_in_chX(4) -> zero_spd_chX_i
-- dual_in_chX(5) -> spd_lim_override_chX_i
-- dual_in_chX(6) -> vigi_pb_chX_i
-- dual_in_chX(7) -> spd_lim_chX_i
-- dual_in_chX(8) -> driverless_chX_i
--
--
-----------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;
USE WORK.txt_util_p.ALL;

ARCHITECTURE TC_RS018_019_020_021_022_203 OF hcmt_cpld_tc_top IS

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

   -- Input IF
   SIGNAL x_st_in_progress_s                      : STD_LOGIC := '0'; -- related to 'x_input_valid_s'
   SIGNAL x_debounce_tick_s                       : STD_LOGIC := '0'; -- related to 'x_input_valid_s'

   -- Input IF -> Dual-Channel Input Compare Inputs
   SIGNAL x_input_valid_s                         : STD_LOGIC := '0';
   SIGNAL x_st_done_s                             : STD_LOGIC := '0';

   -- Input IF -> Dual-Channel Input Compare Outputs
   SIGNAL x_compare_masked_ch1_s                  : STD_LOGIC_VECTOR(8 DOWNTO 0);
   SIGNAL x_compare_masked_ch2_s                  : STD_LOGIC_VECTOR(8 DOWNTO 0);
   SIGNAL x_compare_out_s                         : STD_LOGIC_VECTOR(8 DOWNTO 0);
   -- driverless_ch2_i           (8)
   -- spd_lim_ch2_i              (7)
   -- vigi_pb_ch2_i              (6)
   -- spd_lim_override_ch2_i     (5)
   -- zero_spd_ch2_i             (4)
   -- hcs_mode_ch2_i             (3)
   -- bcp_75_ch2_i               (2)
   -- not_isol_ch2_i             (1)
   -- cab_act_ch2_i              (0)

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

   SIGNAL dual_in_ch1                             : STD_LOGIC_VECTOR(CHANNEL_2_SIZE-1 DOWNTO 0) := (OTHERS => '0');
   SIGNAL dual_in_ch2                             : STD_LOGIC_VECTOR(CHANNEL_2_SIZE-1 DOWNTO 0) := (OTHERS => '0');


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
      VARIABLE t1 : TIME;
      VARIABLE dt : TIME;
      VARIABLE DUAL_CHN_QTD: NATURAL := 9; -- 9

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
         pwm_func_model_data_s   <= C_PWM_FUNC_MODEL_INPUTS_INIT;

         -------------------------------------------------
         tfy_wr_step( report_file, now, Step & ".2", 
            "Set all dual channel inputs to '0'");
         FOR i IN 0 TO 8 LOOP
            dual_in_ch1(i) <= '0';
            dual_in_ch2(i) <= '0';
         END LOOP;

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
         report_fname   => "TC_RS018_019_020_021_022_203.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS018_019_020_021_022_203",
         test_module    => "Input IF",
         tc_revision    => "2.0",
         tc_date        => "09 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Tests Dual Channel Compare Module",
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

      -- Input IF
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/input_valid_s",          "x_input_valid_s", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/selftest_in_progress_s", "x_st_in_progress_s", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/chan_selftest_done_s",   "x_st_done_s", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/debounce_tick_s",        "x_debounce_tick_s", 0);

      -- Input IF -> Dual-Channel Input Compare Outputs
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/compare_masked_ch1_s",       "x_compare_masked_ch1_s", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/compare_masked_ch2_s",       "x_compare_masked_ch2_s", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_compare_out_s", "x_compare_out_s", 0);

      --------------------------------------------------------
      -- Link Drive Probes
      --------------------------------------------------------

      --------------------------------------------------------
      -- Initializations
      --------------------------------------------------------
      tfy_wr_console(" [*] Simulation Init");
      --uut_in                   <= f_uutinit('0');
      uut_in.clk_s             <= 'Z';
      uut_in.pwm_ch1_s         <= 'Z';
      uut_in.pwm_ch2_s         <= 'Z';
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
         "Check if, when there is a discrepancy between two channels, new comparisons are performed only after a self test"); -- (REQ 22-a,c & REQ 203)

      FOR i IN 0 TO DUAL_CHN_QTD-1 LOOP

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_console(" [*] Step 2." &str(i+1));
         tfy_wr_step( report_file, now, "2." &str(i+1), 
            "For dual-channel signal dual_in_chX("& str(i) &"), do:");

         -----------------------------------------------------------------------------------------------------------
         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2."& str(i+1) &".1",
            "Set both channels to '0', and wait for 20ms");

         dual_in_ch1(i) <= '0';
         dual_in_ch2(i) <= '0';
         WAIT FOR 20 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2."& str(i+1) &".2",
            "Force a discrepancy between the two channels (Ch1 = '0' & Ch2 = '1'), and wait for 20ms");

         dual_in_ch1(i) <= '0';
         dual_in_ch2(i) <= '1';
         WAIT FOR 20 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2."& str(i+1) &".3",
            "Set both channels to '1', and wait for 20ms");

         dual_in_ch1(i) <= '1';
         dual_in_ch2(i) <= '1';
         WAIT FOR 20 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2."& str(i+1) &".4",
            "Before a self test, check if output of compare module is '0' (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => x_compare_out_s(i) = '0',
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2."& str(i+1) &".5",
            "After a self test, check if output of compare module is '1' (Expected: TRUE)");

         WAIT UNTIL rising_edge(x_st_done_s);
         WAIT FOR 20 ms;

         tfy_check( relative_time => now,         received        => x_compare_out_s(i) = '1',
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         Reset_UUT("2."& str(i+1) &".6");

         -----------------------------------------------------------------------------------------------------------
         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2."& str(i+1) &".7",
            "Set both channels to '0', and wait for 20ms");

         dual_in_ch1(i) <= '0';
         dual_in_ch2(i) <= '0';
         WAIT FOR 20 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2."& str(i+1) &".8",
            "Force a discrepancy between the two channels (Ch1 = '1' & Ch2 = '0'), and wait for 20ms");

         dual_in_ch1(i) <= '1';
         dual_in_ch2(i) <= '0';
         WAIT FOR 20 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2."& str(i+1) &".9",
            "Set both channels to '1', and wait for 20ms");

         dual_in_ch1(i) <= '1';
         dual_in_ch2(i) <= '1';
         WAIT FOR 20 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2."& str(i+1) &".10",
            "Before a self test, check if output of compare module is '0' (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => x_compare_out_s(i) = '0',
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2."& str(i+1) &".11",
            "After a self test, check if output of compare module is '1' (Expected: TRUE)");

         WAIT UNTIL rising_edge(x_st_done_s);
         WAIT FOR 20 ms;

         tfy_check( relative_time => now,         received        => x_compare_out_s(i) = '1',
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         Reset_UUT("2."& str(i+1) &".12");

      END LOOP;


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "Verify the behavior when (first) one and (then) two channels are masked"); -- (REQ 22-d)

      FOR i IN 0 TO DUAL_CHN_QTD-1 LOOP

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_console(" [*] Step 3." &str(i+1));
         tfy_wr_step( report_file, now, "3." &str(i+1), 
            "For dual-channel signal dual_in_chX("& str(i) &"), do:");

         -----------------------------------------------------------------------------------------------------------
         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3."& str(i+1) &".1",
            "Set both channels to '0', and wait for 20ms");

         dual_in_ch1(i) <= '0';
         dual_in_ch2(i) <= '0';
         WAIT FOR 20 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3."& str(i+1) &".2",
            "Force a discrepancy between the two channels (Ch1 = '1' & Ch2 = '0'), and wait for the end of a self test");

         dual_in_ch1(i) <= '1';
         dual_in_ch2(i) <= '0';
         WAIT UNTIL rising_edge(x_st_done_s);
         WAIT FOR 20 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3."& str(i+1) &".2.1",
            "Check if both CH1 and CH2 are NOT masked (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => (x_compare_masked_ch1_s(i) = '0' AND x_compare_masked_ch2_s(i) = '0'),
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3."& str(i+1) &".2.2",
            "Check if output of compare module is '0' (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => x_compare_out_s(i) = '0',
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3."& str(i+1) &".3",
            "Force a fault on all CH2 inputs and wait for the end of two self tests");

         st_ch2_in_ctrl_s(9 DOWNTO 0) <= (OTHERS => TEST_FAIL_LOW);
         WAIT UNTIL rising_edge(x_st_done_s);
         WAIT UNTIL rising_edge(x_st_done_s);
         WAIT FOR 20 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3."& str(i+1) &".3.1",
            "Check if only CH2 is masked (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => (x_compare_masked_ch1_s(i) = '0' AND x_compare_masked_ch2_s(i) = '1'),
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3."& str(i+1) &".3.2",
            "Check if output of compare module is '1' (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => x_compare_out_s(i) = '1',
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3."& str(i+1) &".4",
            "Force a fault on all CH1 inputs and wait for the end of two self tests");

         st_ch1_in_ctrl_s(16 DOWNTO 0) <= (OTHERS => TEST_FAIL_LOW);
         WAIT UNTIL rising_edge(x_st_done_s);
         WAIT UNTIL rising_edge(x_st_done_s);
         WAIT FOR 20 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3."& str(i+1) &".4.1",
            "Check if Both CH1 and CH2 are masked (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => (x_compare_masked_ch1_s(i) = '1' AND x_compare_masked_ch2_s(i) = '1'),
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3."& str(i+1) &".4.2",
            "Check if output of compare module is '0' (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => x_compare_out_s(i) = '0',
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         Reset_UUT("3."& str(i+1) &".5");

         -----------------------------------------------------------------------------------------------------------
         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3."& str(i+1) &".6",
            "Set both channels to '0', and wait for 20ms");

         dual_in_ch1(i) <= '0';
         dual_in_ch2(i) <= '0';
         WAIT FOR 20 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3."& str(i+1) &".7",
            "Force a discrepancy between the two channels (Ch1 = '0' & Ch2 = '1'), and wait for the end of a self test");

         dual_in_ch1(i) <= '0';
         dual_in_ch2(i) <= '1';
         WAIT UNTIL rising_edge(x_st_done_s);
         WAIT FOR 20 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3."& str(i+1) &".7.1",
            "Check if both CH1 and CH2 are NOT masked (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => (x_compare_masked_ch1_s(i) = '0' AND x_compare_masked_ch2_s(i) = '0'),
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3."& str(i+1) &".7.2",
            "Check if output of compare module is '0' (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => x_compare_out_s(i) = '0',
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3."& str(i+1) &".8",
            "Force a fault on all CH1 inputs and wait for the end of two self tests");

         st_ch1_in_ctrl_s(16 DOWNTO 0) <= (OTHERS => TEST_FAIL_LOW);
         WAIT UNTIL rising_edge(x_st_done_s);
         WAIT UNTIL rising_edge(x_st_done_s);
         WAIT FOR 20 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3."& str(i+1) &".8.1",
            "Check if only CH1 is masked (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => (x_compare_masked_ch1_s(i) = '1' AND x_compare_masked_ch2_s(i) = '0'),
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3."& str(i+1) &".8.2",
            "Check if output of compare module is '1' (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => x_compare_out_s(i) = '1',
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3."& str(i+1) &".9",
            "Force a fault on all CH2 inputs and wait for the end of two self tests");

         st_ch2_in_ctrl_s(9 DOWNTO 0) <= (OTHERS => TEST_FAIL_LOW);
         WAIT UNTIL rising_edge(x_st_done_s);
         WAIT UNTIL rising_edge(x_st_done_s);
         WAIT FOR 20 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3."& str(i+1) &".9.1",
            "Check if Both CH1 and CH2 are masked (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => (x_compare_masked_ch1_s(i) = '1' AND x_compare_masked_ch2_s(i) = '1'),
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3."& str(i+1) &".9.2",
            "Check if output of compare module is '0' (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => x_compare_out_s(i) = '0',
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         Reset_UUT("3."& str(i+1) &".10");

      END LOOP;


      --==============
      -- Step 4 
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------------#");
      tfy_wr_step( report_file, now, "4",
         "Check if, after 10 self tests with the channels in disagreement, then both channels are masked and a minor fault flag is set"); -- (REQ 22-b)

      FOR i IN 0 TO DUAL_CHN_QTD-1 LOOP

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_console(" [*] Step 4." &str(i+1));
         tfy_wr_step( report_file, now, "4." &str(i+1), 
            "For dual-channel signal dual_in_chX("& str(i) &"), do:");

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "4."& str(i+1) &".1",
            "Set both channels to '0', and wait for 20ms");

         dual_in_ch1(i) <= '0';
         dual_in_ch2(i) <= '0';
         WAIT FOR 20 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "4."& str(i+1) &".2",
            "Force a discrepancy between the two channels (Ch1 = '0' & Ch2 = '1'), and wait for the end of nine self tests");

         dual_in_ch1(i) <= '0';
         dual_in_ch2(i) <= '1';
         WAIT UNTIL rising_edge(x_st_done_s); -- 1
         WAIT UNTIL rising_edge(x_st_done_s); -- 2
         WAIT UNTIL rising_edge(x_st_done_s); -- 3
         WAIT UNTIL rising_edge(x_st_done_s); -- 4
         WAIT UNTIL rising_edge(x_st_done_s); -- 5
         WAIT UNTIL rising_edge(x_st_done_s); -- 6
         WAIT UNTIL rising_edge(x_st_done_s); -- 7
         WAIT UNTIL rising_edge(x_st_done_s); -- 8
         WAIT UNTIL rising_edge(x_st_done_s); -- 9
         WAIT FOR 20 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "4."& str(i+1) &".3",
            "Check if both channels are NOT masked (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => (x_compare_masked_ch1_s(i) = '0' AND x_compare_masked_ch2_s(i) = '0'),
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         Report_Minor_Fault("4."& str(i+1) &".3.1", FALSE, minor_flt_report_s);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "4."& str(i+1) &".4",
            "Wait for the end of the tenth self test");

         WAIT UNTIL rising_edge(x_st_done_s); -- 10
         WAIT FOR 20 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "4."& str(i+1) &".5",
            "Check if both channels ARE masked (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => (x_compare_masked_ch1_s(i) = '1' AND x_compare_masked_ch2_s(i) = '1'),
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         Report_Minor_Fault("4."& str(i+1) &".5.1", TRUE, minor_flt_report_s);

         -----------------------------------------------------------------------------------------------------------
         Reset_UUT("4."& str(i+1) &".6");

         -----------------------------------------------------------------------------------------------------------
         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "4."& str(i+1) &".7",
            "Set both channels to '0', and wait for 20ms");

         dual_in_ch1(i) <= '0';
         dual_in_ch2(i) <= '0';
         WAIT FOR 20 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "4."& str(i+1) &".8",
            "Force a discrepancy between the two channels (Ch1 = '1' & Ch2 = '0'), and wait for the end of nine self tests");

         dual_in_ch1(i) <= '1';
         dual_in_ch2(i) <= '0';
         WAIT UNTIL rising_edge(x_st_done_s); -- 1
         WAIT UNTIL rising_edge(x_st_done_s); -- 2
         WAIT UNTIL rising_edge(x_st_done_s); -- 3
         WAIT UNTIL rising_edge(x_st_done_s); -- 4
         WAIT UNTIL rising_edge(x_st_done_s); -- 5
         WAIT UNTIL rising_edge(x_st_done_s); -- 6
         WAIT UNTIL rising_edge(x_st_done_s); -- 7
         WAIT UNTIL rising_edge(x_st_done_s); -- 8
         WAIT UNTIL rising_edge(x_st_done_s); -- 9
         WAIT FOR 20 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "4."& str(i+1) &".9",
            "Check if both channels are NOT masked (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => (x_compare_masked_ch1_s(i) = '0' AND x_compare_masked_ch2_s(i) = '0'),
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         Report_Minor_Fault("4."& str(i+1) &".9.1", FALSE, minor_flt_report_s);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "4."& str(i+1) &".10",
            "Wait for the end of the tenth self test");

         WAIT UNTIL rising_edge(x_st_done_s); -- 10
         WAIT FOR 20 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "4."& str(i+1) &".11",
            "Check if both channels ARE masked (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => (x_compare_masked_ch1_s(i) = '1' AND x_compare_masked_ch2_s(i) = '1'),
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         Report_Minor_Fault("4."& str(i+1) &".11.1", TRUE, minor_flt_report_s);

         -----------------------------------------------------------------------------------------------------------
         Reset_UUT("4."& str(i+1) &".12");

      END LOOP;


      --==============
      -- Step 5 
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5: -------------------------------------------#");
      tfy_wr_step( report_file, now, "5",
         "Check if the comparison between two channels is performed after the self-test pulses are   filtered out"); -- (REQ 20)

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1",
         "Wait for the begin of the CH1 self-test");

      WAIT UNTIL rising_edge(uut_out.test_high_ch1_s);    -- Begin of the CH1 self-test

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2",
         "Wait for the next 'x_input_valid_s'");  -- the comparisson id done every time that x_input_valid_s is '1'

      WAIT UNTIL rising_edge(x_input_valid_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.1",
         "Check if the self-test is already conclude (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_st_in_progress_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);


      --==============
      -- Step 6 
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6: -------------------------------------------#");
      tfy_wr_step( report_file, now, "6",
         "Force the transition to DELAY_CHECK -> WHEN OTHERS ");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1", 
         "For dual-channel signal dual_in_chX(0), do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1.1",
         "Force the transition on instance 'input_compare_i0(0)' anc check the outputs");

      signal_force("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(0)/input_compare_i/state_r", "DELAY_CHECK", open, freeze, open, 0);
      signal_force("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(0)/input_compare_i/imask_s", "11", open, freeze, open, 0);
      WAIT FOR 10 ms;

      tfy_check( relative_time => now,         received        => x_compare_out_s(0) = '0',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => (x_compare_masked_ch1_s(0) = '1' AND x_compare_masked_ch2_s(0) = '1'),
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      signal_release("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(0)/input_compare_i/state_r", 0);
      signal_release("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(0)/input_compare_i/imask_s", 0);
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("6.1.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2", 
         "For dual-channel signal dual_in_chX(1), do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2.1",
         "Force the transition on instance 'input_compare_i0(1)' anc check the outputs");

      signal_force("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(1)/input_compare_i/state_r", "DELAY_CHECK", open, freeze, open, 0);
      signal_force("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(1)/input_compare_i/imask_s", "11", open, freeze, open, 0);
      WAIT FOR 10 ms;

      tfy_check( relative_time => now,         received        => x_compare_out_s(1) = '0',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => (x_compare_masked_ch1_s(1) = '1' AND x_compare_masked_ch2_s(1) = '1'),
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      signal_release("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(1)/input_compare_i/state_r", 0);
      signal_release("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(1)/input_compare_i/imask_s", 0);
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("6.2.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3", 
         "For dual-channel signal dual_in_chX(2), do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.1",
         "Force the transition on instance 'input_compare_i0(2)' anc check the outputs");

      signal_force("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(2)/input_compare_i/state_r", "DELAY_CHECK", open, freeze, open, 0);
      signal_force("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(2)/input_compare_i/imask_s", "11", open, freeze, open, 0);
      WAIT FOR 10 ms;

      tfy_check( relative_time => now,         received        => x_compare_out_s(2) = '0',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => (x_compare_masked_ch1_s(2) = '1' AND x_compare_masked_ch2_s(2) = '1'),
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      signal_release("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(2)/input_compare_i/state_r", 0);
      signal_release("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(2)/input_compare_i/imask_s", 0);
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("6.3.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4", 
         "For dual-channel signal dual_in_chX(3), do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4.1",
         "Force the transition on instance 'input_compare_i0(3)' anc check the outputs");

      signal_force("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(3)/input_compare_i/state_r", "DELAY_CHECK", open, freeze, open, 0);
      signal_force("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(3)/input_compare_i/imask_s", "11", open, freeze, open, 0);
      WAIT FOR 10 ms;

      tfy_check( relative_time => now,         received        => x_compare_out_s(3) = '0',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => (x_compare_masked_ch1_s(3) = '1' AND x_compare_masked_ch2_s(3) = '1'),
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      signal_release("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(3)/input_compare_i/state_r", 0);
      signal_release("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(3)/input_compare_i/imask_s", 0);
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("6.4.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.5", 
         "For dual-channel signal dual_in_chX(4), do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.5.1",
         "Force the transition on instance 'input_compare_i0(4)' anc check the outputs");

      signal_force("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(4)/input_compare_i/state_r", "DELAY_CHECK", open, freeze, open, 0);
      signal_force("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(4)/input_compare_i/imask_s", "11", open, freeze, open, 0);
      WAIT FOR 10 ms;

      tfy_check( relative_time => now,         received        => x_compare_out_s(4) = '0',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => (x_compare_masked_ch1_s(4) = '1' AND x_compare_masked_ch2_s(4) = '1'),
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      signal_release("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(4)/input_compare_i/state_r", 0);
      signal_release("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(4)/input_compare_i/imask_s", 0);
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("6.5.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.6", 
         "For dual-channel signal dual_in_chX(5), do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.6.1",
         "Force the transition on instance 'input_compare_i0(5)' anc check the outputs");

      signal_force("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(5)/input_compare_i/state_r", "DELAY_CHECK", open, freeze, open, 0);
      signal_force("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(5)/input_compare_i/imask_s", "11", open, freeze, open, 0);
      WAIT FOR 10 ms;

      tfy_check( relative_time => now,         received        => x_compare_out_s(5) = '0',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => (x_compare_masked_ch1_s(5) = '1' AND x_compare_masked_ch2_s(5) = '1'),
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      signal_release("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(5)/input_compare_i/state_r", 0);
      signal_release("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(5)/input_compare_i/imask_s", 0);
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("6.6.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.7", 
         "For dual-channel signal dual_in_chX(6), do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.7.1",
         "Force the transition on instance 'input_compare_i0(6)' anc check the outputs");

      signal_force("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(6)/input_compare_i/state_r", "DELAY_CHECK", open, freeze, open, 0);
      signal_force("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(6)/input_compare_i/imask_s", "11", open, freeze, open, 0);
      WAIT FOR 10 ms;

      tfy_check( relative_time => now,         received        => x_compare_out_s(6) = '0',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => (x_compare_masked_ch1_s(6) = '1' AND x_compare_masked_ch2_s(6) = '1'),
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      signal_release("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(6)/input_compare_i/state_r", 0);
      signal_release("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(6)/input_compare_i/imask_s", 0);
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("6.7.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.8", 
         "For dual-channel signal dual_in_chX(7), do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.8.1",
         "Force the transition on instance 'input_compare_i0(7)' anc check the outputs");

      signal_force("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(7)/input_compare_i/state_r", "DELAY_CHECK", open, freeze, open, 0);
      signal_force("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(7)/input_compare_i/imask_s", "11", open, freeze, open, 0);
      WAIT FOR 10 ms;

      tfy_check( relative_time => now,         received        => x_compare_out_s(7) = '0',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => (x_compare_masked_ch1_s(7) = '1' AND x_compare_masked_ch2_s(7) = '1'),
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      signal_release("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(7)/input_compare_i/state_r", 0);
      signal_release("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(7)/input_compare_i/imask_s", 0);
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("6.8.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.9", 
         "For dual-channel signal dual_in_chX(8), do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.9.1",
         "Force the transition on instance 'input_compare_i0(8)' anc check the outputs");

      signal_force("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(8)/input_compare_i/state_r", "DELAY_CHECK", open, freeze, open, 0);
      signal_force("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(8)/input_compare_i/imask_s", "11", open, freeze, open, 0);
      WAIT FOR 10 ms;

      tfy_check( relative_time => now,         received        => x_compare_out_s(8) = '0',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => (x_compare_masked_ch1_s(8) = '1' AND x_compare_masked_ch2_s(8) = '1'),
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      signal_release("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(8)/input_compare_i/state_r", 0);
      signal_release("/hcmt_cpld_top_tb/UUT/input_if_i0/input_compare_i0(8)/input_compare_i/imask_s", 0);
      WAIT FOR 10 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("6.9.2");

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
         tc_name        => "TC_RS018_019_020_021_022_203",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "09 Dec 2019",
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

   ----------------------------------------------------------------------------
   --  Safety-Related Digital Inputs
   ----------------------------------------------------------------------------

   uut_in.cab_act_ch1_s          <= dual_in_ch1(0);
   uut_in.cab_act_ch2_s          <= dual_in_ch2(0);

   uut_in.not_isol_ch1_s         <= dual_in_ch1(1);
   uut_in.not_isol_ch2_s         <= dual_in_ch2(1);

   uut_in.bcp_75_ch1_s           <= dual_in_ch1(2);
   uut_in.bcp_75_ch2_s           <= dual_in_ch2(2);

   uut_in.hcs_mode_ch1_s         <= dual_in_ch1(3);
   uut_in.hcs_mode_ch2_s         <= dual_in_ch2(3);

   uut_in.zero_spd_ch1_s         <= dual_in_ch1(4);
   uut_in.zero_spd_ch2_s         <= dual_in_ch2(4);

   uut_in.spd_lim_override_ch1_s <= dual_in_ch1(5);
   uut_in.spd_lim_override_ch2_s <= dual_in_ch2(5);

   uut_in.vigi_pb_ch1_s          <= dual_in_ch1(6);
   uut_in.vigi_pb_ch2_s          <= dual_in_ch2(6);

   uut_in.spd_lim_ch1_s          <= dual_in_ch1(7);
   uut_in.spd_lim_ch2_s          <= dual_in_ch2(7);

   uut_in.driverless_ch1_s       <= dual_in_ch1(8);
   uut_in.driverless_ch2_s       <= dual_in_ch2(8);

END ARCHITECTURE TC_RS018_019_020_021_022_203;

