-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS124_125
-- Module      : VCU Timing System
-- Revision    : 2.0
-- Date        : 26 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Check Activity Time-Out period for each TLA input 
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-124
--    FPGA-REQ-125
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 27 Mar 2018
--    - J.Sousa (1.0): Initial Release
-- Revision 1.1 - 22 Jun 2019
--    - CABelchior (1.2): CCN3
-- Revision 2.0 - 26 Dec 2019
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
--
-- sim -tc TC_RS124_125 -nocov -numstdoff
-- log -r /*
--
-- 121   Task Linked Activity applicable to Operation Mode diagrams in drawing 4044 3100 shall be defined as:
--       - Movement of MC changing ±12.5% the braking demand;
--       - Movement of MC changing ±12.5% the power demand;
--       - Horn Low or Horn High operation;
--       - Wiper/washer operation;
--       - Headlight operation (Limit of one in succession);
--       - Safety system bypass acknowledge button.
-- 
-- 122   There shall be a limit to the number of times a TLA input resets the timing cycle in succession, 
--       this counter shall be reset when;
--       - Another TLA or Acknowledge input resets the VCU input is used
--       - The VCU is suppressed (inactive) operating mode
-- 
-- 124   There shall be a timeout period for each TLA input, defined in 'Activity Time-Out' column of 
--       Drawing 4044 3105 sheet 1, in which all TLA events from the respective input shall be ignored
--
-- 125   The TLA timeout period shall be reset for each valid TLA event on the corresponding TLA input
--
-- Note from REQ 214: 
--    Both power demand and brake demand TLA events shall be considered 
--    as the same for the purposes of VCU resets and maximum consecutive 
--    reset counters
--
-- Step 2: Verify th Activity Time-Out period for TLA input 'Safety system bypass ack button'
-- Step 3: Verify th Activity Time-Out period for TLA input 'Wiper/washer operation'
-- Step 4: Verify th Activity Time-Out period for TLA input 'Headlight operation'
-- Step 5: Verify timeout period for TLA input 'Horn High operation'
-- Step 6: Verify timeout period for TLA input 'Horn Low operation'
--
-- Attention: In some cases (i.e. w_wiper_pb_i) the TLA event is generated, but the Timer timer_ctr_r
-- is not reset because of the 'Max Consecutive Events' restriction
--

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;
USE WORK.txt_util_p.ALL;

ARCHITECTURE TC_RS124_125 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Type Definitions
   --------------------------------------------------------

   TYPE tla_counter_typ IS ARRAY (7 DOWNTO 0) OF UNSIGNED(3 DOWNTO 0);
   TYPE tla_wait_typ IS ARRAY (7 DOWNTO 0) OF TIME;
   TYPE tla_max_events_typ IS ARRAY (7 DOWNTO 0) OF INTEGER;

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------

   CONSTANT C_TLA_CTR : tla_max_events_typ := (          -- Max Consecutive Events
      0,       -- Spare
      15,      -- MC Movement = Brake Demand or Power Demand. Used in normal mode
      15,      -- Horn Low operation
      15,      -- Horn High operation
      1,       -- Headlight operation
      1,       -- Wiper/washer operation
      0,       -- Spare
      1        -- Safety system bypass ack button  (unlimited, i.e counter never decrement)
   ); 

   CONSTANT C_TLA_WAIT_TIME : tla_wait_typ := (          --Activity Time-Out
       0 ns,   -- Spare
       0 ns,   -- N/A -> MC Movement = Brake Demand or Power Demand. Used in normal mode
      10 sec,  -- Horn Low operation
      10 sec,  -- Horn High operation
       5 sec,  -- Headlight operation
      10 sec,  -- Wiper/washer operation
       0 ns,   -- Spare
      10 sec   -- Safety system bypass ack button
   );

   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------

   -- VCU Timing System FSM
   SIGNAL x_tla_i                                 : STD_LOGIC_VECTOR(7 DOWNTO 0); -- Aggregated Task Linked Activity
   SIGNAL x_timer_ctr_r                           : UNSIGNED(16 DOWNTO 0);        -- Centralized VCU Timer » T1 | T2 | T3 | T4

   -- Input Interface HLB - TIMEOUT FILTERS
   SIGNAL x_cnt_r_i0                              : NATURAL RANGE 0 TO 20; -- Horn Low operation
   SIGNAL x_cnt_r_i1                              : NATURAL RANGE 0 TO 20; -- Horn High operation
   SIGNAL x_cnt_r_i2                              : NATURAL RANGE 0 TO 10; -- Headlight operation
   SIGNAL x_cnt_r_i3                              : NATURAL RANGE 0 TO 20; -- Wiper/washer operation
   SIGNAL x_cnt_r_i5                              : NATURAL RANGE 0 TO 20; -- Safety system bypass ack button

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
   SIGNAL event_latch_tla_r                       : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
   

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
         report_fname   => "TC_RS124_125.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS124_125",
         test_module    => "VCU Timing System",
         tc_revision    => "2.0",
         tc_date        => "26 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Check Activity Time-Out period for each TLA input",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_top_tb",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s
      );

      --------------------------------------------------------
      -- Link Spy Probes
      --------------------------------------------------------
      -- VCU Timing System FSM
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/tla_i",         "x_tla_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/timer_ctr_r",   "x_timer_ctr_r", 0);

      -- Input Interface
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/event_filt_timeout_i0/cnt_r",   "x_cnt_r_i0", 0); -- Horn Low
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/event_filt_timeout_i1/cnt_r",   "x_cnt_r_i1", 0); -- Horn High
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/event_filt_timeout_i2/cnt_r",   "x_cnt_r_i2", 0); -- Headlight Low
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/event_filt_timeout_i3/cnt_r",   "x_cnt_r_i3", 0); -- Washer Wiper Push Button
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/event_filt_timeout_i5/cnt_r",   "x_cnt_r_i5", 0); -- Safety system bypass Push Button

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
         "Verify th Activity Time-Out period for TLA input 'Safety system bypass ack button'");

      -- Rising then falling
      -- Activity Time-Out        = 10 sec

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "Check if the TLA timeout counter is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_cnt_r_i5 = 0,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2",
         "Force a TLA event");

      uut_in.ss_bypass_pb_s <= '1';
      WAIT FOR 160 ms;
      uut_in.ss_bypass_pb_s <= '0';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3",
         "Check if only the respective TLA input was received (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_latch_tla_r = "00000001",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("2.3.1");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4",
         "Wait for 3 sec");

      WAIT FOR 3 sec;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5",
         "Check if the TLA timeout counter is '0' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_cnt_r_i5 = 0,
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.6",
         "Try to force a TLA event, and stamp its time (ta = now)");

      uut_in.ss_bypass_pb_s <= '1';
      WAIT FOR 160 ms;
      uut_in.ss_bypass_pb_s <= '0';
      WAIT FOR 160 ms;

      ta := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.7",
         "Check if no TLA input was received (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_latch_tla_r = "00000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.8",
         "Wait until TLA timeout counter is '0', and stamp its time (tb = now)");

      WAIT UNTIL x_cnt_r_i5 = 0;

      tb := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.9",
         "Force a TLA event");

      uut_in.ss_bypass_pb_s <= '1';
      WAIT FOR 160 ms;
      uut_in.ss_bypass_pb_s <= '0';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.10",
         "Check if only the respective TLA input was received (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_latch_tla_r = "00000001",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("2.10.1");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.11",
         "Check if TLA timeout period is 10sec (Expected: TRUE)");

      dt := tb - ta;
      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => 10 sec - 500 ms,
                expected_max   => 10 sec + 500 ms,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "Verify th Activity Time-Out period for TLA input 'Wiper/washer operation'");

      -- Rising or falling
      -- Activity Time-Out        = 10 sec

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1",
         "Check if the TLA timeout counter is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_cnt_r_i3 = 0,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2",
         "Force a TLA event");

      uut_in.w_wiper_pb_s <= '1';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3",
         "Check if only the respective TLA input was received (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_latch_tla_r = "00000100",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("3.3.1");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4",
         "Wait for 3 sec");

      WAIT FOR 3 sec;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5",
         "Check if the TLA timeout counter is '0' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_cnt_r_i3 = 0,
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.6",
         "Try to force a TLA event, and stamp its time (ta = now)");

      uut_in.w_wiper_pb_s <= '0';
      WAIT FOR 160 ms;

      ta := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.7",
         "Check if no TLA input was received (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_latch_tla_r = "00000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.8",
         "Wait until TLA timeout counter is '0', and stamp its time (tb = now)");

      WAIT UNTIL x_cnt_r_i3 = 0;

      tb := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.9",
         "Force a TLA event");

      uut_in.w_wiper_pb_s <= '1';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.10",
         "Check if only the respective TLA input was received (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_latch_tla_r = "00000100",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("3.10.1");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.11",
         "Check if TLA timeout period is 10sec (Expected: TRUE)");

      dt := tb - ta;
      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => 10 sec - 500 ms,
                expected_max   => 10 sec + 500 ms,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 4
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------------#");
      tfy_wr_step( report_file, now, "4",
         "Verify th Activity Time-Out period for TLA input 'Headlight operation'");

      -- Rising or falling
      -- Activity Time-Out        = 5 sec

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1",
         "Check if the TLA timeout counter is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_cnt_r_i2 = 0,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2",
         "Force a TLA event");

      uut_in.hl_low_s <= '1';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3",
         "Check if only the respective TLA input was received (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_latch_tla_r = "00001000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("4.3.1");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4",
         "Wait for 3 sec");

      WAIT FOR 3 sec;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5",
         "Check if the TLA timeout counter is '0' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_cnt_r_i2 = 0,
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.6",
         "Try to force a 'Headlight operation' TLA event, and stamp its time (ta = now)");

      uut_in.hl_low_s <= '0';
      WAIT FOR 160 ms;

      ta := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.7",
         "Check if no TLA input was received (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_latch_tla_r = "00000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);


      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.8",
         "Wait until TLA timeout counter is '0', and stamp its time (tb = now)");

      WAIT UNTIL x_cnt_r_i2 = 0;

      tb := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.9",
         "Force a TLA event");

      uut_in.hl_low_s <= '1';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.10",
         "Check if only the respective TLA input was received (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_latch_tla_r = "00001000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("4.10.1");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.11",
         "Check if TLA timeout period is 10sec (Expected: TRUE)");

      dt := tb - ta;
      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => 5 sec - 500 ms,
                expected_max   => 5 sec + 500 ms,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 5
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5: -------------------------------------------#");
      tfy_wr_step( report_file, now, "5",
         "Verify timeout period for TLA input 'Horn High operation'");

      -- Rising then falling
      -- Activity Time-Out        = 10 sec

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1",
         "Check if the TLA timeout counter is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_cnt_r_i1 = 0,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2",
         "Force a TLA event");

      uut_in.horn_high_s <= '1';
      WAIT FOR 160 ms;
      uut_in.horn_high_s <= '0';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3",
         "Check if only the respective TLA input was received (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_latch_tla_r = "00010000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("5.3.1");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4",
         "Wait for 3 sec");

      WAIT FOR 3 sec;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5",
         "Check if the TLA timeout counter is '0' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_cnt_r_i1 = 0,
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.6",
         "Try to force a TLA event, and stamp its time (ta = now)");

      uut_in.horn_high_s <= '1';
      WAIT FOR 160 ms;
      uut_in.horn_high_s <= '0';
      WAIT FOR 160 ms;

      ta := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.7",
         "Check if no TLA input was received (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_latch_tla_r = "00000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.8",
         "Wait until TLA timeout counter is '0', and stamp its time (tb = now)");

      WAIT UNTIL x_cnt_r_i1 = 0;

      tb := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.9",
         "Force a TLA event");

      uut_in.horn_high_s <= '1';
      WAIT FOR 160 ms;
      uut_in.horn_high_s <= '0';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.10",
         "Check if only the respective TLA input was received (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_latch_tla_r = "00010000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("5.10.1");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.11",
         "Check if TLA timeout period is 10sec (Expected: TRUE)");

      dt := tb - ta;

      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => 10 sec - 500 ms,
                expected_max   => 10 sec + 500 ms,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 6
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6: -------------------------------------------#");
      tfy_wr_step( report_file, now, "6",
         "Verify timeout period for TLA input 'Horn Low operation'");

      -- Rising then falling
      -- Activity Time-Out        = 10 sec

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1",
         "Check if the TLA timeout counter is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_cnt_r_i0 = 0,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2",
         "Force a TLA event");

      uut_in.horn_low_s <= '1';
      WAIT FOR 160 ms;
      uut_in.horn_low_s <= '0';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3",
         "Check if only the respective TLA input was received (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_latch_tla_r = "00100000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("6.3.1");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4",
         "Wait for 3 sec");

      WAIT FOR 3 sec;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.5",
         "Check if the TLA timeout counter is '0' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_cnt_r_i0 = 0,
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.6",
         "Try to force a TLA event, and stamp its time (ta = now)");

      uut_in.horn_low_s <= '1';
      WAIT FOR 160 ms;
      uut_in.horn_low_s <= '0';
      WAIT FOR 160 ms;

      ta := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.7",
         "Check if no TLA input was received (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_latch_tla_r = "00000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.8",
         "Wait until TLA timeout counter is '0', and stamp its time (tb = now)");

      WAIT UNTIL x_cnt_r_i0 = 0;

      tb := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.9",
         "Force a TLA event");

      uut_in.horn_low_s <= '1';
      WAIT FOR 160 ms;
      uut_in.horn_low_s <= '0';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.10",
         "Check if only the respective TLA input was received (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => event_latch_tla_r = "00100000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);
      
      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("6.10.1");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.11",
         "Check if TLA timeout period is 10sec (Expected: TRUE)");

      dt := tb - ta;

      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => 10 sec - 500 ms,
                expected_max   => 10 sec + 500 ms,
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
         tc_name        => "TC_RS124_125",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "26 Dec 2019",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s    
      );

   END PROCESS p_steps;

    p_event_latch: PROCESS(event_latch_rst_r, x_tla_i)
    BEGIN
        IF rising_edge(event_latch_rst_r) THEN
            event_latch_tla_r <= (OTHERS => '0');  
        ELSE

            IF rising_edge(x_tla_i(0)) THEN
                event_latch_tla_r(0) <= '1'; -- Safety system bypass ack button
            END IF;

            IF rising_edge(x_tla_i(1)) THEN
                event_latch_tla_r(1) <= '1'; -- SPARE
            END IF;

            IF rising_edge(x_tla_i(2)) THEN
                event_latch_tla_r(2) <= '1'; -- Wiper/washer operation
            END IF;

            IF rising_edge(x_tla_i(3)) THEN
                event_latch_tla_r(3) <= '1'; -- Headlight operation
            END IF;

            IF rising_edge(x_tla_i(4)) THEN
                event_latch_tla_r(4) <= '1'; -- Horn High operation
            END IF;

            IF rising_edge(x_tla_i(5)) THEN
                event_latch_tla_r(5) <= '1'; -- Horn Low operation
            END IF;

            IF rising_edge(x_tla_i(6)) THEN
                event_latch_tla_r(6) <= '1'; -- MC Movement = Power or Brake Demand. Used in normal mode
            END IF;

            IF rising_edge(x_tla_i(7)) THEN
                event_latch_tla_r(7) <= '1'; -- SPARE
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

END ARCHITECTURE TC_RS124_125;