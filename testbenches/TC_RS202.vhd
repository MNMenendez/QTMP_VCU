-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS202
-- Module      : Input IF
-- Revision    : 2.0
-- Date        : 11 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Verify the error counter decrementation capability for all error conditions of the analog speed inputs module.
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-202
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 16 Jul 2019
--    - CABelchior (1.0): Initial Release for CCN03
-- Revision 2.0 - 11 Dec 2019
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- sim -tc TC_RS202 -nocov -numstdoff
-- log -r /*
--
-- 202   The analog input shall have an error counter associated with the four types of error 
--       that can occur, detailed in requirements 42, 43 and 179. They shall be incremented if 
--       there is a fault or decremented in the absence of a fault at a rate of 500mS. If a 
--       counter reaches 40 then the fault shall be considerred permanent, a minor fault flag 
--       shall be set and the speed input shall default to the maximum speed for the purposes of 
--       the VCU timing system. Any further decrementing shall be prevented.
--
--       Maximum counter value = 40 -> '101000'
-----------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;
USE WORK.txt_util_p.ALL;

ARCHITECTURE TC_RS202 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Type Definitions
   --------------------------------------------------------

   TYPE speed_cases_typ IS ARRAY(10 DOWNTO 0) OF STD_LOGIC_VECTOR(9 DOWNTO 0);

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------
   CONSTANT C_COUNTER_PERIOD                      : TIME := 500 ms;

   CONSTANT C_SPEED_VALUES : speed_cases_typ := (
      0  => "0000000000",    -- Under Range 
      1  => "0000000001",    -- 0 – 3 km/h 
      2  => "0000000011",    -- 3 – 23 km/h 
      3  => "0000001111",    -- 23 – 25 km/h 
      4  => "0000111111",    -- 25 – 75 km/h 
      5  => "0001111111",    -- 75 – 90 km/h 
      6  => "0011111111",    -- 90 – 110 km/h 
      7  => "0111111111",    -- > 110 km/h 
      8  => "1111111111",    -- Over Range 
      9  => "0101111111",    -- Invalid due to ‘0’ interspersed between ‘1’s
      10 => "0000110111"     -- 25km/h speed range fault 
   );

   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------
   SIGNAL x_opmode_curst_r                        : opmode_st_t;
   SIGNAL x_vcut_curst_r                          : vcut_st_t;

   -- Analog Speed Encoder IF
   SIGNAL x_spd_in_s                              : STD_LOGIC_VECTOR(9 DOWNTO 0); -- Analog Inputs (Speed)   -> Inputs
   SIGNAL x_spd_out_r                             : STD_LOGIC_VECTOR(7 DOWNTO 0); -- Analog Inputs (Speed)   -> Outputs

   -- Analog Speed Encoder IF: Error Counter Filter
   SIGNAL x_udr_rng_s0                            : STD_LOGIC; -- under range flag before counter
   SIGNAL x_udr_rng_s1                            : STD_LOGIC; -- under range flag after counter
   SIGNAL x_counter_r_i0                          : UNSIGNED(5 DOWNTO 0); -- udr_rng_s0

   SIGNAL x_ovr_rng_s0                            : STD_LOGIC; -- over range flag before counter
   SIGNAL x_ovr_rng_s1                            : STD_LOGIC; -- over range flag after counter
   SIGNAL x_counter_r_i1                          : UNSIGNED(5 DOWNTO 0); -- ovr_rng_s0

   SIGNAL x_inv_spd_s0                            : STD_LOGIC; -- invalid speed flag before counter
   SIGNAL x_inv_spd_s1                            : STD_LOGIC; -- invalid speed flag after counter
   SIGNAL x_counter_r_i2                          : UNSIGNED(5 DOWNTO 0); -- inv_spd_s0

   SIGNAL x_spd_25km_flt_2_s0                     : STD_LOGIC; -- 25km/h range flag before counter
   SIGNAL x_spd_25km_flt_2_s1                     : STD_LOGIC; -- 25km/h range flag after counter
   SIGNAL x_counter_r_i3                          : UNSIGNED(5 DOWNTO 0); -- spd_25km_flt_2_s0   

   --------------------------------------------------------
   -- Drive Probes
   --------------------------------------------------------

   --------------------------------------------------------
   -- User Signals //TODO SIGNALs
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
         uut_in.spd_over_spd_s     <= C_SPEED_VALUES(spd_cases)(9);
         uut_in.spd_h110kmh_s      <= C_SPEED_VALUES(spd_cases)(8);
         uut_in.spd_h90kmh_s       <= C_SPEED_VALUES(spd_cases)(7);
         uut_in.spd_h75kmh_s       <= C_SPEED_VALUES(spd_cases)(6);
         uut_in.spd_h25kmh_a_s     <= C_SPEED_VALUES(spd_cases)(5);
         uut_in.spd_h25kmh_b_s     <= C_SPEED_VALUES(spd_cases)(4); -- Only used for 25km/h range fault (OPL#115)
         uut_in.spd_h23kmh_a_s     <= C_SPEED_VALUES(spd_cases)(3);
         uut_in.spd_h23kmh_b_s     <= C_SPEED_VALUES(spd_cases)(2); -- Only used for 25km/h range fault (OPL#115)
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
         report_fname   => "TC_RS202.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS202",
         test_module    => "Input IF",
         tc_revision    => "2.0",
         tc_date        => "11 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Verify the error counter decrementation capability for all error conditions of the analog speed inputs module.",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_top_tb",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s
      );

      --------------------------------------------------------
      -- Link Spy Probes
      --------------------------------------------------------
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_fsm_i0/opmode_curst_r",  "x_opmode_curst_r", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/vcut_curst_r","x_vcut_curst_r", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/spd_in_s",         "x_spd_in_s", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/spd_out_r",        "x_spd_out_r", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i0/fault_i",   "x_udr_rng_s0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i0/fault_o",   "x_udr_rng_s1", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i0/counter_r", "x_counter_r_i0", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i1/fault_i",   "x_ovr_rng_s0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i1/fault_o",   "x_ovr_rng_s1", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i1/counter_r", "x_counter_r_i1", 0);
      
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i2/fault_i",   "x_inv_spd_s0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i2/fault_o",   "x_inv_spd_s1", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i2/counter_r", "x_counter_r_i2", 0);
      
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i3/fault_i",   "x_spd_25km_flt_2_s0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i3/fault_o",   "x_spd_25km_flt_2_s1", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i3/counter_r", "x_counter_r_i3", 0);

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
      tfy_wr_console(" [*] Step 2: -------------------------------------#");
      tfy_wr_step( report_file, now, "2", 
         "Verify the error counter decrementation capability due to an 'Under Range' fault (REQ 42_202)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.1");
      tfy_wr_step( report_file, now, "2.1", 
         "Set the analog input signals with valid values, i.e. C_SPEED_VALUES(1)");

      Set_Speed_Cases(1);
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.1",
         "Check if the no-persistent 'Under Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_udr_rng_s0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.2",
         "Check if the persistent 'Under Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_udr_rng_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.3",
         "Check if the 'Under Range' error counter is '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i0 = "000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("2.1.4", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.2");
      tfy_wr_step( report_file, now, "2.2",
         "Force an 'Under Range' error, i.e. C_SPEED_VALUES(0)");

      Set_Speed_Cases(0);
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.1",
         "Check if the no-persistent 'Under Range' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_udr_rng_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.2",
         "Check if the persistent 'Under Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_udr_rng_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("2.2.3", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.3");
      tfy_wr_step( report_file, now, "2.3",
         "Verify that the increase rate of the error counter is 500ms");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.1",
         "Wait until the error counter is incremented by '1', and stamp its time (t0 = now)");

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
         "Check if the no-persistent 'Under Range' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_udr_rng_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.5",
         "Check if the persistent 'Under Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_udr_rng_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.6",
         "Check if the 'Under Range' error counter is neither '101000' nor '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i0 = "000010",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("2.3.7", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2.4");
      tfy_wr_step( report_file, now, "2.4", 
         "Set the analog input signals with valid values, i.e. C_SPEED_VALUES(1), and wait 1.1 sec");

      Set_Speed_Cases(1);
      WAIT FOR 1.1 sec;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.1",
         "Check if the no-persistent 'Under Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_udr_rng_s0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.2",
         "Check if the persistent 'Under Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_udr_rng_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.3",
         "Check if the 'Under Range' error counter is '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i0 = "000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("2.4.4", FALSE, minor_flt_report_s);


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------#");
      tfy_wr_step( report_file, now, "3", 
         "Verify the error counter decrementation capability due to an 'Over Range' fault (REQ 42_202)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.1");
      tfy_wr_step( report_file, now, "3.1", 
         "Set the analog input signals with valid values, i.e. C_SPEED_VALUES(1)");

      Set_Speed_Cases(1);
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.1",
         "Check if the no-persistent 'Over Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_ovr_rng_s0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.2",
         "Check if the persistent 'Over Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_ovr_rng_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.3",
         "Check if the 'Over Range' error counter is '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i1 = "000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("3.1.4", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.2");
      tfy_wr_step( report_file, now, "3.2",
         "Force an 'Over Range' error, i.e. C_SPEED_VALUES(8)");

      Set_Speed_Cases(8);
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.1",
         "Check if the no-persistent 'Over Range' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_ovr_rng_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.2",
         "Check if the persistent 'Over Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_ovr_rng_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("3.2.3", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------                 
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.3");
      tfy_wr_step( report_file, now, "3.3",
         "Verify that the increase rate of the error counter is 500ms");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.1",
         "Wait until the error counter is incremented by '1', and stamp its time (t0 = now)");

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
         "Check if the no-persistent 'Over Range' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_ovr_rng_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.5",
         "Check if the persistent 'Over Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_ovr_rng_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.6",
         "Check if the 'Over Range' error counter is neither '101000' nor '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i1 = "000010",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("3.3.7", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------         
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.4");
      tfy_wr_step( report_file, now, "3.4", 
         "Set the analog input signals with valid values, i.e. C_SPEED_VALUES(1), and wait 1.1 sec");

      Set_Speed_Cases(1);
      WAIT FOR 1.1 sec;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.1",
         "Check if the no-persistent 'Over Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_ovr_rng_s0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.2",
         "Check if the persistent 'Over Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_ovr_rng_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.3",
         "Check if the 'Over Range' error counter is '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i1 = "000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("3.4.5", FALSE, minor_flt_report_s);


      --==============
      -- Step 4
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------#");
      tfy_wr_step( report_file, now, "4", 
         "Verify the error counter decrementation capability due to an 'Invalid Speed' fault (REQ 43_202)");

      -----------------------------------------------------------------------------------------------------------         
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.1");
      tfy_wr_step( report_file, now, "4.1", 
         "Set the analog input signals with valid values, i.e. C_SPEED_VALUES(1)");

      Set_Speed_Cases(1);
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.1",
         "Check if the no-persistent 'Invalid Speed' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_inv_spd_s0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.2",
         "Check if the persistent 'Invalid Speed' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_inv_spd_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.3",
         "Check if the 'Invalid Speed' error counter is '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i2 = "000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("4.1.4", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------                 
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.2");
      tfy_wr_step( report_file, now, "4.2",
         "Force an 'Invalid Speed' error, i.e. C_SPEED_VALUES(9)");

      Set_Speed_Cases(9);
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.1",
         "Check if the no-persistent 'Invalid Speed' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_inv_spd_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.2",
         "Check if the persistent 'Invalid Speed' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_inv_spd_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("4.2.3", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------                 
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.3");
      tfy_wr_step( report_file, now, "4.3",
         "Verify that the increase rate of the error counter is 500ms");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.1",
         "Wait until the error counter is incremented by '1', and stamp its time (t0 = now)");

      WAIT UNTIL x_counter_r_i2 = "000001" FOR 2*C_COUNTER_PERIOD;
      t0 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.2",
         "Wait until the error counter is incremented by '1', and stamp its time (t1 = now)");

      WAIT UNTIL x_counter_r_i2 = "000010" FOR 2*C_COUNTER_PERIOD;
      t1 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.3",
         "Check if 'dt = t1 - t0' is equal to the specified rate of 500ms (Expected: TRUE)");

      dt := t1 - t0;

      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => (C_COUNTER_PERIOD * 0.98),
                expected_max   => (C_COUNTER_PERIOD * 1.02),
                report_file    => report_file,
                pass           => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.4",
         "Check if the no-persistent 'Invalid Speed' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_inv_spd_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.5",
         "Check if the persistent 'Invalid Speed' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_inv_spd_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.6",
         "Check if the 'Invalid Speed' error counter is neither '101000' nor '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i2 = "000010",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("4.3.7", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------         
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.4");
      tfy_wr_step( report_file, now, "4.4", 
         "Set the analog input signals with valid values, i.e. C_SPEED_VALUES(1), and wait 1.1 sec");

      Set_Speed_Cases(1);
      WAIT FOR 1.1 sec;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.1",
         "Check if the no-persistent 'Invalid Speed' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_inv_spd_s0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.2",
         "Check if the persistent 'Invalid Speed' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_inv_spd_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.3",
         "Check if the 'Invalid Speed' error counter is '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i2 = "000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("4.4.5", FALSE, minor_flt_report_s);


      --==============
      -- Step 5
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5: -------------------------------------#");
      tfy_wr_step( report_file, now, "5", 
         "Verify the error counter decrementation capability due to an '25km/h Speed Range' fault (REQ 179_202)");

      -----------------------------------------------------------------------------------------------------------         
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.1");
      tfy_wr_step( report_file, now, "5.1", 
         "Set the analog input signals with valid values, i.e. C_SPEED_VALUES(1)");

      Set_Speed_Cases(1);
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.1",
         "Check if the no-persistent '25km/h Speed Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_spd_25km_flt_2_s0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.2",
         "Check if the persistent '25km/h Speed Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_spd_25km_flt_2_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.3",
         "Check if the '25km/h Speed Range' error counter is '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i3 = "000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("5.1.4", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------                 
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.2");
      tfy_wr_step( report_file, now, "5.2",
         "Force an '25km/h Speed Range' error, i.e. C_SPEED_VALUES(10)");

      Set_Speed_Cases(10);
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.1",
         "Check if the no-persistent '25km/h Speed Range' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_spd_25km_flt_2_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.2",
         "Check if the persistent '25km/h Speed Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_spd_25km_flt_2_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("5.2.3", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------                 
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.3");
      tfy_wr_step( report_file, now, "5.3",
         "Verify that the increase rate of the error counter is 500ms");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.1",
         "Wait until the error counter is incremented by '1', and stamp its time (t0 = now)");

      WAIT UNTIL x_counter_r_i3 = "000001" FOR 2*C_COUNTER_PERIOD;
      t0 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.2",
         "Wait until the error counter is incremented by '1', and stamp its time (t1 = now)");

      WAIT UNTIL x_counter_r_i3 = "000010" FOR 2*C_COUNTER_PERIOD;
      t1 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.3",
         "Check if 'dt = t1 - t0' is equal to the specified rate of 500ms (Expected: TRUE)");

      dt := t1 - t0;

      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => (C_COUNTER_PERIOD * 0.98),
                expected_max   => (C_COUNTER_PERIOD * 1.02),
                report_file    => report_file,
                pass           => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.4",
         "Check if the no-persistent '25km/h Speed Range' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_spd_25km_flt_2_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.5",
         "Check if the persistent '25km/h Speed Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_spd_25km_flt_2_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.6",
         "Check if the '25km/h Speed Range' error counter is neither '101000' nor '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i3 = "000010",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("5.3.7", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------         
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.4");
      tfy_wr_step( report_file, now, "5.4", 
         "Set the analog input signals with valid values, i.e. C_SPEED_VALUES(1), and wait 1.1 sec");

      Set_Speed_Cases(1);
      WAIT FOR 1.1 sec;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.1",
         "Check if the no-persistent '25km/h Speed Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_spd_25km_flt_2_s0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.2",
         "Check if the persistent '25km/h Speed Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_spd_25km_flt_2_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.3",
         "Check if the '25km/h Speed Range' error counter is '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i3 = "000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("5.4.5", FALSE, minor_flt_report_s);

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
         tc_name        => "TC_RS202",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "11 Dec 2019",
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

END ARCHITECTURE TC_RS202;

