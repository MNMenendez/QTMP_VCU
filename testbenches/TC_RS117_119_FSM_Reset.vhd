-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS117_119_FSM_Reset
-- Module      : VCU Timing System
-- Revision    : 1.0
-- Date        : 18 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Check VCU FSM reset to VCUT_NO_WARNING transitions at OpMode NORMAL
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-117
--    FPGA-REQ-119
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 18 Dec 2019
--    - CABelchior (1.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- Notes:
--
-- sim -tc TC_RS117_119_FSM_Reset -numstdoff -nocov
-- log -r /*
--
-- 117   The Normal Operation Mode and its associated states are specified in drawing 4044 3100 r8 sheet 2.
--
-- 119   The following constraints shall be applicable to Normal Operating Mode:
--       - All vigilance timers are running;
--       - All self-test and fault detection operations continue as normal
--       - Penalty applications ARE allowed;
--
-- At OpMode NORMAL
-- -------------------
--
-- Step 2: Test if the UUT resets the VCUT_NO_WARNING state after a TLA Generation
-- Step 3: Test if the UUT transit from VCUT_1ST_WARNING to VCUT_NO_WARNING after a TLA Generation
-- Step 4: Test if the UUT transit from VCUT_1ST_WARNING to VCUT_NO_WARNING after an Ack Pressed (VPB Pulse)
-- Step 5: Test if the UUT transit from VCUT_2ST_WARNING to VCUT_NO_WARNING after a TLA Generation
-- Step 6: Test if the UUT transit from VCUT_2ST_WARNING to VCUT_NO_WARNING after an Ack Pressed (VPB Pulse)
--
-- Task Linked Activity applicable to Operation Mode diagrams in drawing 4044 3100 shall be defined as:
--       - Movement of MC changing ±12.5% the braking demand;
--       - Movement of MC changing ±12.5% the power demand;
--       - Horn Low or Horn High operation;
--       - Wiper/washer operation;
--       - Headlight operation (Limit of one in succession);
--       - Safety system bypass acknowledge button.
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

ARCHITECTURE TC_RS117_119_FSM_Reset OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------
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

   -- VCU Timing System FSM
   SIGNAL x_vcut_curst_r                          : vcut_st_t;
   SIGNAL x_init_tmr_s                            : STD_LOGIC;             -- Initialize Timer (indicates the reset)
   SIGNAL x_timer_ctr_r                           : UNSIGNED(16 DOWNTO 0); -- Centralized VCU Timer » T1 | T2 | T3 | T4


   --------------------------------------------------------
   -- User Signals
   --------------------------------------------------------
   SIGNAL s_usr_sigout_s                          : tfy_user_out;
   SIGNAL s_usr_sigin_s                           : tfy_user_in;
   SIGNAL pwm_func_model_data_s                   : pwm_func_model_inputs := C_PWM_FUNC_MODEL_INPUTS_INIT;   
   SIGNAL st_ch1_in_ctrl_s                        : ST_BEHAVIOR_CH1;
   SIGNAL st_ch2_in_ctrl_s                        : ST_BEHAVIOR_CH2;

   SIGNAL minor_flt_report_s                      : STD_LOGIC := '0';

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
         report_fname   => "TC_RS117_119_FSM_Reset.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS117_119_FSM_Reset",
         test_module    => "VCU Timing System",
         tc_revision    => "1.0",
         tc_date        => "18 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Check VCU FSM reset to VCUT_NO_WARNING transitions at OpMode NORMAL",
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
         "Test if the UUT resets the VCUT_NO_WARNING state after a TLA Generation");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "For TLA 'Safety system bypass ack button', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.1",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.2",
         "Force a 'Safety system bypass ack button' TLA event");

      uut_in.ss_bypass_pb_s <= '1';
      WAIT FOR 160 ms;
      uut_in.ss_bypass_pb_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.3",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.1.4");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2",
         "For TLA 'Wiper/washer operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.1",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.2",
         "Force a 'Wiper/washer operation' TLA event");

      uut_in.w_wiper_pb_s <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.3",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.2.4");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3",
         "For TLA 'Headlight operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.1",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.2",
         "Force a 'Headlight operation' TLA event");

      uut_in.hl_low_s <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.3",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.3.4");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4",
         "For TLA 'Horn High operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.1",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.2",
         "Force a 'Horn High operation' TLA event");

      uut_in.horn_high_s <= '1';
      WAIT FOR 160 ms;
      uut_in.horn_high_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.3",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.4.4");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5",
         "For TLA 'Horn Low operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.1",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.2",
         "Force a 'Horn Low operation' TLA event");

      uut_in.horn_low_s <= '1';
      WAIT FOR 160 ms;
      uut_in.horn_low_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.3",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.5.4");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.6",
         "For TLA 'MC Movement as Power Demand', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.6.1",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.6.2",
         "Force a 'MC Movement as Power Demand' TLA event");

      pwm_func_model_data_s  <= C_PWM_FMI_PWR_DEMAND;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.6.3",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.6.4");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.7",
         "For TLA 'MC Movement as Brake Demand', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.7.1",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.7.2",
         "Force a 'MC Movement as Power Demand' TLA event");

      pwm_func_model_data_s  <= C_PWM_FMI_BRK_DEMAND;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.7.3",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.7.4");


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "Test if the UUT transit from VCUT_1ST_WARNING to VCUT_NO_WARNING after a TLA Generation");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1",
         "For TLA 'Safety system bypass ack button', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.2",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.3",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.4",
         "Force a 'Safety system bypass ack button' TLA event");

      uut_in.ss_bypass_pb_s <= '1';
      WAIT FOR 160 ms;
      uut_in.ss_bypass_pb_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.5",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.1.6");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2",
         "For TLA 'Wiper/washer operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.2",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.3",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.4",
         "Force a 'Wiper/washer operation' TLA event");

      uut_in.w_wiper_pb_s <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.5",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.2.6");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3",
         "For TLA 'Headlight operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.2",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.3",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.4",
         "Force a 'Headlight operation' TLA event");

      uut_in.hl_low_s <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.5",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.3.6");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4",
         "For TLA 'Horn High operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.2",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.3",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.4",
         "Force a 'Horn High operation' TLA event");

      uut_in.horn_high_s <= '1';
      WAIT FOR 160 ms;
      uut_in.horn_high_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.5",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.4.6");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5",
         "For TLA 'Horn Low operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5.2",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5.3",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5.4",
         "Force a 'Horn Low operation' TLA event");

      uut_in.horn_low_s <= '1';
      WAIT FOR 160 ms;
      uut_in.horn_low_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5.5",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.5.6");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.6",
         "For TLA 'MC Movement as Power Demand', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.6.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.6.2",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.6.3",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.6.4",
         "Force a 'MC Movement as Power Demand' TLA event");

      pwm_func_model_data_s  <= C_PWM_FMI_PWR_DEMAND;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.6.5",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.6.6");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.7",
         "For TLA 'MC Movement as Brake Demand', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.7.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.7.2",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.7.3",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.7.4",
         "Force a 'MC Movement as Power Demand' TLA event");

      pwm_func_model_data_s  <= C_PWM_FMI_BRK_DEMAND;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.7.5",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.7.6");


      --==============
      -- Step 4
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------------#");
      tfy_wr_step( report_file, now, "4",
         "Test if the UUT transit from VCUT_1ST_WARNING to VCUT_NO_WARNING after an Ack Pressed (VPB Pulse)");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4",
         "Set a pulse on signal vigi_pb_chX_i");

      uut_in.vigi_pb_ch1_s        <= '1'; 
      uut_in.vigi_pb_ch2_s        <= '1';
      WAIT FOR 160 ms;

      uut_in.vigi_pb_ch1_s        <= '0'; 
      uut_in.vigi_pb_ch2_s        <= '0'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.6");


      --==============
      -- Step 5
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5: -------------------------------------------#");
      tfy_wr_step( report_file, now, "5",
         "Test if the UUT transit from VCUT_2ST_WARNING to VCUT_NO_WARNING after a TLA Generation");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1",
         "For TLA 'Safety system bypass ack button', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.2",
         "Wait until 'T2=5sec' expires");

      WAIT UNTIL falling_edge(x_init_tmr_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.3",
         "Check if the VCU is in the VCUT_2ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_2ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.4",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.5",
         "Force a 'Safety system bypass ack button' TLA event");

      uut_in.ss_bypass_pb_s <= '1';
      WAIT FOR 160 ms;
      uut_in.ss_bypass_pb_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.6",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.1.7");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2",
         "For TLA 'Wiper/washer operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.2",
         "Wait until 'T2=5sec' expires");

      WAIT UNTIL falling_edge(x_init_tmr_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.3",
         "Check if the VCU is in the VCUT_2ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_2ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.4",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.5",
         "Force a 'Wiper/washer operation' TLA event");

      uut_in.w_wiper_pb_s <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.6",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.2.7");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3",
         "For TLA 'Headlight operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.2",
         "Wait until 'T2=5sec' expires");

      WAIT UNTIL falling_edge(x_init_tmr_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.3",
         "Check if the VCU is in the VCUT_2ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_2ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.4",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.5",
         "Force a 'Headlight operation' TLA event");

      uut_in.hl_low_s <= '1';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.7",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.3.7");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4",
         "For TLA 'Horn High operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.2",
         "Wait until 'T2=5sec' expires");

      WAIT UNTIL falling_edge(x_init_tmr_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.3",
         "Check if the VCU is in the VCUT_2ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_2ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.4",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.5",
         "Force a 'Horn High operation' TLA event");

      uut_in.horn_high_s <= '1';
      WAIT FOR 160 ms;
      uut_in.horn_high_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.6",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.4.7");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5",
         "For TLA 'Horn Low operation', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5.2",
         "Wait until 'T2=5sec' expires");

      WAIT UNTIL falling_edge(x_init_tmr_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5.3",
         "Check if the VCU is in the VCUT_2ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_2ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5.4",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5.5",
         "Force a 'Horn Low operation' TLA event");

      uut_in.horn_low_s <= '1';
      WAIT FOR 160 ms;
      uut_in.horn_low_s <= '0';

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5.6",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.5.7");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.6",
         "For TLA 'MC Movement as Power Demand', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.6.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.6.2",
         "Wait until 'T2=5sec' expires");

      WAIT UNTIL falling_edge(x_init_tmr_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.6.3",
         "Check if the VCU is in the VCUT_2ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_2ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.6.4",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.6.5",
         "Force a 'MC Movement as Power Demand' TLA event");

      pwm_func_model_data_s  <= C_PWM_FMI_PWR_DEMAND;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.6.6",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.6.7");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.7",
         "For TLA 'MC Movement as Brake Demand', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.7.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.7.2",
         "Wait until 'T2=5sec' expires");

      WAIT UNTIL falling_edge(x_init_tmr_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.7.3",
         "Check if the VCU is in the VCUT_2ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_2ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.7.4",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.7.5",
         "Force a 'MC Movement as Power Demand' TLA event");

      pwm_func_model_data_s  <= C_PWM_FMI_BRK_DEMAND;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.7.6",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.7.7");


      --==============
      -- Step 6
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6: -------------------------------------------#");
      tfy_wr_step( report_file, now, "6",
         "Test if the UUT transit from VCUT_2ST_WARNING to VCUT_NO_WARNING after an Ack Pressed (VPB Pulse)");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2",
         "Wait until 'T2=5sec' expires");

      WAIT UNTIL falling_edge(x_init_tmr_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3",
         "Check if the VCU is in the VCUT_2ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_2ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4",
         "Store the current Timer value, wait 10ms, and check that the Timer was NOT frozen");
      
      prev_timer <= x_timer_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.5",
         "Set a pulse on signal vigi_pb_chX_i");

      uut_in.vigi_pb_ch1_s        <= '1'; 
      uut_in.vigi_pb_ch2_s        <= '1';
      WAIT FOR 160 ms;

      uut_in.vigi_pb_ch1_s        <= '0'; 
      uut_in.vigi_pb_ch2_s        <= '0'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.6",
         "Check if timing cycle was reset (Expected: TRUE)"); -- If TLA event occur, timing cycle is reset

      WAIT UNTIL x_timer_ctr_r = C_TIMER_DEFAULT FOR 160 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = C_TIMER_DEFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("6.7");



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
         tc_name        => "TC_RS117_119_FSM_Reset",
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
END ARCHITECTURE TC_RS117_119_FSM_Reset;

