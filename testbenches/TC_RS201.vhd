-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS201
-- Module      : Input IF
-- Revision    : 2.0
-- Date        : 10 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Tests Power Supply status input error counter
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-201
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 25 Jun 2019
--    - CABelchior (1.2): CCN3
-- Revision 2.0 - 10 Dec 2019
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
--
-- sim -tc TC_RS201 -nocov -numstdoff
-- log -r /*
--
-- 201   Every 500 mS, if either the power supply 1 or power supply 2 status signals are low, the 
--       corresponding error counter shall be incremented, if high the corresponding error counter 
--       shall be decremented (if not equal to zero). If either counter reaches 40 the power supply 
--       shall be considered in a fault state and a minor fault flag shall be set as well as the 
--       corresponding bit in the diagnostics interface.
--
--       Maximum counter value = 40 -> '101000'

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;
USE WORK.txt_util_p.ALL;

ARCHITECTURE TC_RS201 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Type Definitions
   --------------------------------------------------------

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------
   CONSTANT C_COUNTER_PERIOD                      : TIME := 500 ms;

   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------
   SIGNAL x_opmode_curst_r                        : opmode_st_t;
   SIGNAL x_vcut_curst_r                          : vcut_st_t;

   -- Input IF - Power Supply Status: Error Counter Filter
   SIGNAL x_ps1_fail_s0                           : STD_LOGIC;
   SIGNAL x_ps1_fail_s1                           : STD_LOGIC;
   SIGNAL x_counter_r_i0                          : UNSIGNED(5 DOWNTO 0);

   SIGNAL x_ps2_fail_s0                           : STD_LOGIC;
   SIGNAL x_ps2_fail_s1                           : STD_LOGIC;
   SIGNAL x_counter_r_i1                          : UNSIGNED(5 DOWNTO 0);

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
      VARIABLE t0 : TIME;
      VARIABLE t1 : TIME;
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

         pwm_func_model_data_s  <= ( time_high_1 => 1 ms,
                                     time_high_2 => 1 ms,
                                     offset      => 0 ns,
                                     on_off      => '1', 
                                     period_1    => 2 ms,
                                     period_2    => 2 ms);

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
         report_fname   => "TC_RS201.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS201",
         test_module    => "Input IF",
         tc_revision    => "2.0",
         tc_date        => "10 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Tests Power Supply status input error counter",
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

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/error_counter_filter_i0/fault_i",   "x_ps1_fail_s0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/error_counter_filter_i0/fault_o",   "x_ps1_fail_s1", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/error_counter_filter_i0/counter_r", "x_counter_r_i0", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/error_counter_filter_i1/fault_i",   "x_ps2_fail_s0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/error_counter_filter_i1/fault_o",   "x_ps2_fail_s1", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/error_counter_filter_i1/counter_r", "x_counter_r_i1", 0);

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
         "Verify the error counter decrementation capability due to a 'Power Supply 1 Status' fault ");

      -----------------------------------------------------------------------------------------------------------         
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.1");
      tfy_wr_step( report_file, now, "2.1", 
         "Set both Power Supply Status signals with valid values, i.e. psX_stat_i = '1' ");

      uut_in.ps1_stat_s <= '1';
      uut_in.ps2_stat_s <= '1';
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.1",
         "Check if the no-persistent error flags are '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_ps1_fail_s0 = '1' OR x_ps2_fail_s0 = '1'),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.2",
         "Check if the persistent error flags are '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_ps1_fail_s1 = '1' OR x_ps2_fail_s1 = '1'),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.3",
         "Check if the error counters are '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => (x_counter_r_i0 = "000000" AND x_counter_r_i1 = "000000"),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------                 
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.2");
      tfy_wr_step( report_file, now, "2.2",
         "Force an 'Power Supply 1 Status' error");

      uut_in.ps1_stat_s <= '0';
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.1",
         "Check if the no-persistent 'Power Supply 1 Status' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_ps1_fail_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.2",
         "Check if the persistent 'Power Supply 1 Status' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_ps1_fail_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("2.2.3", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------                 
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.3");
      tfy_wr_step( report_file, now, "2.3",
         "Verify that the increase rate of the error counter is 500ms");

      WAIT UNTIL x_counter_r_i0 = "000001" FOR 2*C_COUNTER_PERIOD;
      t0 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.2",
         "Wait until the error counter is incremented by '1', and stamp its time (t1 = now)");

      WAIT UNTIL x_counter_r_i0 = "000010" FOR 2*C_COUNTER_PERIOD;
      t1 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.3",
         "Check if 'dt = t1 - t0' is equal to the specified rate of 500ms (Expected: TRUE)");

      dt := t1 - t0;

      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => (C_COUNTER_PERIOD * 0.98),
                expected_max   => (C_COUNTER_PERIOD * 1.02),
                report_file    => report_file,
                pass           => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.4",
         "Check if the no-persistent 'Power Supply 1 Status' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_ps1_fail_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.5",
         "Check if the persistent 'Power Supply 1 Status' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_ps1_fail_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.6",
         "Check if the 'Power Supply 1 Status' error counter is neither '101000' nor '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i0 = "000010",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("2.3.7", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.4");
      tfy_wr_step( report_file, now, "2.4", 
         "Set both Power Supply Status signals with valid values, i.e. psX_stat_i = '1', and wait 1.1 sec ");

      uut_in.ps1_stat_s <= '1';
      uut_in.ps2_stat_s <= '1';
      WAIT FOR 1.1 sec;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.1",
         "Check if the no-persistent 'Power Supply 1 Status' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_ps1_fail_s0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.2",
         "Check if the persistent 'Power Supply 1 Status' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_ps1_fail_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.3",
         "Check if the 'Power Supply 1 Status' error counter is '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i0 = "000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("2.4.4", FALSE, minor_flt_report_s);


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "Verify the error counter decrementation capability due to a 'Power Supply 2 Status' fault ");

      -----------------------------------------------------------------------------------------------------------         
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.1");
      tfy_wr_step( report_file, now, "3.1", 
         "Set both Power Supply Status signals with valid values, i.e. psX_stat_i = '1' ");

      uut_in.ps1_stat_s <= '1';
      uut_in.ps2_stat_s <= '1';
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.1",
         "Check if the no-persistent error flags are '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_ps1_fail_s0 = '1' OR x_ps2_fail_s0 = '1'),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.2",
         "Check if the persistent error flags are '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_ps1_fail_s1 = '1' OR x_ps2_fail_s1 = '1'),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.3",
         "Check if the error counters are '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => (x_counter_r_i0 = "000000" AND x_counter_r_i1 = "000000"),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------                 
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.2");
      tfy_wr_step( report_file, now, "3.2",
         "Force an 'Power Supply 2 Status' error");

      uut_in.ps2_stat_s <= '0';
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.1",
         "Check if the no-persistent 'Power Supply 2 Status' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_ps2_fail_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.2",
         "Check if the persistent 'Power Supply 2 Status' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_ps2_fail_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("3.2.3", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------                 
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.3");
      tfy_wr_step( report_file, now, "3.3",
         "Verify that the increase rate of the error counter is 500ms");

      WAIT UNTIL x_counter_r_i1 = "000001" FOR 2*C_COUNTER_PERIOD;
      t0 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.2",
         "Wait until the error counter is incremented by '1', and stamp its time (t1 = now)");

      WAIT UNTIL x_counter_r_i1 = "000010" FOR 2*C_COUNTER_PERIOD;
      t1 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.3",
         "Check if 'dt = t1 - t0' is equal to the specified rate of 500ms (Expected: TRUE)");

      dt := t1 - t0;

      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => (C_COUNTER_PERIOD * 0.98),
                expected_max   => (C_COUNTER_PERIOD * 1.02),
                report_file    => report_file,
                pass           => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.4",
         "Check if the no-persistent 'Power Supply 2 Status' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_ps2_fail_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.5",
         "Check if the persistent 'Power Supply 2 Status' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_ps2_fail_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.6",
         "Check if the 'Power Supply 2 Status' error counter is neither '101000' nor '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i1 = "000010",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("3.3.7", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------         
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.4");
      tfy_wr_step( report_file, now, "3.4", 
         "Set both Power Supply Status signals with valid values, i.e. psX_stat_i = '1', and wait 1.1 sec ");

      uut_in.ps1_stat_s <= '1';
      uut_in.ps2_stat_s <= '1';
      WAIT FOR 1.1 sec;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.1",
         "Check if the no-persistent 'Power Supply 2 Status' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_ps2_fail_s0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.2",
         "Check if the persistent 'Power Supply 2 Status' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_ps2_fail_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.3",
         "Check if the 'Power Supply 2 Status' error counter is '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i1 = "000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("3.4.4", FALSE, minor_flt_report_s);


      --==============
      -- Step 4 
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------#");
      tfy_wr_step( report_file, now, "4", 
         "Verify the permanent fault capability due to a 'Power Supply 1 Status' fault");

      -----------------------------------------------------------------------------------------------------------         
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.1");
      tfy_wr_step( report_file, now, "4.1", 
         "Set both Power Supply Status signals with valid values, i.e. psX_stat_i = '1' ");

      uut_in.ps1_stat_s <= '1';
      uut_in.ps2_stat_s <= '1';
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.1",
         "Check if the no-persistent error flags are '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_ps1_fail_s0 = '1' OR x_ps2_fail_s0 = '1'),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.2",
         "Check if the persistent error flags are '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_ps1_fail_s1 = '1' OR x_ps2_fail_s1 = '1'),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.3",
         "Check if the error counters are '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => (x_counter_r_i0 = "000000" AND x_counter_r_i1 = "000000"),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.4",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_PSU1_FAILURE_BIT, '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PSU2_FAILURE_BIT, '0', alarm_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("4.1.5", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.2");
      tfy_wr_step( report_file, now, "4.2",
         "Force an 'Power Supply 1 Status' error");

      uut_in.ps1_stat_s <= '0';
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.3");
      tfy_wr_step( report_file, now, "4.3",
         "Wait a sufficient time to the fault be considered permanent (> 40*500ms)");

      WAIT FOR 40*C_COUNTER_PERIOD;
      WAIT FOR 0.2*C_COUNTER_PERIOD;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.1",
         "Check if the no-persistent 'Power Supply 1 Status' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_ps1_fail_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.2",
         "Check if the persistent 'Power Supply 1 Status' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_ps1_fail_s1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.3",
         "Check if the 'Power Supply 1 Status' error counter is '101000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i0 = "101000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("4.3.4", TRUE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.5",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_PSU1_FAILURE_BIT, '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PSU2_FAILURE_BIT, '0', alarm_code_i);

      -----------------------------------------------------------------------------------------------------------         
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.4");
      tfy_wr_step( report_file, now, "4.4", 
         "Set both Power Supply Status signals with valid values, i.e. psX_stat_i = '1', and wait 1 sec ");

      uut_in.ps1_stat_s <= '1';
      uut_in.ps2_stat_s <= '1';
      WAIT FOR 1 sec;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.1",
         "Check if the no-persistent 'Power Supply 1 Status' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_ps1_fail_s0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.2",
         "Check if the persistent 'Power Supply 1 Status' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_ps1_fail_s1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.3",
         "Check if the 'Power Supply 1 Status' error counter is '101000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i0 = "101000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("4.4.4", TRUE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.5");
      Reset_UUT("4.5");


      --==============
      -- Step 5 
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5: -------------------------------------#");
      tfy_wr_step( report_file, now, "5", 
         "Verify the permanent fault capability due to a 'Power Supply 2 Status' fault");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.1");
      tfy_wr_step( report_file, now, "5.1", 
         "Set both Power Supply Status signals with valid values, i.e. psX_stat_i = '1' ");

      uut_in.ps1_stat_s <= '1';
      uut_in.ps2_stat_s <= '1';
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.1",
         "Check if the no-persistent error flags are '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_ps1_fail_s0 = '1' OR x_ps2_fail_s0 = '1'),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.2",
         "Check if the persistent error flags are '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => (x_ps1_fail_s1 = '1' OR x_ps2_fail_s1 = '1'),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.3",
         "Check if the error counters are '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => (x_counter_r_i0 = "000000" AND x_counter_r_i1 = "000000"),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.4",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_PSU1_FAILURE_BIT, '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PSU2_FAILURE_BIT, '0', alarm_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("5.1.5", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.2");
      tfy_wr_step( report_file, now, "5.2",
         "Force an 'Power Supply 2 Status' error");

      uut_in.ps2_stat_s <= '0';
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.3");
      tfy_wr_step( report_file, now, "5.3",
         "Wait a sufficient time to the fault be considered permanent (> 40*500ms)");

      WAIT FOR 40*C_COUNTER_PERIOD;
      WAIT FOR 0.2*C_COUNTER_PERIOD;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.1",
         "Check if the no-persistent 'Power Supply 2 Status' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_ps2_fail_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.2",
         "Check if the persistent 'Power Supply 2 Status' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_ps2_fail_s1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.3",
         "Check if the 'Power Supply 2 Status' error counter is '101000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i1 = "101000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("5.3.4", TRUE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.5",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_PSU1_FAILURE_BIT, '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_PSU2_FAILURE_BIT, '1', alarm_code_i);

      -----------------------------------------------------------------------------------------------------------         
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.4");
      tfy_wr_step( report_file, now, "5.4", 
         "Set both Power Supply Status signals with valid values, i.e. psX_stat_i = '1', and wait 1 sec ");

      uut_in.ps1_stat_s <= '1';
      uut_in.ps2_stat_s <= '1';
      WAIT FOR 1 sec;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.1",
         "Check if the no-persistent 'Power Supply 2 Status' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_ps2_fail_s0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.2",
         "Check if the persistent 'Power Supply 2 Status' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_ps2_fail_s1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.3",
         "Check if the 'Power Supply 2 Status' error counter is '101000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i1 = "101000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("5.4.4", TRUE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.5");
      Reset_UUT("5.5");

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
         tc_name        => "TC_RS201",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "10 Dec 2019",
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

END ARCHITECTURE TC_RS201;

