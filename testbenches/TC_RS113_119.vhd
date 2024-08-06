-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS113_119
-- Module      : VCU Timing System
-- Revision    : 2.0
-- Date        : 23 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Test if all self-test and fault detection operations continue as normal while in OpMode NORMAL and DEPRESSED
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-113
--    FPGA-REQ-119
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 28 Mar 2018
--    - J.Sousa (1.0): Initial Release
-- Revision 1.1 - 29 Aug 2018
--    - CABelchior (1.1): CCN2
-- Revision 1.2 - 07 Jun 2019
--    - VSA (1.0): CCN03 changes
-- Revision 2.0 - 23 Dec 2019
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- Notes:
--
-- sim -tc TC_RS113_119 -numstdoff -nocov
-- log -r /*
--
-- 113   The following constraints shall be applied to Depressed Operating Mode:
--       - All vigilance timers are running;
--       - All self-test and fault detection operations continue as normal;
--       - Penalty brake applications are NOT allowed;
--
-- 119   The following constraints shall be applicable to Normal Operating Mode:
--       - All vigilance timers are running;
--       - All self-test and fault detection operations continue as normal
--       - Penalty applications ARE allowed;
--
-- Testcase Steps:
-- Step 2: Check that while in OpMode NORMAL, faults detection continue as normal
-- Step 3: After an UUT Reset, force the transit from OpMode NORMAL to DEPRESSED
-- Step 4: Check that while in OpMode DEPRESSED, faults detection continue as normal
--
-- @See 3.4.5.6.1. OPERATION <CSW-ARTHCMT-2018-SAS-01166-software_architecture_design_and_interface_specification_CCN04>
--    The VCU Timing FSM block interprets all inputs fed by the Analog IF to perform actions over the HCMT CPLD outputs 
--    depending on the current operation mode fed by the Operation Mode FSM block. The block implements a centralized timer, 
--    hereafter denoted as VCU Timer, that is initialized with the counter values necessary by specific states. 
-----------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;

ARCHITECTURE TC_RS113_119 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------

   CONSTANT C_TIMER_DEFAULT                       : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(89999, 17);   -- 45s timer
   CONSTANT C_DEBOUNCE_PERIOD                     : TIME := 500 us;
   CONSTANT C_SETTLING_PERIOD                     : TIME := 500 us;
   CONSTANT C_TOLERANCE_PERIOD                    : TIME :=  10 us;
   CONSTANT C_SELF_TEST_PERIOD                    : TIME := 500 ms;

   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------

   SIGNAL x_selftest_in_progress_s                : STD_LOGIC := '0';

   -- Top-Level of the VCU Timing System HLB
   SIGNAL x_pulse500us_i                          : STD_LOGIC;      -- Internal 500us synch pulse
   SIGNAL x_hcs_mode_i                            : STD_LOGIC;      -- Communication-based train control (sets VCU in depressed mode)

   --  VCU Timing System HLB » Outputs
   SIGNAL x_opmode_mft_o                          : STD_LOGIC;     -- Notify Major Fault opmode
   SIGNAL x_opmode_tst_o                          : STD_LOGIC;     -- Notify Test opmode
   SIGNAL x_opmode_dep_o                          : STD_LOGIC;     -- Notify Depression opmode
   SIGNAL x_opmode_sup_o                          : STD_LOGIC;     -- Notify Suppression opmode
   SIGNAL x_opmode_nrm_o                          : STD_LOGIC;     -- Notify Normal opmode

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
   SIGNAL major_flt_report_s                      : STD_LOGIC := '0';
   
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
            "Set analog speed to [90 - 110 km/h]");
         Set_Speed_Cases(6);               -- Analog Speed -> 90 - 110 km/h

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
         report_fname   => "TC_RS113_119.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS113_119",
         test_module    => "VCU Timing System",
         tc_revision    => "2.0",
         tc_date        => "23 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Test if all self-test and fault detection operations continue as normal while in OpMode NORMAL and DEPRESSED",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_top_tb",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s
      );

      --------------------------------------------------------
      -- Link Spy Probes
      --------------------------------------------------------
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/selftest_in_progress_s", "x_selftest_in_progress_s", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/pulse500us_i", "x_pulse500us_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/hcs_mode_i",   "x_hcs_mode_i", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_mft_o", "x_opmode_mft_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_tst_o", "x_opmode_tst_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_dep_o", "x_opmode_dep_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_sup_o", "x_opmode_sup_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_nrm_o", "x_opmode_nrm_o", 0);

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


      --==============
      -- Step 2
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2: -------------------------------------------#");
      tfy_wr_step( report_file, now, "2",
         "Check that while in OpMode NORMAL, faults detection continue as normal");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "Check if the VCU is in the OpMode NORMAL (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_opmode_mft_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_tst_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_dep_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_sup_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_nrm_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      -- vigi_pb_chX_i
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_1_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_1_BIT,'0', alarm_code_i);
      Report_LED_IF  ("-", C_LED_DI_1_RED_BIT,    '0', led_code_i);

      -- penaltyX_out_o
      Report_Diag_IF ("-", C_DIAG_PEN_1_FAULT_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PEN_2_FAULT_BIT,'0', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PEN_1_RED_BIT,   '0', led_code_i);
      Report_LED_IF  ("-", C_LED_PEN_2_RED_BIT,   '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("2.3", FALSE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Report_Major_Fault("2.4", FALSE, major_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5",
         "Force a fault on vigi_pb_chX_i and wait for a self-test on both CH1 and CH2");

      -- @See simulation\testbench\hcmt_cpld_top_tb.vhd
      st_ch1_in_ctrl_s(0)  <= TEST_FAIL_HIGH;
      st_ch2_in_ctrl_s(0)  <= TEST_FAIL_LOW;

      WAIT UNTIL falling_edge(uut_out.test_low_ch1_s);    -- End of the CH1 self-test
      WAIT UNTIL falling_edge(uut_out.test_low_ch2_s);    -- End of the CH2 self-test
      WAIT UNTIL falling_edge(x_selftest_in_progress_s);  -- End of self-test routine

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.6",
         "Check if the VCU is in the OpMode NORMAL (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_opmode_mft_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_tst_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_dep_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_sup_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_nrm_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.7",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      -- vigi_pb_chX_i
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_1_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_1_BIT,'1', alarm_code_i);
      Report_LED_IF  ("-", C_LED_DI_1_RED_BIT,    '1', led_code_i);

      -- penaltyX_out_o
      Report_Diag_IF ("-", C_DIAG_PEN_1_FAULT_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PEN_2_FAULT_BIT,'0', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PEN_1_RED_BIT,   '0', led_code_i);
      Report_LED_IF  ("-", C_LED_PEN_2_RED_BIT,   '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("2.8", TRUE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Report_Major_Fault("2.9", FALSE, major_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.10",
         "Force a fault on feedback signals for Penalty Brake 1");

      fb_func_model_behaviour(PENALTY1_FB) <= FEEDBACK_FAIL;
      WAIT FOR 150 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.11",
         "Check if the VCU is in the OpMode NORMAL (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_opmode_mft_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_tst_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_dep_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_sup_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_nrm_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.12",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      -- vigi_pb_chX_i
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_1_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_1_BIT,'1', alarm_code_i);
      Report_LED_IF  ("-", C_LED_DI_1_RED_BIT,    '1', led_code_i);

      -- penaltyX_out_o
      Report_Diag_IF ("-", C_DIAG_PEN_1_FAULT_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PEN_2_FAULT_BIT,'0', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PEN_1_RED_BIT,   '1', led_code_i);
      Report_LED_IF  ("-", C_LED_PEN_2_RED_BIT,   '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("2.13", TRUE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Report_Major_Fault("2.14", TRUE, major_flt_report_s);
      WAIT FOR 1 ms;


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "After an UUT Reset, force the transit from OpMode NORMAL to DEPRESSED");

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.1");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2",
         "Set logic level '1' on signal hcs_mode_chX_i to force the transit from OpMode NORMAL to DEPRESSED");

      uut_in.hcs_mode_ch1_s         <= '1';
      uut_in.hcs_mode_ch2_s         <= '1';

      WAIT UNTIL x_hcs_mode_i = '1' FOR 200 ms;   -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);    -- for TMS output sync


      --==============
      -- Step 4
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------------#");
      tfy_wr_step( report_file, now, "4",
         "Check that while in OpMode DEPRESSED, faults detection continue as normal");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1",
         "Check if the VCU is in the OpMode NORMAL (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_opmode_mft_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_tst_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_dep_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_sup_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_nrm_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      -- vigi_pb_chX_i
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_1_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_1_BIT,'0', alarm_code_i);
      Report_LED_IF  ("-", C_LED_DI_1_RED_BIT,    '0', led_code_i);

      -- penaltyX_out_o
      Report_Diag_IF ("-", C_DIAG_PEN_1_FAULT_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PEN_2_FAULT_BIT,'0', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PEN_1_RED_BIT,   '0', led_code_i);
      Report_LED_IF  ("-", C_LED_PEN_2_RED_BIT,   '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("4.3", FALSE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Report_Major_Fault("4.4", FALSE, major_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5",
         "Force a fault on vigi_pb_chX_i and wait for a self-test on both CH1 and CH2");

      -- @See simulation\testbench\hcmt_cpld_top_tb.vhd
      st_ch1_in_ctrl_s(0)  <= TEST_FAIL_HIGH;
      st_ch2_in_ctrl_s(0)  <= TEST_FAIL_LOW;

      WAIT UNTIL falling_edge(uut_out.test_low_ch1_s);    -- End of the CH1 self-test
      WAIT UNTIL falling_edge(uut_out.test_low_ch2_s);    -- End of the CH2 self-test
      WAIT UNTIL falling_edge(x_selftest_in_progress_s);  -- End of self-test routine

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.6",
         "Check if the VCU is in the OpMode NORMAL (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_opmode_mft_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_tst_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_dep_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_sup_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_nrm_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.7",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      -- vigi_pb_chX_i
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_1_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_1_BIT,'1', alarm_code_i);
      Report_LED_IF  ("-", C_LED_DI_1_RED_BIT,    '1', led_code_i);

      -- penaltyX_out_o
      Report_Diag_IF ("-", C_DIAG_PEN_1_FAULT_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PEN_2_FAULT_BIT,'0', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PEN_1_RED_BIT,   '0', led_code_i);
      Report_LED_IF  ("-", C_LED_PEN_2_RED_BIT,   '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("4.8", TRUE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Report_Major_Fault("4.9", FALSE, major_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.10",
         "Force a fault on feedback signals for Penalty Brake 1");

      fb_func_model_behaviour(PENALTY1_FB) <= FEEDBACK_FAIL;
      WAIT FOR 150 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.11",
         "Check if the VCU is in the OpMode NORMAL (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_opmode_mft_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_tst_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_dep_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_sup_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_nrm_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.12",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      -- vigi_pb_chX_i
      Report_Diag_IF ("-", C_DIAG_CH1_INPUT_1_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_CH2_INPUT_1_BIT,'1', alarm_code_i);
      Report_LED_IF  ("-", C_LED_DI_1_RED_BIT,    '1', led_code_i);

      -- penaltyX_out_o
      Report_Diag_IF ("-", C_DIAG_PEN_1_FAULT_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PEN_2_FAULT_BIT,'0', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PEN_1_RED_BIT,   '1', led_code_i);
      Report_LED_IF  ("-", C_LED_PEN_2_RED_BIT,   '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("4.13", TRUE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Report_Major_Fault("4.14", TRUE, major_flt_report_s);
      WAIT FOR 1 ms;


      --------------------------------------------------------
      -- Testcase End Sequence
      --------------------------------------------------------

      tfy_tc_end(
         tc_pass        => pass,
         report_file    => report_file,
         tc_name        => "TC_RS113_119",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "23 Dec 2019",
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
END ARCHITECTURE TC_RS113_119;

