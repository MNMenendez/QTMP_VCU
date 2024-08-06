-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS103_104_183
-- Module      : VCU Timing System
-- Revision    : 2.0
-- Date        : 24 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Check Major Fault OpMode requirements complieance
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-103
--    FPGA-REQ-104
--    FPGA-REQ-183
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 27 Fev 2018
--    - J.Sousa (1.0): Initial Release
-- Revision 1.1 - 26 Apr 2019
--    - VSA (1.1): CCN03 changes
-- Revision 2.0 - 24 Dec 2019
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- Notes:
--
-- sim -tc TC_RS103_104_183 -numstdoff -nocov
-- log -r /*
--
-- 103   A major fault primarily captures a failure of the FPGA. The internally detectable major fault conditions are:
--       - Penalty brake relay 1 or 2 failed (Feedback not indicating expected state).
--
-- 104   The following constraints shall be applicable to Major Fault Operating Mode:
--       - All vigilance timers are stopped;
--       - Permanent penalty application.
--
-- 183   (...) The display minor fault and major fault pins should be driven high when their 
--       respective faults are found.
--
-- @See 3.4.5.6.1. OPERATION <CSW-ARTHCMT-2018-SAS-01166-software_architecture_design_and_interface_specification_CCN04>
--    The VCU Timing FSM block interprets all inputs fed by the Analog IF to perform actions over the HCMT CPLD outputs 
--    depending on the current operation mode fed by the Operation Mode FSM block. The block implements a centralized timer, 
--    hereafter denoted as VCU Timer, that is initialized with the counter values necessary by specific states. 
--
-- Aditional notes: 
-- ----------------------
-- minor_flt_report_s         <= tms_minor_fault_o AND disp_minor_fault_o;
-- major_flt_report_s         <= tms_major_fault_o AND disp_major_fault_o;
-----------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;

ARCHITECTURE TC_RS103_104_183 OF hcmt_cpld_tc_top IS

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

   SIGNAL x_vcut_curst_r                          : vcut_st_t;

   -- VCU Timing System FSM
   SIGNAL x_init_tmr_s                            : STD_LOGIC;             -- Initialize Timer (indicates the reset)
   SIGNAL x_timer_ctr_r                           : UNSIGNED(16 DOWNTO 0); -- Centralized VCU Timer » T1 | T2 | T3 | T4

   --  VCU Timing System HLB » Outputs
   SIGNAL x_penalty1_out_o                        : STD_LOGIC;     -- Penalty Brake 1
   SIGNAL x_penalty2_out_o                        : STD_LOGIC;     -- Penalty Brake 2

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
   SIGNAL prev_timer                              : UNSIGNED(16 DOWNTO 0);
   
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
         report_fname   => "TC_RS103_104_183.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS103_104_183",
         test_module    => "VCU Timing System",
         tc_revision    => "2.0",
         tc_date        => "24 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Check Major Fault OpMode requirements complieance",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_top_tb",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s
      );

      --------------------------------------------------------
      -- Link Spy Probes
      --------------------------------------------------------
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/vcut_curst_r", "x_vcut_curst_r", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/init_tmr_s",   "x_init_tmr_s", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/timer_ctr_r",  "x_timer_ctr_r", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/penalty1_out_o",  "x_penalty1_out_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/penalty2_out_o",  "x_penalty2_out_o", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_mft_o",    "x_opmode_mft_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_tst_o",    "x_opmode_tst_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_dep_o",    "x_opmode_dep_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_sup_o",    "x_opmode_sup_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_nrm_o",    "x_opmode_nrm_o", 0);

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
         "Test if the UUT transit to OpMode MFAULT after a Penalty Brake 1 Failure");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "Check if the VCU is in VCUT_NO_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NO_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2",
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
      tfy_wr_step( report_file, now, "2.3",
         "Check that the Timer was NOT frozen (Expected: TRUE)");

      prev_timer <= x_timer_ctr_r;
      WAIT FOR 50 ms;

      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4",
         "Check if the Penalty Brake are NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_penalty1_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_penalty2_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      -- OpModes
      Report_Diag_IF ("-", C_DIAG_VCU_MAJOR_FAULT_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_TEST_BIT,       '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_DEPRESSED_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_SUPPRESSED_BIT, '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_NORMAL_BIT,     '1', alarm_code_i);

      -- penaltyX_out_o
      Report_Diag_IF ("-", C_DIAG_VCU_PEN_BRAKE_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PEN_1_FAULT_BIT,    '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PEN_2_FAULT_BIT,    '0', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PEN_1_RED_BIT,       '0', led_code_i);
      Report_LED_IF  ("-", C_LED_PEN_2_RED_BIT,       '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("2.6", FALSE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Report_Major_Fault("2.7", FALSE, major_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.8",
         "Force a fault on feedback signals for Penalty Brake 1");

      fb_func_model_behaviour(PENALTY1_FB) <= FEEDBACK_FAIL;
      WAIT FOR 150 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.9",
         "Check if the VCU is in VCUT_NO_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NO_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.10",
         "Check if the VCU is in the OpMode MFAULT (Expected: TRUE)");

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
      tfy_wr_step( report_file, now, "2.11",
         "Check that the Timer was NOT frozen (Expected: FALSE)");

      prev_timer <= x_timer_ctr_r;
      WAIT FOR 50 ms;

      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.12",
         "Check if the Penalty Brake are NOT applied (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_penalty1_out_o = '0', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_penalty2_out_o = '0', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.13",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      -- OpModes
      Report_Diag_IF ("-", C_DIAG_VCU_MAJOR_FAULT_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_TEST_BIT,       '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_DEPRESSED_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_SUPPRESSED_BIT, '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_NORMAL_BIT,     '0', alarm_code_i);

      -- penaltyX_out_o
      Report_Diag_IF ("-", C_DIAG_VCU_PEN_BRAKE_BIT,  '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PEN_1_FAULT_BIT,    '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PEN_2_FAULT_BIT,    '0', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PEN_1_RED_BIT,       '1', led_code_i);
      Report_LED_IF  ("-", C_LED_PEN_2_RED_BIT,       '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("2.14", TRUE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Report_Major_Fault("2.15", TRUE, major_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.16");


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "Test if the UUT transit to OpMode MFAULT after a Penalty Brake 2 Failure");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1",
         "Check if the VCU is in VCUT_NO_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NO_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2",
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
      tfy_wr_step( report_file, now, "3.3",
         "Check that the Timer was NOT frozen (Expected: TRUE)");

      prev_timer <= x_timer_ctr_r;
      WAIT FOR 50 ms;

      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4",
         "Check if the Penalty Brake are NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_penalty1_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_penalty2_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      -- OpModes
      Report_Diag_IF ("-", C_DIAG_VCU_MAJOR_FAULT_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_TEST_BIT,       '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_DEPRESSED_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_SUPPRESSED_BIT, '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_NORMAL_BIT,     '1', alarm_code_i);

      -- penaltyX_out_o
      Report_Diag_IF ("-", C_DIAG_VCU_PEN_BRAKE_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PEN_1_FAULT_BIT,    '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PEN_2_FAULT_BIT,    '0', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PEN_1_RED_BIT,       '0', led_code_i);
      Report_LED_IF  ("-", C_LED_PEN_2_RED_BIT,       '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("3.6", FALSE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Report_Major_Fault("3.7", FALSE, major_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.8",
         "Force a fault on feedback signals for Penalty Brake 2");

      fb_func_model_behaviour(PENALTY2_FB) <= FEEDBACK_FAIL;
      WAIT FOR 150 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.9",
         "Check if the VCU is in VCUT_NO_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NO_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.10",
         "Check if the VCU is in the OpMode MFAULT (Expected: TRUE)");

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
      tfy_wr_step( report_file, now, "3.11",
         "Check that the Timer was NOT frozen (Expected: FALSE)");

      prev_timer <= x_timer_ctr_r;
      WAIT FOR 50 ms;

      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.12",
         "Check if the Penalty Brake are NOT applied (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_penalty1_out_o = '0', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_penalty2_out_o = '0', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.13",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      -- OpModes
      Report_Diag_IF ("-", C_DIAG_VCU_MAJOR_FAULT_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_TEST_BIT,       '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_DEPRESSED_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_SUPPRESSED_BIT, '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_NORMAL_BIT,     '0', alarm_code_i);

      -- penaltyX_out_o
      Report_Diag_IF ("-", C_DIAG_VCU_PEN_BRAKE_BIT,  '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PEN_1_FAULT_BIT,    '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PEN_2_FAULT_BIT,    '1', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PEN_1_RED_BIT,       '0', led_code_i);
      Report_LED_IF  ("-", C_LED_PEN_2_RED_BIT,       '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("3.14", TRUE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Report_Major_Fault("3.15", TRUE, major_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.16");


      --------------------------------------------------------
      -- Testcase End Sequence
      --------------------------------------------------------

      tfy_tc_end(
         tc_pass        => pass,
         report_file    => report_file,
         tc_name        => "TC_RS103_104_183",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "24 Dec 2019",
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
END ARCHITECTURE TC_RS103_104_183;

