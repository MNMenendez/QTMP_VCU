-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS013_048_014_049_015_055_190
-- Module      : DI
-- Revision    : 2.0
-- Date        : 03 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Tests the input self-test requirements compliance disregarding the masking operations
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-13
--    FPGA-REQ-48
--    FPGA-REQ-14
--    FPGA-REQ-49
--    FPGA-REQ-15
--    FPGA-REQ-55
--    FPGA-REQ-190
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 06 Apr 2018
--    - CABelchior (1.0): Initial Release
-- Revision 1.1 - 08 Jun 2019
--    - VSA (1.1): CCN03 changes
-- Revision 2.0 - 03 Dec 2019
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- Notes:
--
-- sim -tc TC_RS013_048_014_049_015_055_190 -numstdoff -nocov
-- log -r /*
--
-- NOTE: In order to test the Diagnostic and LED Display interfaces, 
--       one MUST use C_CLK_DERATE_BITS = 0 at hcmt_cpld_top_p
--
-- 13   At every 0.5 second, the CPLD shall perform a self-test routine for all digital inputs specified 
--      in Table 1, interleaving between both channel 1 and channel 2.
-- 
-- 48   The self-test routine shall include two sub-tests, hereafter denoted as:
--      1. test input-HIGH
--      2. test input-LOW
--
-- 14   The 'test input-HIGH' shall provide the following functionality: An output signaling the execution 
--      of the 'test input-HIGH' to external hardware should be asserted (logic-high), while an output 
--      signaling the execution of 'test input-LOW' should be de-asserted (logic-low).
--
-- 49   'test input-HIGH', shall check that all digital inputs across the channel under test are set to logic 
--      level ‘1’.
--
-- 15   The 'test input-LOW' shall provide the following functionality: The output signaling the execution 
--      of 'test input-LOW' is asserted at least 1ms after the assertion of the output signal requesting 
--      'test input-HIGH', resulting in both outputs set to logic-high.
--
-- 55   'test input-LOW', shall check that all digital inputs across the channel under test are set to logic 
--      level ‘0’.
--
-- 190  When finishing the 'test input-LOW' check the 'test input-HIGH' request output shall be de-asserted 500uS BEFORE the
--      de-assertion of the output requesting the 'test input-LOW'. 
-----------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;

ARCHITECTURE TC_RS013_048_014_049_015_055_190 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Type Definitions
   --------------------------------------------------------

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------
   CONSTANT C_DEBOUNCE_PERIOD                     : TIME := 500 us;
   CONSTANT C_SETTLING_PERIOD                     : TIME := 500 us;
   CONSTANT C_TOLERANCE_PERIOD                    : TIME :=  10 us;
   CONSTANT C_SELF_TEST_PERIOD                    : TIME := 500 ms;

   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------

   -- Status outputs
   SIGNAL x_selftest_in_progress_s                : STD_LOGIC := '0';

   -- Fault outputs
   SIGNAL x_fault_st_ch1_s                        : STD_LOGIC_VECTOR(13 DOWNTO 0) := (OTHERS => '0'); -- effective number of inputs, disregarding the spares
   SIGNAL x_fault_st_ch2_s                        : STD_LOGIC_VECTOR(8 DOWNTO 0) := (OTHERS => '0');  -- effective number of inputs, disregarding the spares

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

   SIGNAL expected_results_ch1                    : STD_LOGIC_VECTOR(13 DOWNTO 0);  -- same size of x_fault_st_ch1_s
   SIGNAL expected_results_ch2                    : STD_LOGIC_VECTOR(8 DOWNTO 0);   -- same size of x_fault_st_ch2_s

BEGIN

   p_steps: PROCESS

      --------------------------------------------------------
      -- Common Test Case variable declarations
      --------------------------------------------------------
      VARIABLE pass                              : BOOLEAN := true;

      --------------------------------------------------------
      -- Other Testcase Variables
      --------------------------------------------------------
      VARIABLE t0_ch1                            : TIME := 0 us;
      VARIABLE t1_ch1                            : TIME := 0 us;
      VARIABLE t2_ch1                            : TIME := 0 us;
      VARIABLE t3_ch1                            : TIME := 0 us;
      VARIABLE dt_ch1                            : TIME := 0 us;

      VARIABLE t0_ch2                            : TIME := 0 us;
      VARIABLE t1_ch2                            : TIME := 0 us;
      VARIABLE t2_ch2                            : TIME := 0 us;
      VARIABLE t3_ch2                            : TIME := 0 us;
      VARIABLE dt_ch2                            : TIME := 0 us;

      VARIABLE t0_st_ch1                         : TIME := 0 us;
      VARIABLE t0_st_ch2                         : TIME := 0 us;
      VARIABLE t1_st_ch1                         : TIME := 0 us;
      VARIABLE t1_st_ch2                         : TIME := 0 us;

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
         report_fname   => "TC_RS013_048_014_049_015_055_190.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS013_048_014_049_015_055_190",
         test_module    => "Input SelfTest",
         tc_revision    => "2.0",
         tc_date        => "03 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Tests the input self-test requirements compliance disregarding the masking operations",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_top_tb",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s
      );

      --------------------------------------------------------
      -- Link Spy Probes
      --------------------------------------------------------

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/selftest_in_progress_s",   "x_selftest_in_progress_s", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/fault_st_ch1_s",           "x_fault_st_ch1_s", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/fault_st_ch2_s",           "x_fault_st_ch2_s", 0);

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
         "Check the time and sequence constraints of 'test_high_ch1_o' and 'test_low_ch1_o'");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1", 
         "Wait until the rising edge of 'test_high_ch1_o' and stamp its time (t0_ch1 = t0_st_ch1 = now)");

      WAIT UNTIL rising_edge(uut_out.test_high_ch1_s); REPORT ("2.1:");
      t0_ch1 := now;
      t0_st_ch1 := t0_ch1;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.1", 
         "Compare 'test_high_ch1_o' and 'test_low_ch1_o with their expected values");

      tfy_check( relative_time => now,         received        => (uut_out.test_high_ch1_s = '1') and (uut_out.test_low_ch1_s = '0'),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2", 
         "Wait until the rising edge of 'test_low_ch1_o' and stamp its time (t1_ch1 = now)");

      WAIT UNTIL rising_edge(uut_out.test_low_ch1_s); REPORT ("2.2:");
      t1_ch1 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.1", 
         "Compare 'test_high_ch1_o' and 'test_low_ch1_o' with their expected values");

      tfy_check( relative_time => now,         received        => (uut_out.test_high_ch1_s = '1') and (uut_out.test_low_ch1_s = '1'),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3", 
         "Wait until the falling edge of 'test_high_ch1_o' and stamp its time (t2_ch1 = now)");

      WAIT UNTIL falling_edge(uut_out.test_high_ch1_s); REPORT ("2.3:");
      t2_ch1 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.1", 
         "Compare 'test_high_ch1_o' and 'test_low_ch1_o' with their expected values");

      tfy_check( relative_time => now,         received        => (uut_out.test_high_ch1_s = '0') and (uut_out.test_low_ch1_s = '1'),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4", 
         "Wait until the falling edge of 'test_low_ch1_o' and stamp its time (t3_ch1 = now)");

      WAIT UNTIL falling_edge(uut_out.test_low_ch1_s); REPORT ("2.4:");
      t3_ch1 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.1", 
         "Compare 'test_high_ch1_o' and 'test_low_ch1_o' with their expected values");

      tfy_check( relative_time => now,         received        => (uut_out.test_high_ch1_s = '0') and (uut_out.test_low_ch1_s = '0'),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5", 
         "Check if the time between rising edges of 'test_high_ch1_o' and 'test_low_ch1_o' is at least 1ms");  -- REQ 15

      dt_ch1 := t1_ch1 - t0_ch1;

      tfy_check(relative_time  => now, 
         received       => dt_ch1,
         expected_min   => C_DEBOUNCE_PERIOD + C_SETTLING_PERIOD,
         expected_max   => C_DEBOUNCE_PERIOD + C_SETTLING_PERIOD + C_TOLERANCE_PERIOD,
         report_file    => report_file,
         pass           => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.6", 
         "Check if the time between the falling edge of 'test_high_ch1_o' and 'test_low_ch1_o' is 500us");     -- REQ 190

      dt_ch1 := t3_ch1 - t2_ch1;

      tfy_check(relative_time  => now, 
         received       => dt_ch1,
         expected_min   => C_DEBOUNCE_PERIOD - C_TOLERANCE_PERIOD,
         expected_max   => C_DEBOUNCE_PERIOD + C_TOLERANCE_PERIOD,
         report_file    => report_file,
         pass           => pass);


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3", 
         "Check the time and sequence constraints of 'test_high_ch2_o' and 'test_low_ch2_o'");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1", 
         "Wait until the rising edge of 'test_high_ch2_o' and stamp its time (t0_ch2 = t0_st_ch2 = now)");

      WAIT UNTIL rising_edge(uut_out.test_high_ch2_s); REPORT ("3.1:");
      t0_ch2 := now;
      t0_st_ch2 := t0_ch2;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.1", 
         "Compare 'test_high_ch2_o' and 'test_low_ch1_o with their expected values'");

      tfy_check( relative_time => now,         received        => (uut_out.test_high_ch2_s = '1') and (uut_out.test_low_ch2_s = '0'),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2", 
         "Wait until the rising edge of 'test_low_ch2_o' and stamp its time (t1_ch2 = now)");

      WAIT UNTIL rising_edge(uut_out.test_low_ch2_s); REPORT ("3.2:");
      t1_ch2 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.1", 
         "Compare 'test_high_ch2_o' and 'test_low_ch2_o' with their expected values'");

      tfy_check( relative_time => now,         received        => (uut_out.test_high_ch2_s = '1') and (uut_out.test_low_ch2_s = '1'),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3", 
         "Wait until the falling edge of 'test_high_ch2_o' and stamp its time (t2_ch2 = now)");

      WAIT UNTIL falling_edge(uut_out.test_high_ch2_s); REPORT ("3.3:");
      t2_ch2 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.1", 
         "Compare 'test_high_ch2_o' and 'test_low_ch2_o' with their expected values");

      tfy_check( relative_time => now,         received        => (uut_out.test_high_ch2_s = '0') and (uut_out.test_low_ch2_s = '1'),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4", 
         "Wait until the falling edge of 'test_low_ch2_o' and stamp its time (t3_ch2 = now)");

      WAIT UNTIL falling_edge(uut_out.test_low_ch2_s); REPORT ("3.4:");
      t3_ch2 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.1", 
         "Compare 'test_high_ch2_o' and 'test_low_ch2_o' with their expected values");

      tfy_check( relative_time => now,         received        => (uut_out.test_high_ch2_s = '0') and (uut_out.test_low_ch2_s = '0'),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5", 
         "Check if the time between rising edges of 'test_high_ch2_o' and 'test_low_ch2_o' is at least 1 ms");   -- REQ 15

      dt_ch2 := t1_ch2 - t0_ch2;

      tfy_check(relative_time  => now, 
         received       => dt_ch2,
         expected_min   => C_DEBOUNCE_PERIOD + C_SETTLING_PERIOD,
         expected_max   => C_DEBOUNCE_PERIOD + C_SETTLING_PERIOD + C_TOLERANCE_PERIOD,
         report_file    => report_file,
         pass           => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.6", 
         "Check if the time between the falling edge of 'test_high_ch2_o' and 'test_low_ch2_o' is 500us");        -- REQ 190

      dt_ch2 := t3_ch2 - t2_ch2;

      tfy_check(relative_time  => now, 
         received       => dt_ch2,
         expected_min   => C_DEBOUNCE_PERIOD - C_TOLERANCE_PERIOD,
         expected_max   => C_DEBOUNCE_PERIOD + C_TOLERANCE_PERIOD,
         report_file    => report_file,
         pass           => pass);


      --==============
      -- Step 4
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------#");
      tfy_wr_step( report_file, now, "4", 
         "Check the 'failure while self-test HIGH' detection capability for both CH1 and CH2");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1", 
         "Force a 'failure while self-test HIGH' at all CH1 inputs");

      st_ch1_in_ctrl_s     <= (OTHERS => TEST_FAIL_HIGH);
      expected_results_ch1 <= (OTHERS => '1');
  
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2", 
         "Wait until the rising edge of 'test_high_ch1_o' and stamp its time (t1_st_ch1 = now)");

      WAIT UNTIL rising_edge(uut_out.test_high_ch1_s);
      t1_st_ch1 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3", 
         "Wait until the end of self-test routine");

      WAIT UNTIL falling_edge(x_selftest_in_progress_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4", 
         "Compare the obtained results with the expected results");

      tfy_check( relative_time => now,         received        => (x_fault_st_ch1_s = expected_results_ch1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);
      
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5", 
         "Force a 'failure while self-test HIGH' at all CH2 inputs");

      st_ch2_in_ctrl_s     <= (OTHERS => TEST_FAIL_HIGH);
      expected_results_ch2 <= (OTHERS => '1');

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.6", 
         "Wait until the rising edge of 'test_high_ch2_o' and stamp its time (t1_st_ch2 = now)");

      WAIT UNTIL rising_edge(uut_out.test_high_ch2_s);
      t1_st_ch2 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.7", 
         "Wait until the end of self-test routine");

      WAIT UNTIL falling_edge(x_selftest_in_progress_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.8", 
         "Compare the obtained results with the expected results");

      tfy_check( relative_time => now,         received        => (x_fault_st_ch2_s = expected_results_ch2),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);


      --==============
      -- Step 5
      --==============

      tfy_wr_console(" [*] Step 5: -------------------------------------#");
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5", 
         "Check if all registered faults are cleaned after a reset of the UUT");

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.1");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2", 
         "Recheck the results of step 4.4, but this time expect a FALSE as result");

      tfy_check( relative_time => now,         received        => (x_fault_st_ch1_s = expected_results_ch1),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3", 
         "Recheck the results of step 4.8, but this time expect a FALSE as result");

      tfy_check( relative_time => now,         received        => (x_fault_st_ch2_s = expected_results_ch2),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);


      --==============
      -- Step 6
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6: -------------------------------------#");
      tfy_wr_step( report_file, now, "6", 
         "Check the 'failure while self-test LOW' detection capability for both CH1 and CH2");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1", 
         "Force a 'failure while self-test LOW' at all CH1 inputs");

      st_ch1_in_ctrl_s     <= (OTHERS => TEST_FAIL_LOW);
      expected_results_ch1 <= (OTHERS => '1');

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2", 
         "Wait until the rising edge of 'test_high_ch1_o'");

      WAIT UNTIL rising_edge(uut_out.test_high_ch1_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3", 
         "Wait until the end of self-test routine");

      WAIT UNTIL falling_edge(x_selftest_in_progress_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4", 
         "Compare the obtained results with the expected results");

      tfy_check( relative_time => now,         received        => (x_fault_st_ch1_s = expected_results_ch1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.5", 
         "Force a 'failure while self-test LOW' at all CH2 inputs");

      st_ch2_in_ctrl_s     <= (OTHERS => TEST_FAIL_LOW);
      expected_results_ch2 <= (OTHERS => '1');

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.6", 
         "Wait until the rising edge of 'test_high_ch1_o' and stamp its time");

      WAIT UNTIL rising_edge(uut_out.test_high_ch2_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.7", 
         "Wait until the end of self-test routine");

      WAIT UNTIL falling_edge(x_selftest_in_progress_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.8", 
         "Compare the obtained results with the expected results");

      tfy_check( relative_time => now,         received        => (x_fault_st_ch2_s = expected_results_ch2),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);


      --==============
      -- Step 7
      --==============

      tfy_wr_console(" [*] Step 7: -------------------------------------#");
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7", 
         "Check if all registered faults are cleaned after a reset of the UUT");

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("7.1");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.2", 
         "Recheck the results of step 6.4, but this time expect a FALSE as result");

      tfy_check( relative_time => now,         received        => (x_fault_st_ch1_s = expected_results_ch1),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.3", 
         "Recheck the results of step 6.8, but this time expect a FALSE as result");

      tfy_check( relative_time => now,         received        => (x_fault_st_ch2_s = expected_results_ch2),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);


      --==============
      -- Step 8
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 8: -------------------------------------#");
      tfy_wr_step( report_file, now, "8", 
         "Check the time compliance of the digital inputs self-test routine");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.1", 
         "Check the time between a self-test routine request for the CH1 and for the CH2");

      tfy_check(relative_time  => now, 
                  received       => t0_st_ch2 - t0_st_ch1,
                  expected_min   => C_SELF_TEST_PERIOD - C_TOLERANCE_PERIOD,
                  expected_max   => C_SELF_TEST_PERIOD + C_TOLERANCE_PERIOD,
                  report_file    => report_file,
                  pass           => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.2", 
         "Check the time between two CH1 self-test routine requests");

      tfy_check(relative_time  => now, 
                received       => t1_st_ch1 - t0_st_ch1,
                expected_min   => C_SELF_TEST_PERIOD*2 - C_TOLERANCE_PERIOD,
                expected_max   => C_SELF_TEST_PERIOD*2 + C_TOLERANCE_PERIOD,
                report_file    => report_file,
                pass           => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.3", 
         "Check the time between two CH2 self-test routine requests");

      tfy_check(relative_time  => now, 
                received       => t1_st_ch2 - t0_st_ch2,
                expected_min   => C_SELF_TEST_PERIOD*2 - C_TOLERANCE_PERIOD,
                expected_max   => C_SELF_TEST_PERIOD*2 + C_TOLERANCE_PERIOD,
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
         tc_name        => "TC_RS013_048_014_049_015_055_190",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "03 Dec 2019",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s    
      );

   END PROCESS p_steps;

   s_usr_sigin_s.test_select	<= test_select;
   s_usr_sigin_s.clk       <= Clk;
   test_done               <= s_usr_sigout_s.test_done;
   pwm_func_model_data     <= pwm_func_model_data_s;
   st_ch1_in_ctrl_o        <= st_ch1_in_ctrl_s; 
   st_ch2_in_ctrl_o        <= st_ch2_in_ctrl_s; 

   minor_flt_report_s      <= uut_out.tms_minor_fault_s AND uut_out.disp_minor_fault_s;

END ARCHITECTURE TC_RS013_048_014_049_015_055_190;

