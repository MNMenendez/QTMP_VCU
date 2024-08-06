-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS121_122
-- Module      : VCU Timing System
-- Revision    : 2.0
-- Date        : 24 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Check TLA max consecutive events and respective couter reset
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-121
--    FPGA-REQ-122
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 27 Mar 2018
--    - J.Sousa (1.0): Initial Release
-- Revision 1.1 - 22 Jun 2019
--    - CABelchior (1.2): CCN3
-- Revision 2.0 - 24 Dec 2019
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
--
-- sim -tc TC_RS121_122 -nocov -numstdoff
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
-- Step 2: Verify the Max Consecutive Events functionality for each TLA input 
-- Step 3: Verify the reset of event counter due to 'Another TLA input'
-- Step 4: Verify the reset of event counter when VCU goes to Suppressed (Inactive) Mode
-- Step 5: Verify the reset of event counter due to an 'VPB input' (acknowledge)
--

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;
USE WORK.txt_util_p.ALL;

ARCHITECTURE TC_RS121_122 OF hcmt_cpld_tc_top IS

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

   CONSTANT C_TIMER_DEFAULT       : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(89999, 17);   -- 45s timer

   CONSTANT C_PWM_FMI_PWR_DEMAND  : pwm_func_model_inputs := ( time_high_1 => 2.00 ms * ( 85.00 / 100.00 ),
                                                               time_high_2 => 2.00 ms * ( 85.00 / 100.00 ),
                                                               offset      => 0 us,
                                                               on_off      => '1', 
                                                               period_1    => 2.00 ms,
                                                               period_2    => 2.00 ms);

   CONSTANT C_PWM_FMI_BRK_DEMAND  : pwm_func_model_inputs := ( time_high_1 => 2.00 ms * ( 15.00 / 100.00 ),
                                                               time_high_2 => 2.00 ms * ( 15.00 / 100.00 ),
                                                               offset      => 0 us,
                                                               on_off      => '1', 
                                                               period_1    => 2.00 ms,
                                                               period_2    => 2.00 ms);

   CONSTANT C_PWM_FMI_NO_POWER    : pwm_func_model_inputs := ( time_high_1 => 2.00 ms * ( 50.00 / 100.00 ),
                                                               time_high_2 => 2.00 ms * ( 50.00 / 100.00 ),
                                                               offset      => 0 us,
                                                               on_off      => '1', 
                                                               period_1    => 2.00 ms,
                                                               period_2    => 2.00 ms);
   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------
   SIGNAL x_opmode_curst_r                        : opmode_st_t;

   -- VCU Timing System FSM
   SIGNAL x_timer_ctr_r                           : UNSIGNED(16 DOWNTO 0);        -- Centralized VCU Timer » T1 | T2 | T3 | T4
   SIGNAL x_tla_evt_ctr_r                         : tla_counter_typ;

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
         report_fname   => "TC_RS121_122.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS121_122",
         test_module    => "VCU Timing System",
         tc_revision    => "2.0",
         tc_date        => "24 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Check TLA max consecutive events and respective couter reset",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_top_tb",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s
      );

      --------------------------------------------------------
      -- Link Spy Probes
      --------------------------------------------------------
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_fsm_i0/opmode_curst_r",   "x_opmode_curst_r", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/tla_evt_ctr_r", "x_tla_evt_ctr_r", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/timer_ctr_r",   "x_timer_ctr_r", 0);

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
         "Verify the Max Consecutive Events functionality for each TLA input");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "For TLA 'Safety system bypass ack button', do:");

      FOR j IN 1 TO C_TLA_CTR(0) LOOP

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.1." & str(j),
            "Force a 'Safety system bypass ack button' TLA event");

         -- Rising then falling
         -- Max Consecutive Events   = unlimited, i.e event counter never decrement

         uut_in.ss_bypass_pb_s <= '1';
         WAIT FOR 160 ms;
         uut_in.ss_bypass_pb_s <= '0';

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.1." & str(j) & ".1",
            "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

         WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
         tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.1." & str(j) & ".2",
            "Check if the TLA event counter was decremented (Expected: FALSE)");

         tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(0) = (C_TLA_CTR(0)-j),
                    expected      => FALSE,       equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.1." & str(j) & ".3",
            "Wait for activity timeout period ");

         ---- Get ready for the next TLA

         ----

         WAIT FOR C_TLA_WAIT_TIME(0);

      END LOOP;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.2",
         "Force one additional 'Safety system bypass ack button' TLA event");

      uut_in.ss_bypass_pb_s <= '1';
      WAIT FOR 160 ms;
      uut_in.ss_bypass_pb_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.2.1",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

         ---- Get ready for the next TLA

         ----

      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2",
         "For TLA 'Wiper/washer operation', do:");

      FOR j IN 1 TO C_TLA_CTR(2) LOOP

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.2." & str(j),
            "Force a 'Wiper/washer operation' TLA event");

         -- Rising or falling 
         -- Max Consecutive Events   = 1

         uut_in.w_wiper_pb_s <= '1';

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.2." & str(j) & ".1",
            "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

         WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
         tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.2." & str(j) & ".2",
            "Check if the TLA event counter was decremented (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(2) = (C_TLA_CTR(2)-j),
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.2." & str(j) & ".3",
            "Wait for activity timeout period ");

         ---- Get ready for the next TLA
         uut_in.w_wiper_pb_s <= '0';
         ----

         WAIT FOR C_TLA_WAIT_TIME(2);

      END LOOP;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.2",
         "Force one additional 'Wiper/washer operation' TLA event");

      uut_in.w_wiper_pb_s <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.2.1",
         "Check if timing cycle was reset (Expected: FALSE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.2.3");


      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3",
         "For TLA 'Headlight operation', do:");

      FOR j IN 1 TO C_TLA_CTR(3) LOOP

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.3." & str(j),
            "Force a 'Headlight operation' TLA event");

         -- Rising or falling 
         -- Max Consecutive Events   = 1

         uut_in.hl_low_s <= '1';

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.3." & str(j) & ".1",
            "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

         WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
         tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.3." & str(j) & ".2",
            "Check if the TLA event counter was decremented (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(3) = (C_TLA_CTR(3)-j),
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.3." & str(j) & ".3",
            "Wait for activity timeout period ");

         ---- Get ready for the next TLA
         uut_in.hl_low_s <= '0';
         ----

         WAIT FOR C_TLA_WAIT_TIME(3);

      END LOOP;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.2",
         "Force one additional 'Headlight operation' TLA event");

         uut_in.hl_low_s <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.2.1",
         "Check if timing cycle was reset (Expected: FALSE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.3.3");


      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4",
         "For TLA 'Horn High operation', do:");

      FOR j IN 1 TO C_TLA_CTR(4) LOOP

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.4." & str(j),
            "Force a 'Horn High operation' TLA event");

         -- Rising then falling
         -- Max Consecutive Events   = 15

         uut_in.horn_high_s <= '1';
         WAIT FOR 160 ms;
         uut_in.horn_high_s <= '0';

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.4." & str(j) & ".1",
            "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

         WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
         tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.4." & str(j) & ".2",
            "Check if the TLA event counter was decremented (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(4) = (C_TLA_CTR(4)-j),
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.4." & str(j) & ".3",
            "Wait for activity timeout period ");

         ---- Get ready for the next TLA

         ----

         WAIT FOR C_TLA_WAIT_TIME(4);

      END LOOP;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.16",
         "Force one additional 'Horn High operation' TLA event");

      uut_in.horn_high_s <= '1';
      WAIT FOR 160 ms;
      uut_in.horn_high_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.16.1",
         "Check if timing cycle was reset (Expected: FALSE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.4.17");


      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5",
         "For TLA 'Horn Low operation', do:");

      FOR j IN 1 TO C_TLA_CTR(5) LOOP

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.5." & str(j),
            "Force a 'Horn Low operation' TLA event");

         -- Rising then falling
         -- Max Consecutive Events   = 15

         uut_in.horn_low_s <= '1';
         WAIT FOR 160 ms;
         uut_in.horn_low_s <= '0';

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.5." & str(j) & ".1",
            "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

         WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
         tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.5." & str(j) & ".2",
            "Check if the TLA event counter was decremented (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(5) = (C_TLA_CTR(5)-j),
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.5." & str(j) & ".3",
            "Wait for activity timeout period ");

         ---- Get ready for the next TLA

         ----

         WAIT FOR C_TLA_WAIT_TIME(5);

      END LOOP;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.16",
         "Force one additional 'Horn Low operation' TLA event");

      uut_in.horn_low_s <= '1';
      WAIT FOR 160 ms;
      uut_in.horn_low_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.16.1",
         "Check if timing cycle was reset (Expected: FALSE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.5.17");


      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.6",
         "For TLA 'MC Movement as Power or Brake Demand', do:");

      FOR j IN 1 TO C_TLA_CTR(6) LOOP

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.6." & str(j),
            "Force a 'MC Movement as Power or Brake Demand' TLA event");

         -- At least ±12.5% of valid ranges
         -- Max Consecutive Events   = 15

         IF (j MOD 2) = 1 THEN
            pwm_func_model_data_s  <= C_PWM_FMI_PWR_DEMAND;
         ELSE
            pwm_func_model_data_s  <= C_PWM_FMI_BRK_DEMAND;
         END IF;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.6." & str(j) & ".1",
            "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

         WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
         tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.6." & str(j) & ".2",
            "Check if the TLA event counter was decremented (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(6) = (C_TLA_CTR(6)-j),
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.6." & str(j) & ".3",
            "Wait for activity timeout period ");

         ---- Get ready for the next TLA

         ----

         WAIT FOR C_TLA_WAIT_TIME(6);

      END LOOP;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.6.16",
         "Force one additional 'MC Movement as Power or Brake Demand' TLA event");

      pwm_func_model_data_s  <= C_PWM_FMI_NO_POWER;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.6.16.1",
         "Check if timing cycle was reset (Expected: FALSE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.6.17");


      --==============
      -- Step 3
      --==============
      -- The Safety system bypass ack button counter is unlimited, i.e counter never decrement

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "Verify the reset of event counter due to 'Another TLA input'");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1",
         "For TLA 'Wiper/washer operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.1",
         "Force a 'Wiper/washer operation' TLA event");

      uut_in.w_wiper_pb_s <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.2",
         "Check if the TLA event counter was decremented (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(2) = (C_TLA_CTR(2)-1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.3",
         "Force another TLA event");

      uut_in.ss_bypass_pb_s <= '1';
      WAIT FOR 160 ms;
      uut_in.ss_bypass_pb_s <= '0';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.4",
         "Check if the TLA event counter was reset (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(2) = C_TLA_CTR(2),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.1.5");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2",
         "For TLA 'Headlight operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.1",
         "Force a 'Headlight operation' TLA event");

      uut_in.hl_low_s <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.2",
         "Check if the TLA event counter was decremented (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(3) = (C_TLA_CTR(3)-1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.3",
         "Force another TLA event");

      uut_in.ss_bypass_pb_s <= '1';
      WAIT FOR 160 ms;
      uut_in.ss_bypass_pb_s <= '0';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.4",
         "Check if the TLA event counter was reset (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(3) = C_TLA_CTR(3),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.2.5");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3",
         "For TLA 'Horn High operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.1",
         "Force a 'Horn High operation' TLA event");

      uut_in.horn_high_s <= '1';
      WAIT FOR 160 ms;
      uut_in.horn_high_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.2",
         "Check if the TLA event counter was decremented (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(4) = (C_TLA_CTR(4)-1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.3",
         "Force another TLA event");

      uut_in.ss_bypass_pb_s <= '1';
      WAIT FOR 160 ms;
      uut_in.ss_bypass_pb_s <= '0';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.4",
         "Check if the TLA event counter was reset (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(4) = C_TLA_CTR(4),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.3.5");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4",
         "For TLA 'Horn Low operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.1",
         "Force a 'Horn Low operation' TLA event");

      uut_in.horn_low_s <= '1';
      WAIT FOR 160 ms;
      uut_in.horn_low_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.2",
         "Check if the TLA event counter was decremented (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(5) = (C_TLA_CTR(5)-1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.3",
         "Force another TLA event");

      uut_in.ss_bypass_pb_s <= '1';
      WAIT FOR 160 ms;
      uut_in.ss_bypass_pb_s <= '0';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.4",
         "Check if the TLA event counter was reset (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(5) = C_TLA_CTR(5),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.4.5");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5",
         "For TLA 'MC Movement as Power or Brake Demand', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5.1",
         "Force a 'MC Movement as Power Demand' TLA event");

      pwm_func_model_data_s  <= C_PWM_FMI_PWR_DEMAND;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5.2",
         "Check if the TLA event counter was decremented (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(6) = (C_TLA_CTR(6)-1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5.3",
         "Force another TLA event");

      uut_in.ss_bypass_pb_s <= '1';
      WAIT FOR 160 ms;
      uut_in.ss_bypass_pb_s <= '0';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5.4",
         "Check if the TLA event counter was reset (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(6) = C_TLA_CTR(6),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.5.5");


      --==============
      -- Step 4
      --==============
      -- The Safety system bypass ack button counter is unlimited, i.e counter never decrement

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------------#");
      tfy_wr_step( report_file, now, "4",
         "Verify the reset of event counter when VCU goes to Suppressed (Inactive) Mode");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1",
         "For TLA 'Wiper/washer operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.1",
         "Force a 'Wiper/washer operation' TLA event");

      uut_in.w_wiper_pb_s <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.2",
         "Check if the TLA event counter was decremented (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(2) = (C_TLA_CTR(2)-1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.3",
         "Set logic level '1' on signal driverless_chX_i to change OpMode to OPMODE_SUPPRESSED");

      uut_in.driverless_ch1_s <= '1';
      uut_in.driverless_ch2_s <= '1';
      WAIT UNTIL x_opmode_curst_r = OPMODE_SUPPRESSED;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.4",
         "Check if the TLA event counter was reset (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(2) = C_TLA_CTR(2),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.1.5");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2",
         "For TLA 'Headlight operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.1",
         "Force a 'Headlight operation' TLA event");

      uut_in.hl_low_s <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.2",
         "Check if the TLA event counter was decremented (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(3) = (C_TLA_CTR(3)-1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.3",
         "Set logic level '1' on signal driverless_chX_i to change OpMode to OPMODE_SUPPRESSED");

      uut_in.driverless_ch1_s <= '1';
      uut_in.driverless_ch2_s <= '1';
      WAIT UNTIL x_opmode_curst_r = OPMODE_SUPPRESSED;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.4",
         "Check if the TLA event counter was reset (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(3) = C_TLA_CTR(3),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.2.5");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3",
         "For TLA 'Horn High operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.1",
         "Force a 'Horn High operation' TLA event");

      uut_in.horn_high_s <= '1';
      WAIT FOR 160 ms;
      uut_in.horn_high_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.2",
         "Check if the TLA event counter was decremented (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(4) = (C_TLA_CTR(4)-1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.3",
         "Set logic level '1' on signal driverless_chX_i to change OpMode to OPMODE_SUPPRESSED");

      uut_in.driverless_ch1_s <= '1';
      uut_in.driverless_ch2_s <= '1';
      WAIT UNTIL x_opmode_curst_r = OPMODE_SUPPRESSED;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.4",
         "Check if the TLA event counter was reset (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(4) = C_TLA_CTR(4),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.3.5");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4",
         "For TLA 'Horn Low operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.1",
         "Force a 'Horn Low operation' TLA event");

      uut_in.horn_low_s <= '1';
      WAIT FOR 160 ms;
      uut_in.horn_low_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.2",
         "Check if the TLA event counter was decremented (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(5) = (C_TLA_CTR(5)-1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.3",
         "Set logic level '1' on signal driverless_chX_i to change OpMode to OPMODE_SUPPRESSED");

      uut_in.driverless_ch1_s <= '1';
      uut_in.driverless_ch2_s <= '1';
      WAIT UNTIL x_opmode_curst_r = OPMODE_SUPPRESSED;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.4",
         "Check if the TLA event counter was reset (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(5) = C_TLA_CTR(5),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.4.5");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5",
         "For TLA 'MC Movement as Power or Brake Demand', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5.1",
         "Force a 'MC Movement as Brake Demand' TLA event");

      pwm_func_model_data_s  <= C_PWM_FMI_BRK_DEMAND;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5.2",
         "Check if the TLA event counter was decremented (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(6) = (C_TLA_CTR(6)-1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5.3",
         "Set logic level '1' on signal driverless_chX_i to change OpMode to OPMODE_SUPPRESSED");

      uut_in.driverless_ch1_s <= '1';
      uut_in.driverless_ch2_s <= '1';
      WAIT UNTIL x_opmode_curst_r = OPMODE_SUPPRESSED;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5.4",
         "Check if the TLA event counter was reset (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(6) = C_TLA_CTR(6),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.5.5");


      --==============
      -- Step 5
      --==============
      -- The Safety system bypass ack button counter is unlimited, i.e counter never decrement

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5: -------------------------------------------#");
      tfy_wr_step( report_file, now, "5",
         "Verify the reset of event counter due to an 'VPB input' (acknowledge)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1",
         "For TLA 'Wiper/washer operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.1",
         "Force a 'Wiper/washer operation' TLA event");

      uut_in.w_wiper_pb_s <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.2",
         "Check if the TLA event counter was decremented (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(2) = (C_TLA_CTR(2)-1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.3",
         "Set a pulse on signal vigi_pb_chX_i");

      uut_in.vigi_pb_ch1_s <= '1'; 
      uut_in.vigi_pb_ch2_s <= '1';
      WAIT FOR 160 ms;

      uut_in.vigi_pb_ch1_s <= '0'; 
      uut_in.vigi_pb_ch2_s <= '0'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.4",
         "Check if the TLA event counter was reset (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(2) = C_TLA_CTR(2),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.1.5");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2",
         "For TLA 'Headlight operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.1",
         "Force a 'Headlight operation' TLA event");

      uut_in.hl_low_s <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.2",
         "Check if the TLA event counter was decremented (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(3) = (C_TLA_CTR(3)-1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.3",
         "Set a pulse on signal vigi_pb_chX_i");

      uut_in.vigi_pb_ch1_s <= '1'; 
      uut_in.vigi_pb_ch2_s <= '1';
      WAIT FOR 160 ms;

      uut_in.vigi_pb_ch1_s <= '0'; 
      uut_in.vigi_pb_ch2_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.4",
         "Check if the TLA event counter was reset (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(3) = C_TLA_CTR(3),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.2.5");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3",
         "For TLA 'Horn High operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.1",
         "Force a 'Horn High operation' TLA event");

      uut_in.horn_high_s <= '1';
      WAIT FOR 160 ms;
      uut_in.horn_high_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.2",
         "Check if the TLA event counter was decremented (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(4) = (C_TLA_CTR(4)-1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.3",
         "Set a pulse on signal vigi_pb_chX_i");

      uut_in.vigi_pb_ch1_s <= '1'; 
      uut_in.vigi_pb_ch2_s <= '1';
      WAIT FOR 160 ms;

      uut_in.vigi_pb_ch1_s <= '0'; 
      uut_in.vigi_pb_ch2_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.4",
         "Check if the TLA event counter was reset (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(4) = C_TLA_CTR(4),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.3.5");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4",
         "For TLA 'Horn Low operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.1",
         "Force a 'Horn Low operation' TLA event");

      uut_in.horn_low_s <= '1';
      WAIT FOR 160 ms;
      uut_in.horn_low_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.2",
         "Check if the TLA event counter was decremented (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(5) = (C_TLA_CTR(5)-1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.3",
         "Set a pulse on signal vigi_pb_chX_i");

      uut_in.vigi_pb_ch1_s <= '1'; 
      uut_in.vigi_pb_ch2_s <= '1';
      WAIT FOR 160 ms;

      uut_in.vigi_pb_ch1_s <= '0'; 
      uut_in.vigi_pb_ch2_s <= '0'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.4",
         "Check if the TLA event counter was reset (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(5) = C_TLA_CTR(5),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.4.5");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5",
         "For TLA 'MC Movement as Power or Brake Demand', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5.1",
         "Force a 'MC Movement as Power Demand' TLA event");

      pwm_func_model_data_s  <= C_PWM_FMI_PWR_DEMAND;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5.2",
         "Check if the TLA event counter was decremented (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(6) = (C_TLA_CTR(6)-1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5.3",
         "Set a pulse on signal vigi_pb_chX_i");

      uut_in.vigi_pb_ch1_s <= '1'; 
      uut_in.vigi_pb_ch2_s <= '1';
      WAIT FOR 160 ms;

      uut_in.vigi_pb_ch1_s <= '0'; 
      uut_in.vigi_pb_ch2_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5.4",
         "Check if the TLA event counter was reset (Expected: TRUE)");

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_tla_evt_ctr_r(6) = C_TLA_CTR(6),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.5.5");


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
         tc_name        => "TC_RS121_122",
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

END ARCHITECTURE TC_RS121_122;

