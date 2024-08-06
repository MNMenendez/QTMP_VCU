-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS117_118_119
-- Module      : VCU Timing System
-- Revision    : 2.0
-- Date        : 18 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Check VCU FSM transitions at OpMode NORMAL
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-117
--    FPGA-REQ-118
--    FPGA-REQ-119
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 07 Mar 2018
--    - J.Sousa (1.0): Initial Release
-- Revision 1.1 - 02 May 2019
-- -  VSA (1.1): CCN03 changes
-- Revision 2.0 - 18 Dec 2019
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- Notes:
--
-- sim -tc TC_RS117_118_119 -numstdoff -nocov
-- log -r /*
--
-- 117   The Normal Operation Mode and its associated states are specified in drawing 4044 3100 r8 sheet 2.
--
-- 118   During power up the VCU shall enter the normal mode "No Warning" state, show in drawing 4044 3100 r8 sheet 2.
--
-- 119   The following constraints shall be applicable to Normal Operating Mode:
--       - All vigilance timers are running;
--       - All self-test and fault detection operations continue as normal
--       - Penalty applications ARE allowed;
--
-- At OpMode NORMAL
-- -------------------
--
-- Step 2:  Test if the UUT transit to VCUT_NO_WARNING after a Power Up
--
-- Step 3:  Test if the UUT transit from VCUT_NO_WARNING      to VCUT_1ST_WARNING     after 'T1=45sec' expires
-- Step 4:  Test if the UUT transit from VCUT_NO_WARNING      to VCUT_1ST_WARNING     after 'T1=35sec' expires
-- Step 5:  Test if the UUT transit from VCUT_NO_WARNING      to VCUT_1ST_WARNING     after 'T1=30sec' expires
-- Step 6:  Test if the UUT transit from VCUT_NO_WARNING      to VCUT_1ST_WARNING     after 'T1=25sec' expires
-- Step 7:  Test if the UUT transit from VCUT_1ST_WARNING     to VCUT_2ST_WARNING     after 'T2=5sec' expires
-- Step 8:  Test if the UUT transit from VCUT_2ST_WARNING     to VCUT_BRK_NORST       after 'T3=5sec' expires
-- Step 9:  Test if the UUT transit from VCUT_BRK_NORST       to VCUT_TRN_STOP_NORST  after SPD Good AND Train Standstill
-- Step 10: Test if the UUT transit from VCUT_TRN_STOP_NORST  to VCUT_NORMAL          after 'T4=3sec' expires
-- Step 11: Test if the UUT transit from VCUT_NORMAL          to VCUT_NO_WARNING      after 'MC=No_Power AND cab_act_chX_i = '1' > 2sec'
-- Step 12: Test if the UUT transit from VCUT_NO_WARNING      to VCUT_1ST_WARNING     after 'VPB Held > 1.5sec'
-- Step 13: Test if the UUT transit from VCUT_2ST_WARNING     to VCUT_BRK_NORST       after 'T3=10sec' expires
-- Step 14: Test if the UUT transit from VCUT_BRK_NORST       to VCUT_NORMAL          after 'SPD Failure AND Tbrake > 45sec'
-- Step 15: Test if the UUT transit from VCUT_NORMAL          to VCUT_NO_WARNING      after 'MC=No_Power AND VPB Pulse'
--
-- FPGA-REQ-119 "fault detection operations" is tested on TC_RS113_119
--
-- The following outputs are tested per VCU FSM States in OpMode NORMAL at TC_RS115_052_053_056_054 (Steps 2 to 7)
--    » Penalty Brake Release
--    » Penalty Brake Applied
--    » Solid Light at '0'
--    » Solid Light at '1'
--    » Flashing Light at freq. equal to 1Hz (50% Duty)
--    » Audible Warning applied (only on step 4)
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

ARCHITECTURE TC_RS117_118_119 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------
   CONSTANT C_TIMER_DEFAULT       : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(89999, 17);   -- 45s timer
   
   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------
   SIGNAL x_vcut_curst_r                          : vcut_st_t;

      -- Top-Level of the VCU Timing System HLB
   --------------------------------------------------------

   --  Timing
   SIGNAL x_pulse500us_i                          : STD_LOGIC;      -- Internal 500us synch pulse

   --  Raw Inputs
   SIGNAL x_vigi_pb_raw_i                         : STD_LOGIC;      -- Vigilance Push

   --  PWM Processed Inputs
   SIGNAL x_mc_no_pwr_i                           : STD_LOGIC;      -- MC = No Power

   -- VCU Timing System FSM
   --------------------------------------------------------
   SIGNAL x_init_tmr_s                            : STD_LOGIC;             -- Initialize Timer (indicates the reset)
   SIGNAL x_timer_ctr_r                           : UNSIGNED(16 DOWNTO 0); -- Centralized VCU Timer » T1 | T2 | T3 | T4

   SIGNAL x_init_ctmr_s                           : STD_LOGIC;             -- Initialize Timer
   SIGNAL x_ctmr_ctr_r                            : UNSIGNED(11 DOWNTO 0); -- Cab Timer

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
         report_fname   => "TC_RS117_118_119.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS117_118_119",
         test_module    => "VCU Timing System",
         tc_revision    => "2.0",
         tc_date        => "18 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Check VCU FSM transitions at OpMode NORMAL",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_top_tb",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s
      );   

      --------------------------------------------------------
      -- Link Spy Probes
      --------------------------------------------------------

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/vcut_curst_r", "x_vcut_curst_r", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/pulse500us_i",       "x_pulse500us_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vigi_pb_raw_i",      "x_vigi_pb_raw_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/mc_no_pwr_i",        "x_mc_no_pwr_i", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/init_tmr_s",   "x_init_tmr_s", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/timer_ctr_r",  "x_timer_ctr_r", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/init_ctmr_s",  "x_init_ctmr_s", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/ctmr_ctr_r",   "x_ctmr_ctr_r", 0);

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
         "Test if the UUT transit to VCUT_NO_WARNING after a Power Up");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "Reset UUT");

      uut_in.arst_n_s     <= '0';       -- Reset UUT
      wait_for_clk_cycles(30, Clk);
      uut_in.arst_n_s     <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2",
         "Check if the VCU is in VCUT_IDLE state just after the reset on UUT (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_IDLE,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.1",
         "Wait for the falling edge of x_pulse500us_i, for TMS output sync");
      
      WAIT UNTIL falling_edge(x_pulse500us_i) FOR 1 ms;    -- for TMS output sync

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3",
         "Check if the VCU is in VCUT_NO_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NO_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "Test if the UUT transit from VCUT_NO_WARNING to VCUT_1ST_WARNING after 'T1=45sec' expires");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1",
         "Set analog speed to [25 - 75 km/h]");

      Set_Speed_Cases(4);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2",
         "Reset UUT");

      uut_in.arst_n_s     <= '0';       -- Reset UUT
      wait_for_clk_cycles(30, Clk);
      uut_in.arst_n_s     <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3",
         "Wait for the next falling edge of x_pulse500us_i and stamp its time (ta = now)"); -- x_pulse500us_i because is just after a reset

      WAIT UNTIL falling_edge(x_pulse500us_i) FOR 1 ms;
      ta := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4",
         "Wait until 'T1=45sec' expires and stamp its time (tb = now)");

      WAIT UNTIL falling_edge(x_init_tmr_s);
      tb := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.6",
         "Check if the time between two falling edge of x_init_tmr_s (tb - ta) is equal to 'T1=45sec'");

      dt := tb - ta;
      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => (45 sec)*0.998,
                expected_max   => (45 sec)*1.002,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 4
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------------#");
      tfy_wr_step( report_file, now, "4",
         "Test if the UUT transit from VCUT_NO_WARNING to VCUT_1ST_WARNING after 'T1=35sec' expires");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1",
         "Set analog speed to [75 - 90 km/h]");

      Set_Speed_Cases(5);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2",
         "Reset UUT");

      uut_in.arst_n_s     <= '0';       -- Reset UUT
      wait_for_clk_cycles(30, Clk);
      uut_in.arst_n_s     <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3",
         "Wait for the next falling edge of x_pulse500us_i and stamp its time (ta = now)"); -- x_pulse500us_i because is just after a reset

      WAIT UNTIL falling_edge(x_pulse500us_i) FOR 1 ms;
      ta := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4",
         "Wait until 'T1=35sec' expires and stamp its time (tb = now)");

      WAIT UNTIL falling_edge(x_init_tmr_s);
      tb := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.6",
         "Check if the time between two falling edge of x_init_tmr_s (tb - ta) is equal to 'T1=35sec'");

      dt := tb - ta;
      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => (35 sec)*0.998,
                expected_max   => (35 sec)*1.002,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 5
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5: -------------------------------------------#");
      tfy_wr_step( report_file, now, "5",
         "Test if the UUT transit from VCUT_NO_WARNING to VCUT_1ST_WARNING after 'T1=30sec' expires");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1",
         "Set analog speed to [90 - 110 km/h]");

      Set_Speed_Cases(6);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2",
         "Reset UUT");

      uut_in.arst_n_s     <= '0';       -- Reset UUT
      wait_for_clk_cycles(30, Clk);
      uut_in.arst_n_s     <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3",
         "Wait for the next falling edge of x_pulse500us_i and stamp its time (ta = now)"); -- x_pulse500us_i because is just after a reset

      WAIT UNTIL falling_edge(x_pulse500us_i) FOR 1 ms;
      ta := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4",
         "Wait until 'T1=30sec' expires and stamp its time (tb = now)");

      WAIT UNTIL falling_edge(x_init_tmr_s);
      tb := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.6",
         "Check if the time between two falling edge of x_init_tmr_s (tb - ta) is equal to 'T1=30sec'");

      dt := tb - ta;
      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => (30 sec)*0.998,
                expected_max   => (30 sec)*1.002,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 6
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6: -------------------------------------------#");
      tfy_wr_step( report_file, now, "6",
         "Test if the UUT transit from VCUT_NO_WARNING to VCUT_1ST_WARNING after 'T1=25sec' expires");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1",
         "Set analog speed to [> 110 km/h]");

      Set_Speed_Cases(7);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2",
         "Reset UUT");

      uut_in.arst_n_s     <= '0';       -- Reset UUT
      wait_for_clk_cycles(30, Clk);
      uut_in.arst_n_s     <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3",
         "Wait for the next falling edge of x_pulse500us_i and stamp its time (ta = now)"); -- x_pulse500us_i because is just after a reset

      WAIT UNTIL falling_edge(x_pulse500us_i) FOR 1 ms;
      ta := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4",
         "Wait until 'T1=25sec' expires and stamp its time (tb = now)");

      -- --»»»»»»»»»»»» begin speeding up the transition
      -- uut_in.vigi_pb_ch1_s <= '1';
      -- uut_in.vigi_pb_ch2_s <= '1';
      -- --««««««««««««

      WAIT UNTIL falling_edge(x_init_tmr_s);
      tb := now;

      -- --»»»»»»»»»»»»
      -- uut_in.vigi_pb_ch1_s <= '0';
      -- uut_in.vigi_pb_ch2_s <= '0';
      -- --«««««««««««« end speeding up the transition

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.5",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.6",
         "Check if the time between two falling edge of x_init_tmr_s (tb - ta) is equal to 'T1=25sec'");

      dt := tb - ta;
      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => (25 sec)*0.998,
                expected_max   => (25 sec)*1.002,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 7
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 7: -------------------------------------------#");
      tfy_wr_step( report_file, now, "7",
         "Test if the UUT transit from VCUT_1ST_WARNING to VCUT_2ST_WARNING after 'T2=5sec' expires");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.1",
         "Wait until 'T2=5sec' expires and stamp its time (tc = now)");

      WAIT UNTIL falling_edge(x_init_tmr_s);
      tc := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.2",
         "Check if the VCU is in the VCUT_2ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_2ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.3",
         "Check if the time between two falling edge of x_init_tmr_s (tc - tb) is equal to 'T2=5sec'");

      dt := tc - tb;
      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => (5 sec)*0.998,
                expected_max   => (5 sec)*1.002,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 8
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 8: -------------------------------------------#");
      tfy_wr_step( report_file, now, "8",
         "Test if the UUT transit from VCUT_2ST_WARNING to VCUT_BRK_NORST after 'T3=5sec' expires");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.1",
         "Wait until 'T3=5sec' expires and stamp its time (td = now)");

      WAIT UNTIL falling_edge(x_init_tmr_s);
      td := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.2",
         "Check if the VCU is in the VCUT_BRK_NORST state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_BRK_NORST,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.3",
         "Check if the time between two falling edge of x_init_tmr_s (td - tc) is equal to 'T3=5sec'");

      dt := td - tc;
      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => (5 sec)*0.998,
                expected_max   => (5 sec)*1.002,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 9
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 9: -------------------------------------------#");
      tfy_wr_step( report_file, now, "9",
         "Test if the UUT transit from VCUT_BRK_NORST to VCUT_TRN_STOP_NORST after SPD Good AND Train Standstill");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.1",
         "Force the 'Train Standstill' state along with SPD Good (no faults)");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.1.1",
         "Set analog speed to [0 - 3 km/h]");
      Set_Speed_Cases(1); -- Analog Speed -> 0 – 3 km/h

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.1.2",
         "Set logic level '1' on signal zero_spd_chX_i");

      uut_in.zero_spd_ch1_s       <= '1'; 
      uut_in.zero_spd_ch2_s       <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.2",
         "Wait until 'Reset T4 (On entry)' and stamp its time (te = now)");

      WAIT UNTIL falling_edge(x_init_tmr_s);
      te := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.3",
         "Check if the VCU is in the VCUT_TRN_STOP_NORST state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_TRN_STOP_NORST,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);


      --==============
      -- Step 10
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 10: -------------------------------------------#");
      tfy_wr_step( report_file, now, "10",
         "Test if the UUT transit from VCUT_TRN_STOP_NORST to VCUT_NORMAL after 'T4=3sec' expires");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.1",
         "Wait until 'T4=3sec' expires and stamp its time (tf = now)");

      WAIT UNTIL falling_edge(x_init_tmr_s);
      tf := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.2",
         "Check if the VCU is in the VCUT_NORMAL state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NORMAL,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.3",
         "Check if the time between two falling edge of x_init_tmr_s (tf - te) is equal to 'T4=3sec'");

      dt := tf - te;
      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => (3 sec)*0.998,
                expected_max   => (3 sec)*1.002,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 11
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 11: -------------------------------------------#");
      tfy_wr_step( report_file, now, "11",
         "Test if the UUT transit from VCUT_NORMAL to VCUT_NO_WARNING after 'MC=No_Power AND cab_act_chX_i = '1' > 2sec'"); -- this two signals are in the specified states from begining

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.1",
         "Check if the MC is in No_Power state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.2",
         "Set logic level '1' on signal cab_act_chX_i");

      uut_in.cab_act_ch1_s        <= '1'; 
      uut_in.cab_act_ch2_s        <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.3", 
         "Wait until 'Cab Timer' begins to count and stamp its time (tf = now)");

      WAIT UNTIL falling_edge(x_init_ctmr_s);
      tf := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.4",
         "Wait until 'Cab Timer' expires and stamp its time (tg = now)"); -- As T1 is reset on VCUT_NO_WARNING entry, one can still use x_timer_ctr_r

      WAIT UNTIL falling_edge(x_init_tmr_s);
      tg := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.5",
         "Check if the VCU is in the VCUT_NO_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NO_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.6",
         "Check if the time between two falling edge of x_init_tmr_s (tg - tf) is '> 2sec'");

      dt := tg - tf;
      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => (2 sec)*0.998,
                expected_max   => (2 sec)*1.002,
                report_file    => report_file,
                pass           => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("11.7");


      --==============
      -- Step 12
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 12: -------------------------------------------#");
      tfy_wr_step( report_file, now, "12",
         "Test if the UUT transit from VCUT_NO_WARNING to VCUT_1ST_WARNING after 'VPB Held > 1.5sec'");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.1",
         "Set analog speed to [25 - 75 km/h]");

      Set_Speed_Cases(4);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.2",
         "Reset UUT");

      uut_in.arst_n_s     <= '0';       -- Reset UUT
      wait_for_clk_cycles(30, Clk);
      uut_in.arst_n_s     <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.3",
         "Wait for the VCU change state to VCUT_NO_WARNING");

      WAIT UNTIL falling_edge(x_init_tmr_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.3.1",
         "Check if the VCU is in the VCUT_NO_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NO_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.4",
         "Set logic level '1' on signal vigi_pb_chX_i");

      uut_in.vigi_pb_ch1_s <= '1'; 
      uut_in.vigi_pb_ch2_s <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.4.1",
         "Wait the input of the TMS module to change and stamp its time (ta = now)");

      WAIT UNTIL x_vigi_pb_raw_i = '1' FOR 200 ms; -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);     -- for TMS output sync
      ta := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.5",
         "Wait for the VCU change state to VCUT_1ST_WARNING and stamp its time (tb = now)");

      WAIT UNTIL falling_edge(x_init_tmr_s) FOR 2 sec;
      tb := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.5.1",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.6",
         "Set logic level '0' on signal vigi_pb_chX_i");

      uut_in.vigi_pb_ch1_s <= '0'; 
      uut_in.vigi_pb_ch2_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.7",
         "Check if the time between two falling edge of x_init_tmr_s (tb - ta) is '> 1.5sec'");

      dt := tb - ta;
      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => (1.5 sec)*0.998,
                expected_max   => (1.5 sec)*1.002,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 13
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 13: -------------------------------------------#");
      tfy_wr_step( report_file, now, "13",
         "Test if the UUT transit from VCUT_2ST_WARNING to VCUT_BRK_NORST after 'T3=10sec' expires");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.1",
         "Wait for the VCU change state to VCUT_2ST_WARNING and stamp its time (ta = now)");

      WAIT UNTIL falling_edge(x_init_tmr_s) FOR 5.5 sec;    -- T2 Expired
      ta := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.1.1",
         "Check if the VCU is in the VCUT_2ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_2ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.2",
         "Wait for the VCU change state to VCUT_BRK_NORST and stamp its time (tb = now)");

      WAIT UNTIL falling_edge(x_init_tmr_s) FOR 10.5 sec;   -- T3 Expired
      tb := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.2.1",
         "Check if the VCU is in the VCUT_BRK_NORST state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_BRK_NORST,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "13.3",
         "Check if the time between two falling edge of x_init_tmr_s (tb - ta) is equal to 'T3=10sec'");

      dt := tb - ta;
      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => (10 sec)*0.998,
                expected_max   => (10 sec)*1.002,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 14
      --==============

      -- Note: SPD Failure, by design, takes only analog speed into consideration 
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 14: -------------------------------------------#");
      tfy_wr_step( report_file, now, "14",
         "Test if the UUT transit from VCUT_BRK_NORST to VCUT_NORMAL after 'SPD Failure AND Tbrake > 45sec'"); 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.1",
         "Force a SPD Failure (i.e. Analog Speed Error)");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.1.1",
         "Set analog speed to [Under Range]"); -- Because of FPGA-REQ-202, this fault takes 20sec to be considered
      Set_Speed_Cases(0); -- Analog Speed -> Under Range

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.2",
         "Wait until 'Reset T6 (On entry)' and stamp its time (tc = now)");

      WAIT UNTIL falling_edge(x_init_tmr_s) FOR 45.5 sec;
      tc := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "14.3",
         "Check if the time between two falling edge of x_init_tmr_s (tc - tb) is equal to 'Tbrake > 45sec'");

      dt := tc - tb;
      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => (45 sec)*0.998,
                expected_max   => (45 sec)*1.002,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 15
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 15: -------------------------------------------#");
      tfy_wr_step( report_file, now, "15",
         "Test if the UUT transit from VCUT_NORMAL to VCUT_NO_WARNING after 'MC=No_Power AND VPB Pulse'");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.1",
         "Check if the MC is in No_Power state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_mc_no_pwr_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.2",
         "Set a pulse on signal vigi_pb_chX_i");

      uut_in.vigi_pb_ch1_s        <= '1'; 
      uut_in.vigi_pb_ch2_s        <= '1';
      WAIT FOR 200 ms;

      uut_in.vigi_pb_ch1_s        <= '0'; 
      uut_in.vigi_pb_ch2_s        <= '0'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.2.1",
         "Wait the Timer value to reset");

      WAIT UNTIL falling_edge(x_init_tmr_s);       -- As T1 is reset on VCUT_NO_WARNING entry

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "15.3",
         "Check if the VCU is in the VCUT_NO_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NO_WARNING,
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
         tc_name        => "TC_RS117_118_119",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "18 Dec 2019",
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
END ARCHITECTURE TC_RS117_118_119;

