-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS016_023_027_012_188
-- Module      : Input IF
-- Revision    : 2.0
-- Date        : 03 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Tests the input masking capabilities of the input self-test operation, its contribution to minor fault, 
--               as well as its qualification type during normal/unmasked operation 
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-16
--    FPGA-REQ-23
--    FPGA-REQ-27
--    FPGA-REQ-12,01
--    FPGA-REQ-188
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 06 Apr 2018
--    - CABelchior (1.0): Initial Release
-- Revision 1.1 - 16 Apr 2019
--    - VSA (1.1): CCN03 changes
-- Revision 2.0 - 03 Dec 2019
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
--
-- sim -tc TC_RS016_023_027_012_188 -numstdoff -nocov
-- log -r /*
--
-- NOTE: In order to test the Diagnostic and LED Display interfaces, 
--       one MUST use C_CLK_DERATE_BITS = 0 at hcmt_cpld_top_p
--
--  16  Any bit error detected during either a 'test input-HIGH' or a 'test input-LOW' self–test, shall 
--      result in the corresponding signal being masked.
--
--  23  Any masked signal becomes an ignored input to the VCU timing system.
--
--  27  During normal operation all unmasked inputs shall trigger their respective function if their 
--      corresponding behaviour matches their configured mode of operation.
--
--  188 Any fault reported by the Self-Test routine shall contribute to the minor fault.
--
--  12,01 The means for activity detection of every logical input, defined as 'Qualification Type', 
--        is specified in Table 1. Possible attributes are:
--        - Rising edge only (RE);
--        - Falling edge only (FE);
--        - Rising OR Falling edge;
--        - Rising then Falling within a period of time with hold detection;
--        - Level sensitive.
--
--  C_POOL_PERIOD       -> simulation\testbench\hcmt_cpld_tc_top.vhd
--  C_CLK_DERATE_BITS   -> code\hcmt_cpld\hcmt_cpld_top_p.vhd
-----------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;

ARCHITECTURE TC_RS016_023_027_012_188 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Type Definitions
   --------------------------------------------------------

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------

   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------

   SIGNAL x_single_channel_event                  : STD_LOGIC_VECTOR(4 DOWNTO 0);
   SIGNAL x_dual_channel_event                    : STD_LOGIC_VECTOR(8 DOWNTO 0);

   SIGNAL x_selftest_in_progress_s                : STD_LOGIC := '0';

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

   SIGNAL single_channel_event_latch_r            : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
   SIGNAL dual_channel_event_latch_r              : STD_LOGIC_VECTOR(8 DOWNTO 0) := (OTHERS => '0');
   SIGNAL event_latch_rst_r                       : STD_LOGIC := '0';

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
         report_fname   => "TC_RS016_023_027_012_188.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS016_023_027_012_188",
         test_module    => "Input IF",
         tc_revision    => "2.0",
         tc_date        => "03 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Tests the input masking capabilities of the input self-test operation, its contribution to minor fault, as well as its qualification type during normal/unmasked operation",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_top_tb",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s
      );

      --------------------------------------------------------
      -- Link Spy Probes
      --------------------------------------------------------

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/vigi_pb_event_o",          "x_dual_channel_event(0)", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/zero_spd_event_o",         "x_dual_channel_event(1)", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/hcs_mode_event_o",         "x_dual_channel_event(2)", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/bcp_75_event_o",           "x_dual_channel_event(3)", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/not_isol_event_o",         "x_dual_channel_event(4)", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/cab_act_event_o",          "x_dual_channel_event(5)", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/spd_lim_override_event_o", "x_dual_channel_event(6)", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/driverless_event_o",       "x_dual_channel_event(7)", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/spd_lim_event_o",          "x_dual_channel_event(8)", 0);


      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/horn_low_pre_event_s",     "x_single_channel_event(0)", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/horn_high_pre_event_s",    "x_single_channel_event(1)", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/hl_low_pre_event_s",       "x_single_channel_event(2)", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/w_wiper_pb_pre_event_s",   "x_single_channel_event(3)", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/ss_bypass_pb_pre_event_s", "x_single_channel_event(4)", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/selftest_in_progress_s",   "x_selftest_in_progress_s", 0);



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
         "For Digital Input 1 - Vigilance Push Button - do:");

      -- Rising then falling 
      -- Logic Polarity           = Active High
      -- Max Activity Period      = 1.5 sec 
      -- Activity Time-Out        = N/A
      -- Max Consecutive Events   = 8

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "Set logic level '1' on signal vigi_pb_chX_i");

      uut_in.vigi_pb_ch1_s          <= '1';
      uut_in.vigi_pb_ch2_s          <= '1';
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2",
         "Check if the 'Vigilance Push Button' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(0) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_1_GREEN_BIT,  '1', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_1_RED_BIT,    '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4",
         "Set logic level '0' on signal vigi_pb_chX_i");

      uut_in.vigi_pb_ch1_s          <= '0';
      uut_in.vigi_pb_ch2_s          <= '0';
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5",
         "Check if the 'Vigilance Push Button' event was generated (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(0) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.6",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_1_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_1_BIT,'0', alarm_code_i);
      Report_LED_IF  ("-", C_LED_DI_1_GREEN_BIT,  '0', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_1_RED_BIT,    '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.7",
         "Force a fault on both CH1 and CH2 and wait for a self-test on both CH1 and CH2");

      -- @See simulation\testbench\hcmt_cpld_top_tb.vhd
      st_ch1_in_ctrl_s(0)  <= TEST_FAIL_HIGH;
      st_ch2_in_ctrl_s(0)  <= TEST_FAIL_LOW;

      WAIT UNTIL falling_edge(uut_out.test_low_ch1_s);    -- End of the CH1 self-test
      WAIT UNTIL falling_edge(uut_out.test_low_ch2_s);    -- End of the CH2 self-test
      WAIT UNTIL falling_edge(x_selftest_in_progress_s);  -- End of self-test routine

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.8",
         "Set logic level '1' on signal vigi_pb_chX_i");

      uut_in.vigi_pb_ch1_s          <= '1';
      uut_in.vigi_pb_ch2_s          <= '1';
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.9",
         "Check if the 'Vigilance Push Button' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(0) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.10",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_1_GREEN_BIT,  '0', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_1_RED_BIT,    '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.11",
         "Set logic level '0' on signal vigi_pb_chX_i");

      uut_in.vigi_pb_ch1_s          <= '0';
      uut_in.vigi_pb_ch2_s          <= '0';
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.12",
         "Check if the 'Vigilance Push Button' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(0) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.13",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_1_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_1_BIT,'1', alarm_code_i);
      Report_LED_IF  ("-", C_LED_DI_1_GREEN_BIT,  '0', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_1_RED_BIT,    '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("2.14", TRUE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.15");


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "For Digital Input 3 - Zero Speed - do:");

      -- Level sensitive 
      -- Logic Polarity           = Active High
      -- Max Activity Period      = N/A
      -- Activity Time-Out        = N/A
      -- Max Consecutive Events   = N/A

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1",
         "Set logic level '1' on signal zero_spd_chX_i");

      uut_in.zero_spd_ch1_s         <= '1'; 
      uut_in.zero_spd_ch2_s         <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2",
         "Check if the 'Zero Speed' event was generated (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(1) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_3_GREEN_BIT,  '1', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_3_RED_BIT,    '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4",
         "Set logic level '0' on signal zero_spd_chX_i");

      uut_in.zero_spd_ch1_s         <= '0'; 
      uut_in.zero_spd_ch2_s         <= '0'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5",
         "Check if the 'Zero Speed' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.6",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_3_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_3_BIT,'0', alarm_code_i);
      Report_LED_IF  ("-", C_LED_DI_3_GREEN_BIT,  '0', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_3_RED_BIT,    '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.7",
         "Force a fault on both CH1 and CH2 and wait for a self-test on both CH1 and CH2");

      -- @See simulation\testbench\hcmt_cpld_top_tb.vhd
      st_ch1_in_ctrl_s(2)  <= TEST_FAIL_HIGH;
      st_ch2_in_ctrl_s(2)  <= TEST_FAIL_LOW;

      WAIT UNTIL falling_edge(uut_out.test_low_ch1_s);    -- End of the CH1 self-test
      WAIT UNTIL falling_edge(uut_out.test_low_ch2_s);    -- End of the CH2 self-test
      WAIT UNTIL falling_edge(x_selftest_in_progress_s);  -- End of self-test routine

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.8",
         "Set logic level '1' on signal zero_spd_chX_i");

      uut_in.zero_spd_ch1_s         <= '1'; 
      uut_in.zero_spd_ch2_s         <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.9",
         "Check if the 'Zero Speed' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.10",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_3_GREEN_BIT,  '0', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_3_RED_BIT,    '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.11",
         "Set logic level '0' on signal zero_spd_chX_i");

      uut_in.zero_spd_ch1_s         <= '0'; 
      uut_in.zero_spd_ch2_s         <= '0'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.12",
         "Check if the 'Zero Speed' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.13",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_3_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_3_BIT,'1', alarm_code_i);
      Report_LED_IF  ("-", C_LED_DI_3_GREEN_BIT,  '0', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_3_RED_BIT,    '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("3.14", TRUE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.15");


      --==============
      -- Step 4
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------------#");
      tfy_wr_step( report_file, now, "4",
         "For Digital Input 4 - CBTC HCS Mode - do:");

      -- Level sensitive 
      -- Logic Polarity           = Active High
      -- Max Activity Period      = N/A
      -- Activity Time-Out        = N/A
      -- Max Consecutive Events   = N/A

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1",
         "Set logic level '1' on signal hcs_mode_chX_i");

      uut_in.hcs_mode_ch1_s         <= '1'; 
      uut_in.hcs_mode_ch2_s         <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2",
         "Check if the 'CBTC HCS Mode' event was generated (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(2) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_4_GREEN_BIT,  '1', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_4_RED_BIT,    '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4",
         "Set logic level '0' on signal hcs_mode_chX_i");

      uut_in.hcs_mode_ch1_s         <= '0'; 
      uut_in.hcs_mode_ch2_s         <= '0'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5",
         "Check if the 'CBTC HCS Mode' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(2) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.6",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_4_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_4_BIT,'0', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_4_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_4_RED_BIT,     '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.7",
         "Force a fault on both CH1 and CH2 and wait for a self-test on both CH1 and CH2");

      -- @See simulation\testbench\hcmt_cpld_top_tb.vhd
      st_ch1_in_ctrl_s(3)  <= TEST_FAIL_HIGH;
      st_ch2_in_ctrl_s(3)  <= TEST_FAIL_LOW;
      

      WAIT UNTIL falling_edge(uut_out.test_low_ch1_s);    -- End of the CH1 self-test
      WAIT UNTIL falling_edge(uut_out.test_low_ch2_s);    -- End of the CH2 self-test
      WAIT UNTIL falling_edge(x_selftest_in_progress_s);  -- End of self-test routine

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.8",
         "Set logic level '1' on signal hcs_mode_chX_i");

      uut_in.hcs_mode_ch1_s         <= '1'; 
      uut_in.hcs_mode_ch2_s         <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.9",
         "Check if the 'CBTC HCS Mode' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(2) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.10",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_4_GREEN_BIT,  '0', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_4_RED_BIT,    '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.11",
         "Set logic level '0' on signal hcs_mode_chX_i");

      uut_in.hcs_mode_ch1_s         <= '0'; 
      uut_in.hcs_mode_ch2_s         <= '0'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.12",
         "Check if the 'CBTC HCS Mode' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(2) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.13",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_4_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_4_BIT,'1', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_4_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_4_RED_BIT,     '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("4.14", TRUE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.15");


      --==============
      -- Step 5
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5: -------------------------------------------#");
      tfy_wr_step( report_file, now, "5",
         "For Digital Input 5 - BCP > 75% - do:");

      -- Level sensitive 
      -- Logic Polarity           = Active High
      -- Max Activity Period      = N/A
      -- Activity Time-Out        = N/A
      -- Max Consecutive Events   = N/A

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1",
         "Set logic level '1' on signal bcp_75_chX_i");

      uut_in.bcp_75_ch1_s           <= '1'; 
      uut_in.bcp_75_ch2_s           <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2",
         "Check if the 'BCP > 75%' event was generated (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(3) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_5_GREEN_BIT,  '1', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_5_RED_BIT,    '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4",
         "Set logic level '0' on signal bcp_75_chX_i");

      uut_in.bcp_75_ch1_s           <= '0'; 
      uut_in.bcp_75_ch2_s           <= '0'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5",
         "Check if the 'BCP > 75%' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(3) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.6",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_5_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_5_BIT,'0', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_5_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_5_RED_BIT,     '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.7",
         "Force a fault on both CH1 and CH2 and wait for a self-test on both CH1 and CH2");

      -- @See simulation\testbench\hcmt_cpld_top_tb.vhd
      st_ch1_in_ctrl_s(4)  <= TEST_FAIL_HIGH;
      st_ch2_in_ctrl_s(4)  <= TEST_FAIL_LOW;

      WAIT UNTIL falling_edge(uut_out.test_low_ch1_s);    -- End of the CH1 self-test
      WAIT UNTIL falling_edge(uut_out.test_low_ch2_s);    -- End of the CH2 self-test
      WAIT UNTIL falling_edge(x_selftest_in_progress_s);  -- End of self-test routine

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.8",
         "Set logic level '1' on signal bcp_75_chX_i");

      uut_in.bcp_75_ch1_s           <= '1'; 
      uut_in.bcp_75_ch2_s           <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.9",
         "Check if the 'BCP > 75%' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(3) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.10",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_5_GREEN_BIT,  '0', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_5_RED_BIT,    '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.11",
         "Set logic level '0' on signal bcp_75_chX_i");

      uut_in.bcp_75_ch1_s           <= '0'; 
      uut_in.bcp_75_ch2_s           <= '0'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.12",
         "Check if the 'BCP > 75%' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(3) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.13",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_5_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_5_BIT,'1', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_5_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_5_RED_BIT,     '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("5.14", TRUE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.15");


      --==============
      -- Step 6
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6: -------------------------------------------#");
      tfy_wr_step( report_file, now, "6",
         "For Digital Input 6 - Not Isolated - do:");

      -- Level sensitive 
      -- Logic Polarity           = Active Low
      -- Max Activity Period      = N/A
      -- Activity Time-Out        = N/A
      -- Max Consecutive Events   = N/A

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1",
         "Set logic level '1' on signal not_isol_chX_i");

      uut_in.not_isol_ch1_s         <= '1'; 
      uut_in.not_isol_ch2_s         <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2",
         "Check if the 'Not Isolated' event was generated (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(4) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_6_GREEN_BIT,  '1', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_6_RED_BIT,    '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4",
         "Set logic level '0' on signal not_isol_chX_i");

      uut_in.not_isol_ch1_s         <= '0'; 
      uut_in.not_isol_ch2_s         <= '0'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.5",
         "Check if the 'Not Isolated' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(4) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.6",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_6_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_6_BIT,'0', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_6_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_6_RED_BIT,     '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.7",
         "Force a fault on both CH1 and CH2 and wait for a self-test on both CH1 and CH2");

      -- @See simulation\testbench\hcmt_cpld_top_tb.vhd
      st_ch1_in_ctrl_s(5)  <= TEST_FAIL_HIGH;
      st_ch2_in_ctrl_s(5)  <= TEST_FAIL_LOW;

      WAIT UNTIL falling_edge(uut_out.test_low_ch1_s);    -- End of the CH1 self-test
      WAIT UNTIL falling_edge(uut_out.test_low_ch2_s);    -- End of the CH2 self-test
      WAIT UNTIL falling_edge(x_selftest_in_progress_s);  -- End of self-test routine

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.8",
         "Set logic level '1' on signal not_isol_chX_i");

      uut_in.not_isol_ch1_s         <= '1'; 
      uut_in.not_isol_ch2_s         <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.9",
         "Check if the 'Not Isolated' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(4) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.10",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_6_GREEN_BIT,  '0', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_6_RED_BIT,    '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.11",
         "Set logic level '0' on signal not_isol_chX_i");

      uut_in.not_isol_ch1_s         <= '0'; 
      uut_in.not_isol_ch2_s         <= '0'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.12",
         "Check if the 'Not Isolated' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(4) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.13",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_6_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_6_BIT,'1', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_6_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_6_RED_BIT,     '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("6.14", TRUE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("6.15");


      --==============
      -- Step 7
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 7: -------------------------------------------#");
      tfy_wr_step( report_file, now, "7",
         "For Digital Input 7 - Cab Active - do:");

      -- Level sensitive 
      -- Logic Polarity           = Active Low
      -- Max Activity Period      = N/A
      -- Activity Time-Out        = N/A
      -- Max Consecutive Events   = N/A

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.1",
         "Set logic level '1' on signal cab_act_chX_i");

      uut_in.cab_act_ch1_s          <= '1';
      uut_in.cab_act_ch2_s          <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.2",
         "Check if the 'Cab Active' event was generated (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(5) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.3",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_7_GREEN_BIT,  '1', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_7_RED_BIT,    '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.4",
         "Set logic level '0' on signal cab_act_chX_i");

      uut_in.cab_act_ch1_s          <= '0'; 
      uut_in.cab_act_ch2_s          <= '0'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.5",
         "Check if the 'Cab Active' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(5) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.6",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_7_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_7_BIT,'0', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_7_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_7_RED_BIT,     '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.7",
         "Force a fault on both CH1 and CH2 and wait for a self-test on both CH1 and CH2");

      -- @See simulation\testbench\hcmt_cpld_top_tb.vhd
      st_ch1_in_ctrl_s(6)  <= TEST_FAIL_HIGH;
      st_ch2_in_ctrl_s(6)  <= TEST_FAIL_LOW;

      WAIT UNTIL falling_edge(uut_out.test_low_ch1_s);    -- End of the CH1 self-test
      WAIT UNTIL falling_edge(uut_out.test_low_ch2_s);    -- End of the CH2 self-test
      WAIT UNTIL falling_edge(x_selftest_in_progress_s);  -- End of self-test routine

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.8",
         "Set logic level '1' on signal cab_act_chX_i");

      uut_in.cab_act_ch1_s          <= '1';
      uut_in.cab_act_ch2_s          <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.9",
         "Check if the 'Cab Active' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(5) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.10",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_7_GREEN_BIT,  '0', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_7_RED_BIT,    '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.11",
         "Set logic level '0' on signal cab_act_chX_i");

      uut_in.cab_act_ch1_s          <= '0'; 
      uut_in.cab_act_ch2_s          <= '0'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.12",
         "Check if the 'Cab Active' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(5) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.13",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_7_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_7_BIT,'1', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_7_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_7_RED_BIT,     '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("7.14", TRUE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("7.15");


      -- ==============
      -- Step 8
      -- ==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 8: -------------------------------------------#");
      tfy_wr_step( report_file, now, "8",
         "For Digital Input 8 - Driver Override Input - do:");

      -- Rising then falling 
      -- Logic Polarity           = Active High
      -- Max Activity Period      = 1.5 sec
      -- Activity Time-Out        = N/A
      -- Max Consecutive Events   = N/A

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.1",
         "Set logic level '1' on signal spd_lim_override_chX_i");

      uut_in.spd_lim_override_ch1_s <= '1'; 
      uut_in.spd_lim_override_ch2_s <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.2",
         "Check if the 'Driver Override' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(6) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.3",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_8_GREEN_BIT,  '1', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_8_RED_BIT,    '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.4",
         "Set logic level '0' on signal spd_lim_override_chX_i");

      uut_in.spd_lim_override_ch1_s <= '0'; 
      uut_in.spd_lim_override_ch2_s <= '0'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.5",
         "Check if the 'Driver Override' event was generated (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(6) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.6",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_8_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_8_BIT,'0', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_8_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_8_RED_BIT,     '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.7",
         "Force a fault on both CH1 and CH2 and wait for a self-test on both CH1 and CH2");

      -- @See simulation\testbench\hcmt_cpld_top_tb.vhd
      st_ch1_in_ctrl_s(7)  <= TEST_FAIL_HIGH;
      st_ch2_in_ctrl_s(7)  <= TEST_FAIL_LOW;

      WAIT UNTIL falling_edge(uut_out.test_low_ch1_s);    -- End of the CH1 self-test
      WAIT UNTIL falling_edge(uut_out.test_low_ch2_s);    -- End of the CH2 self-test
      WAIT UNTIL falling_edge(x_selftest_in_progress_s);  -- End of self-test routine

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.8",
         "Set logic level '1' on signal spd_lim_override_chX_i");

      uut_in.spd_lim_override_ch1_s <= '1'; 
      uut_in.spd_lim_override_ch2_s <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.9",
         "Check if the 'Driver Override' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(6) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.10",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_8_GREEN_BIT,  '0', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_8_RED_BIT,    '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.11",
         "Set logic level '0' on signal spd_lim_override_chX_i");

      uut_in.spd_lim_override_ch1_s <= '0'; 
      uut_in.spd_lim_override_ch2_s <= '0'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.12",
         "Check if the 'Driver Override' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(6) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.13",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_8_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_8_BIT,'1', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_8_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_8_RED_BIT,     '1', led_code_i);


      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("8.14", TRUE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("8.14");


      --==============
      -- Step 9
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 9: -------------------------------------------#");
      tfy_wr_step( report_file, now, "9",
         "For Digital Input 9 - Driverless - do:");

      -- Level sensitive 
      -- Logic Polarity           = Active High
      -- Max Activity Period      = N/A
      -- Activity Time-Out        = N/A
      -- Max Consecutive Events   = N/A

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.1",
         "Set logic level '1' on signal driverless_chX_i");

      uut_in.driverless_ch1_s       <= '1'; 
      uut_in.driverless_ch2_s       <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.2",
         "Check if the 'Driverless' event was generated (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(7) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.3",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_9_GREEN_BIT,  '1', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_9_RED_BIT,    '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.4",
         "Set logic level '0' on signal driverless_chX_i");

      uut_in.driverless_ch1_s       <= '0'; 
      uut_in.driverless_ch2_s       <= '0'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.5",
         "Check if the 'Driverless' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(7) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.6",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_9_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_9_BIT,'0', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_9_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_9_RED_BIT,     '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.7",
         "Force a fault on both CH1 and CH2 and wait for a self-test on both CH1 and CH2");

      -- @See simulation\testbench\hcmt_cpld_top_tb.vhd
      st_ch1_in_ctrl_s(8)  <= TEST_FAIL_HIGH;
      st_ch2_in_ctrl_s(8)  <= TEST_FAIL_LOW;

      WAIT UNTIL falling_edge(uut_out.test_low_ch1_s);    -- End of the CH1 self-test
      WAIT UNTIL falling_edge(uut_out.test_low_ch2_s);    -- End of the CH2 self-test
      WAIT UNTIL falling_edge(x_selftest_in_progress_s);  -- End of self-test routine

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.8",
         "Set logic level '1' on signal driverless_chX_i");

      uut_in.driverless_ch1_s       <= '1'; 
      uut_in.driverless_ch2_s       <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.9",
         "Check if the 'Driverless' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(7) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.10",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_9_GREEN_BIT,  '0', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_9_RED_BIT,    '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.11",
         "Set logic level '0' on signal driverless_chX_i");

      uut_in.driverless_ch1_s       <= '0'; 
      uut_in.driverless_ch2_s       <= '0'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.12",
         "Check if the 'Driverless' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(7) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.13",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_9_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_9_BIT,'1', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_9_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_9_RED_BIT,     '1', led_code_i);


      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("9.14", TRUE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("9.15");


      -- ==============
      -- Step 10
      -- ==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 10: -------------------------------------------#");
      tfy_wr_step( report_file, now, "10",
         "For Digital Input 10 - Speed Limit Active - do:");

      -- Falling 
      -- Logic Polarity           = Active High
      -- Max Activity Period      = 200s
      -- Activity Time-Out        = N/A
      -- Max Consecutive Events   = N/A

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.1",
         "Set logic level '1' on signal spd_lim_chX_i");

      uut_in.spd_lim_ch1_s          <= '1'; 
      uut_in.spd_lim_ch2_s          <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.2",
         "Check if the 'Speed Limit Active' event was generated (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(8) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.3",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_10_GREEN_BIT,  '1', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_10_RED_BIT,    '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.4",
         "Set logic level '0' on signal spd_lim_chX_i");

      uut_in.spd_lim_ch1_s          <= '0'; 
      uut_in.spd_lim_ch2_s          <= '0'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.5",
         "Check if the 'Speed Limit Active' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(8) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.6",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_10_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_10_BIT,'0', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_10_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_10_RED_BIT,     '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.7",
         "Force a fault on both CH1 and CH2 and wait for a self-test on both CH1 and CH2");

      -- @See simulation\testbench\hcmt_cpld_top_tb.vhd
      st_ch1_in_ctrl_s(9)  <= TEST_FAIL_HIGH;
      st_ch2_in_ctrl_s(9)  <= TEST_FAIL_LOW;

      WAIT UNTIL falling_edge(uut_out.test_low_ch1_s);    -- End of the CH1 self-test
      WAIT UNTIL falling_edge(uut_out.test_low_ch2_s);    -- End of the CH2 self-test
      WAIT UNTIL falling_edge(x_selftest_in_progress_s);  -- End of self-test routine

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.8",
         "Set logic level '1' on signal spd_lim_chX_i");

      uut_in.spd_lim_ch1_s          <= '1'; 
      uut_in.spd_lim_ch2_s          <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.9",
         "Check if the 'Speed Limit Active' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(8) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.10",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_10_GREEN_BIT,  '0', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_10_RED_BIT,    '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.11",
         "Set logic level '0' on signal spd_lim_chX_i");

      uut_in.spd_lim_ch1_s          <= '0'; 
      uut_in.spd_lim_ch2_s          <= '0'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.12",
         "Check if the 'Speed Limit Active' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(8) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.13",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_10_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_10_BIT,'1', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_10_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_10_RED_BIT,     '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("10.14", TRUE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("10.15");


      --==============
      -- Step 11
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 11: -------------------------------------------#");
      tfy_wr_step( report_file, now, "11",
         "For Digital Input 11 - Horn Low - do:");

      -- Rising then falling 
      -- Logic Polarity           = Active High
      -- Max Activity Period      = 3 sec
      -- Activity Time-Out        = 10 sec
      -- Max Consecutive Events   = 8

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.1",
         "Set logic level '1' on signal horn_low_i");

      uut_in.horn_low_s             <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.2",
         "Check if the 'Horn Low' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => single_channel_event_latch_r(0) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.3",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_11_GREEN_BIT,  '1', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_11_RED_BIT,    '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.4",
         "Set logic level '0' on signal horn_low_i");

      uut_in.horn_low_s             <= '0';  
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.5",
         "Check if the 'Horn Low' event was generated (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => single_channel_event_latch_r(0) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.6",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_11_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_11_BIT,'0', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_11_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_11_RED_BIT,     '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.7",
         "Force a fault on CH1 and wait for a self-test on CH1");

      -- @See simulation\testbench\hcmt_cpld_top_tb.vhd
      st_ch1_in_ctrl_s(10) <= TEST_FAIL_LOW;

      WAIT UNTIL falling_edge(uut_out.test_low_ch1_s);    -- End of the CH1 self-test
      WAIT UNTIL falling_edge(x_selftest_in_progress_s);  -- End of self-test routine

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.8",
         "Set logic level '1' on signal horn_low_i");

      uut_in.horn_low_s             <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.9",
         "Check if the 'Horn Low' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => single_channel_event_latch_r(0) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.10",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_11_GREEN_BIT,  '0', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_11_RED_BIT,    '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.11",
         "Set logic level '0' on signal horn_low_i");

      uut_in.horn_low_s             <= '0';  
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.12",
         "Check if the 'Horn Low' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => single_channel_event_latch_r(0) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.3",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_11_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_11_BIT,'0', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_11_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_11_RED_BIT,     '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("11.14", TRUE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("11.15");


      --==============
      -- Step 12
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 12: -------------------------------------------#");
      tfy_wr_step( report_file, now, "12",
         "For Digital Input 12 - Horn High - do:");

      -- Rising then falling 
      -- Logic Polarity           = Active High
      -- Max Activity Period      = 3 sec
      -- Activity Time-Out        = 10 sec
      -- Max Consecutive Events   = 8

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.1",
         "Set logic level '1' on signal horn_high_i");

      uut_in.horn_high_s            <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.2",
         "Check if the 'Horn High' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => single_channel_event_latch_r(1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.3",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_12_GREEN_BIT,  '1', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_12_RED_BIT,    '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.4",
         "Set logic level '0' on signal horn_high_i");

      uut_in.horn_high_s            <= '0';  
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.5",
         "Check if the 'Horn High' event was generated (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => single_channel_event_latch_r(1) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.6",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_12_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_12_BIT,'0', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_12_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_12_RED_BIT,     '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.7",
         "Force a fault on CH1 and wait for a self-test on CH1");

      -- @See simulation\testbench\hcmt_cpld_top_tb.vhd
      st_ch1_in_ctrl_s(11) <= TEST_FAIL_LOW;

      WAIT UNTIL falling_edge(uut_out.test_low_ch1_s);    -- End of the CH1 self-test
      WAIT UNTIL falling_edge(x_selftest_in_progress_s);  -- End of self-test routine

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.8",
         "Set logic level '1' on signal horn_high_i");

      uut_in.horn_high_s            <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.9",
         "Check if the 'Horn High' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => single_channel_event_latch_r(1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.10",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_12_GREEN_BIT,  '0', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_12_RED_BIT,    '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.11",
         "Set logic level '0' on signal horn_high_i");

      uut_in.horn_high_s            <= '0';  
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.12",
         "Check if the 'Horn High' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => single_channel_event_latch_r(1) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.13",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_12_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_12_BIT,'0', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_12_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_12_RED_BIT,     '1', led_code_i);


      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("12.14", TRUE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("12.15");


      --==============
      -- Step 13
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 13: -------------------------------------------#");
      tfy_wr_step( report_file, now, "13",
         "For Digital Input 13 - Headlight Low - do:");

      -- Rising or falling 
      -- Logic Polarity           = N/A
      -- Max Activity Period      = N/A
      -- Activity Time-Out        = 5 sec
      -- Max Consecutive Events   = 1

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.1",
         "Set logic level '1' on signal hl_low_i");

      uut_in.hl_low_s               <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.2",
         "Check if the 'Headlight Low' event was generated (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => single_channel_event_latch_r(2) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.3",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_13_GREEN_BIT,  '1', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_13_RED_BIT,    '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.4",
         "Set logic level '0' on signal hl_low_i");

      uut_in.hl_low_s               <= '0';
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.5",
         "Check if the 'Headlight Low' event was generated (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => single_channel_event_latch_r(2) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.6",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_13_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_13_BIT,'0', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_13_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_13_RED_BIT,     '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.7",
         "Force a fault on CH1 and wait for a self-test on CH1");

      -- @See simulation\testbench\hcmt_cpld_top_tb.vhd
      st_ch1_in_ctrl_s(12) <= TEST_FAIL_LOW;

      WAIT UNTIL falling_edge(uut_out.test_low_ch1_s);    -- End of the CH1 self-test
      WAIT UNTIL falling_edge(x_selftest_in_progress_s);  -- End of self-test routine

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.8",
         "Set logic level '1' on signal hl_low_i");

      uut_in.hl_low_s               <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.9",
         "Check if the 'Headlight Low' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => single_channel_event_latch_r(2) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.10",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_13_GREEN_BIT,  '0', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_13_RED_BIT,    '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.11",
         "Set logic level '0' on signal hl_low_i");

      uut_in.hl_low_s               <= '0';
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.12",
         "Check if the 'Headlight Low' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => single_channel_event_latch_r(2) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.13",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_13_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_13_BIT,'0', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_13_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_13_RED_BIT,     '1', led_code_i);


      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("13.14", TRUE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("13.15");


      --==============
      -- Step 14
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 14: -------------------------------------------#");
      tfy_wr_step( report_file, now, "14",
         "For Digital Input 15 - Washer wiper switch - do:");

      -- Rising or falling 
      -- Logic Polarity           = N/A
      -- Max Activity Period      = N/A
      -- Activity Time-Out        = 10 sec
      -- Max Consecutive Events   = 8

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.1",
         "Set logic level '1' on signal w_wiper_pb_i");

      uut_in.w_wiper_pb_s           <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.2",
         "Check if the 'Washer wiper switch' event was generated (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => single_channel_event_latch_r(3) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.3",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_15_GREEN_BIT,  '1', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_15_RED_BIT,    '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.4",
         "Set logic level '0' on signal w_wiper_pb_i");

      uut_in.w_wiper_pb_s           <= '0';
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.5",
         "Check if the 'Washer wiper switch' event was generated (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => single_channel_event_latch_r(3) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.6",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_15_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_15_BIT,'0', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_15_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_15_RED_BIT,     '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.7",
         "Force a fault on CH1 and wait for a self-test on CH1");

      -- @See simulation\testbench\hcmt_cpld_top_tb.vhd
      st_ch1_in_ctrl_s(14) <= TEST_FAIL_LOW;

      WAIT UNTIL falling_edge(uut_out.test_low_ch1_s);    -- End of the CH1 self-test
      WAIT UNTIL falling_edge(x_selftest_in_progress_s);  -- End of self-test routine

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.8",
         "Set logic level '1' on signal w_wiper_pb_i");

      uut_in.w_wiper_pb_s           <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.9",
         "Check if the 'Washer wiper switch' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => single_channel_event_latch_r(3) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.10",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_15_GREEN_BIT,  '0', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_15_RED_BIT,    '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.11",
         "Set logic level '0' on signal w_wiper_pb_i");

      uut_in.w_wiper_pb_s           <= '0';
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.12",
         "Check if the 'Washer wiper switch' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => single_channel_event_latch_r(3) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.13",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_15_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_15_BIT,'0', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_15_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_15_RED_BIT,     '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("14.14", TRUE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("14.15");


      --==============
      -- Step 15
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 15: -------------------------------------------#");
      tfy_wr_step( report_file, now, "15",
         "For Digital Input 17 - Safety system bypass push button - do:");

      -- Rising then falling 
      -- Logic Polarity           = Active High
      -- Max Activity Period      = 1.5 sec 
      -- Activity Time-Out        = 10 sec
      -- Max Consecutive Events   = 8

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.1",
         "Set logic level '1' on signal ss_bypass_pb_i");

      uut_in.ss_bypass_pb_s         <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.2",
         "Check if the 'Safety system bypass push button' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => single_channel_event_latch_r(4) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.3",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_17_GREEN_BIT,  '1', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_17_RED_BIT,    '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.4",
         "Set logic level '0' on signal ss_bypass_pb_i");

      uut_in.ss_bypass_pb_s         <= '0';  
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.5",
         "Check if the 'Safety system bypass push button' event was generated (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => single_channel_event_latch_r(4) = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.6",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_17_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_17_BIT,'0', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_17_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_17_RED_BIT,     '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.7",
         "Force a fault on CH1 and wait for a self-test on CH1");

      -- @See simulation\testbench\hcmt_cpld_top_tb.vhd
      st_ch1_in_ctrl_s(16) <= TEST_FAIL_LOW;

      WAIT UNTIL falling_edge(uut_out.test_low_ch1_s);    -- End of the CH1 self-test
      WAIT UNTIL falling_edge(x_selftest_in_progress_s);  -- End of self-test routine

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.8",
         "Set logic level '1' on signal ss_bypass_pb_i");

      uut_in.ss_bypass_pb_s         <= '1'; 
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.9",
         "Check if the 'Safety system bypass push button' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => single_channel_event_latch_r(4) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.10",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_LED_IF  ("-", C_LED_DI_17_GREEN_BIT,  '0', led_code_i);
      Report_LED_IF  ("-", C_LED_DI_17_RED_BIT,    '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.11",
         "Set logic level '0' on signal ss_bypass_pb_i");

      uut_in.ss_bypass_pb_s         <= '0';  
      WAIT FOR 157 ms; -- +156ms debounce

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.12",
         "Check if the 'Safety system bypass push button' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => single_channel_event_latch_r(4) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.13",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_17_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_17_BIT,'0', alarm_code_i);
      Report_LED_IF ("-", C_LED_DI_17_GREEN_BIT,   '0', led_code_i);
      Report_LED_IF ("-", C_LED_DI_17_RED_BIT,     '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("15.14", TRUE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("15.15");



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
         tc_name        => "TC_RS016_023_027_012_188",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "03 Dec 2019",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s    
      );

   END PROCESS p_steps;

    p_event_latch: PROCESS(event_latch_rst_r, x_dual_channel_event, x_single_channel_event)
    BEGIN
        IF rising_edge(event_latch_rst_r) THEN
            dual_channel_event_latch_r <= (OTHERS => '0');
            single_channel_event_latch_r <= (OTHERS => '0');
        ELSE
            IF rising_edge(x_dual_channel_event(0)) THEN -- vigi_pb_event_o
                dual_channel_event_latch_r(0) <= x_dual_channel_event(0);
            END IF;

            IF rising_edge(x_dual_channel_event(1)) THEN -- zero_spd_event_o
                dual_channel_event_latch_r(1) <= x_dual_channel_event(1);
            END IF;

            IF rising_edge(x_dual_channel_event(2)) THEN -- hcs_mode_event_o
                dual_channel_event_latch_r(2) <= x_dual_channel_event(2);
            END IF;

            IF rising_edge(x_dual_channel_event(3)) THEN -- bcp_75_event_o
                dual_channel_event_latch_r(3) <= x_dual_channel_event(3);
            END IF;

            IF rising_edge(x_dual_channel_event(4)) THEN -- not_isol_event_o
                dual_channel_event_latch_r(4) <= x_dual_channel_event(4);
            END IF;

            IF rising_edge(x_dual_channel_event(5)) THEN -- cab_act_event_o
                dual_channel_event_latch_r(5) <= x_dual_channel_event(5);
            END IF;

            IF rising_edge(x_dual_channel_event(6)) THEN -- spd_lim_override_event_o
                dual_channel_event_latch_r(6) <= x_dual_channel_event(6);
            END IF;

            IF rising_edge(x_dual_channel_event(7)) THEN -- driverless_event_o
                dual_channel_event_latch_r(7) <= x_dual_channel_event(7);
            END IF;

            IF rising_edge(x_dual_channel_event(8)) THEN -- spd_lim_event_o
                dual_channel_event_latch_r(8) <= x_dual_channel_event(8);
            END IF;

            IF rising_edge(x_single_channel_event(0)) THEN -- horn_low_pre_event_s
                single_channel_event_latch_r(0) <= x_single_channel_event(0);
            END IF;

            IF rising_edge(x_single_channel_event(1)) THEN -- horn_high_pre_event_s
                single_channel_event_latch_r(1) <= x_single_channel_event(1);
            END IF;

            IF rising_edge(x_single_channel_event(2)) THEN -- hl_low_pre_event_s
                single_channel_event_latch_r(2) <= x_single_channel_event(2);
            END IF;

            IF rising_edge(x_single_channel_event(3)) THEN -- w_wiper_pb_pre_event_s
                single_channel_event_latch_r(3) <= x_single_channel_event(3);
            END IF;

            IF rising_edge(x_single_channel_event(4)) THEN -- ss_bypass_pb_pre_event_s
                single_channel_event_latch_r(4) <= x_single_channel_event(4);
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

END ARCHITECTURE TC_RS016_023_027_012_188;

