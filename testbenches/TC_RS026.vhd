-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS026
-- Module      : Input IF
-- Revision    : 2.0
-- Date        : 05 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Tests the input maximum differential propagation requirement compliance
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-26
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 06 Apr 2018
--    - CABelchior (1.0): Initial Release
-- Revision 1.1 - 19 Apr 2019
--    - VSA (1.1): CCN03 changes
-- Revision 2.0 - 04 Dec 2019
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- Notes:
-- 
-- sim -tc TC_RS026 -numstdoff -nocov
-- log -r /*
--
-- 26 A maximum differential propagation of 15.625us (+ a tolerance of 15.625 us) shall 
--    be accounted for all Digital Inputs classified as 'Dual-Channel'.
--
-- This check is per transition. In a 'rise than falling' type of signal, if just one of its 
-- transition falls on this check, the signal will be masked
--
-- Borderline conditions:
--  Scenario 1: input pulses sync with the rising_edge (x_pulse15_625us_s)
--  Scenario 2: input pulses sync with the falling_edge(x_pulse15_625us_s)
--
--  Results:
--                                                                  |---  1   ---|---  2   ---|
--   --> guaranteed diff. propagation is <  15.625us                |  generate  |  generate  |
--   --> eventually, can be              >= 15.625us and > 31.25us  |   block    |  generate  |
--   --> never                           >= 31.25us                 |   block    |   block    |
-----------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;
USE WORK.txt_util_p.ALL;

ARCHITECTURE TC_RS026 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Type Definitions
   --------------------------------------------------------

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------

   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------
   SIGNAL x_dual_channel_event                    : STD_LOGIC_VECTOR(8 DOWNTO 0);
   SIGNAL x_pulse15_625us_s                       : STD_LOGIC;     -- pulse every 15.625 us

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

   SIGNAL dual_in_ch1                             : STD_LOGIC_VECTOR(8 DOWNTO 0) := (OTHERS => '0');
   SIGNAL dual_in_ch2                             : STD_LOGIC_VECTOR(8 DOWNTO 0) := (OTHERS => '0');

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
         st_ch1_in_ctrl_s  <= (OTHERS => BYPASS);     -- ATTENTION: The default is C_ST_FUNC_MODEL_ARRAY_INIT, but this test requires BYPASS
         st_ch2_in_ctrl_s  <= (OTHERS => BYPASS);     -- ATTENTION: The default is C_ST_FUNC_MODEL_ARRAY_INIT, but this test requires BYPASS
         fb_func_model_behaviour <= C_OUT_FB_FUNC_MODEL_BEHAVIOUR_INIT;
   
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

      PROCEDURE p_set_data_in (s_input: std_logic_vector (3 downto 0); delay: TIME) IS
      BEGIN
         CASE s_input is
            when "0000" => 
               uut_in.cab_act_ch1_s            <='1';
               uut_in.cab_act_ch2_s            <='1' AFTER delay; -- debounce_out_s(0)
               WAIT FOR 1 ms;
               uut_in.cab_act_ch1_s            <='0';
               uut_in.cab_act_ch2_s            <='0';
               WAIT FOR 1 ms;

            when "0001" => 
               uut_in.not_isol_ch1_s           <='1';
               uut_in.not_isol_ch2_s           <='1' AFTER delay; -- debounce_out_s(1)
               WAIT FOR 1 ms;
               uut_in.not_isol_ch1_s           <='0';
               uut_in.not_isol_ch2_s           <='0';
               WAIT FOR 1 ms;

            when "0010" => 
               uut_in.bcp_75_ch1_s             <='1';
               uut_in.bcp_75_ch2_s             <='1' AFTER delay; -- debounce_out_s(2)
               WAIT FOR 1 ms;
               uut_in.bcp_75_ch1_s             <='0';
               uut_in.bcp_75_ch2_s             <='0';
               WAIT FOR 1 ms;

            when "0011" => 
               uut_in.hcs_mode_ch1_s           <='1';
               uut_in.hcs_mode_ch2_s           <='1' AFTER delay; -- debounce_out_s(3)
               WAIT FOR 1 ms;
               uut_in.hcs_mode_ch1_s           <='0';
               uut_in.hcs_mode_ch2_s           <='0';
               WAIT FOR 1 ms;

            when "0100" => 
               uut_in.zero_spd_ch1_s           <='1';
               uut_in.zero_spd_ch2_s           <='1' AFTER delay; -- debounce_out_s(4)
               WAIT FOR 1 ms;
               uut_in.zero_spd_ch1_s           <='0';
               uut_in.zero_spd_ch2_s           <='0';
               WAIT FOR 1 ms;

            when "0101" => 
               uut_in.spd_lim_override_ch1_s   <='1';
               uut_in.spd_lim_override_ch2_s   <='1' AFTER delay; -- debounce_out_s(5)
               WAIT FOR 1 ms;
               uut_in.spd_lim_override_ch1_s   <='0';
               uut_in.spd_lim_override_ch2_s   <='0';
               WAIT FOR 1 ms;

            when "0110" => 
               uut_in.vigi_pb_ch1_s            <='1';
               uut_in.vigi_pb_ch2_s            <='1' AFTER delay; -- debounce_out_s(6)
               WAIT FOR 1 ms;
               uut_in.vigi_pb_ch1_s            <='0';
               uut_in.vigi_pb_ch2_s            <='0';
               WAIT FOR 1 ms;

            when "0111" => 
               uut_in.spd_lim_ch1_s            <='1';
               uut_in.spd_lim_ch2_s            <='1' AFTER delay; -- debounce_out_s(7)
               WAIT FOR 1 ms;
               uut_in.spd_lim_ch1_s            <='0';
               uut_in.spd_lim_ch2_s            <='0';
               WAIT FOR 1 ms;

            when "1000" => 
               uut_in.driverless_ch1_s         <='1';
               uut_in.driverless_ch2_s         <='1' AFTER delay; -- debounce_out_s(8)
               WAIT FOR 1 ms;
               uut_in.driverless_ch1_s         <='0';
               uut_in.driverless_ch2_s         <='0';
               WAIT FOR 1 ms;

            when others =>
               uut_in.cab_act_ch1_s            <='0';
               uut_in.cab_act_ch2_s            <='0';

               uut_in.not_isol_ch1_s           <='0';
               uut_in.not_isol_ch2_s           <='0';

               uut_in.bcp_75_ch1_s             <='0';
               uut_in.bcp_75_ch2_s             <='0';

               uut_in.hcs_mode_ch1_s           <='0';
               uut_in.hcs_mode_ch2_s           <='0';

               uut_in.zero_spd_ch1_s           <='0';
               uut_in.zero_spd_ch2_s           <='0';

               uut_in.spd_lim_override_ch1_s   <='0';
               uut_in.spd_lim_override_ch2_s   <='0';

               uut_in.vigi_pb_ch1_s            <='0';
               uut_in.vigi_pb_ch2_s            <='0';

               uut_in.spd_lim_ch1_s            <='0';
               uut_in.spd_lim_ch2_s            <='0';

               uut_in.driverless_ch1_s         <='0';
               uut_in.driverless_ch2_s         <='0';

         END CASE;
      END PROCEDURE p_set_data_in;

   BEGIN

      --------------------------------------------------------
      -- Testcase Start Sequence
      --------------------------------------------------------
      tfy_tc_start(
         report_fname   => "TC_RS026.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS026",
         test_module    => "Input IF",
         tc_revision    => "2.0",
         tc_date        => "05 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Tests the input maximum differential propagation requirement compliance",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_top_tb",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s
      );

      --------------------------------------------------------
      -- Link Spy Probes
      --------------------------------------------------------
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_compare_out_s(0)",  "x_dual_channel_event(0)", 0); -- cab_act_chX_s
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_compare_out_s(1)",  "x_dual_channel_event(1)", 0); -- not_isol_chX_s
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_compare_out_s(2)",  "x_dual_channel_event(2)", 0); -- bcp_75_chX_s
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_compare_out_s(3)",  "x_dual_channel_event(3)", 0); -- hcs_mode_chX_s
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_compare_out_s(4)",  "x_dual_channel_event(4)", 0); -- zero_spd_chX_s
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_compare_out_s(5)",  "x_dual_channel_event(5)", 0); -- spd_lim_override_chX_s
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_compare_out_s(6)",  "x_dual_channel_event(6)", 0); -- vigi_pb_chX_s
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_compare_out_s(7)",  "x_dual_channel_event(7)", 0); -- spd_lim_chX_s
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_compare_out_s(8)",  "x_dual_channel_event(8)", 0); -- driverless_chX_s

      init_signal_spy("/hcmt_cpld_top_tb/UUT/pulse15_625us_s", "x_pulse15_625us_s", 0);

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
         "Check if a diff. propagation <= 15.625us effectively generates an event");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "For all dual channel inputs, do:");

      FOR i IN 0 TO 8 LOOP
         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.1."& str(i+1),
            "Set a pulse on signal dual_in_chX("& str(i) &") with diff. propagation of 15.625us, in synch with the falling edge of x_pulse15_625us_s");

         WAIT UNTIL falling_edge(x_pulse15_625us_s);
         p_set_data_in (STD_LOGIC_VECTOR(to_unsigned(i, 4)), 15.625 us);

         ---------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.1." & str(i+1)& ".1",
            "Check if the dual_in_chX("& str(i) &") event was generated (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(i) = '1',
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         Reset_Checker("-");
      END LOOP;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2",
         "For all dual channel inputs, do:");

      FOR i IN 0 TO 8 LOOP
         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.2."& str(i+1),
            "Set a pulse on signal dual_in_chX("& str(i) &") with diff. propagation of 15.625us, in synch with the rising edge of x_pulse15_625us_s");

         WAIT UNTIL rising_edge(x_pulse15_625us_s);
         p_set_data_in (STD_LOGIC_VECTOR(to_unsigned(i, 4)), 15.625 us);

         ---------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.2." & str(i+1)& ".1",
            "Check if the dual_in_chX("& str(i) &") event was generated (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(i) = '1',
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         Reset_Checker("-");
      END LOOP;

      ---------------------------------------------------------------------------------------------------------
      Reset_UUT("2.3");


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "Check if a diff. propagation > 15.625us and < 31.250us, eventually generates an event");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1",
         "For all dual channel inputs, do:");

      FOR i IN 0 TO 8 LOOP
         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3.1."& str(i+1),
            "Set a pulse on signal dual_in_chX("& str(i) &") with diff. propagation of 31.240us, in synch with the falling edge of x_pulse15_625us_s");

         WAIT UNTIL falling_edge(x_pulse15_625us_s);
         p_set_data_in (STD_LOGIC_VECTOR(to_unsigned(i, 4)), 31.240 us);

         ---------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3.1." & str(i+1)& ".1",
            "Check if the dual_in_chX("& str(i) &") event was generated (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(i) = '1',
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         Reset_Checker("-");
      END LOOP;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2",
         "For all dual channel inputs, do:");

      FOR i IN 0 TO 8 LOOP
         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3.2."& str(i+1),
            "Set a pulse on signal dual_in_chX("& str(i) &") with diff. propagation of 31.240us, in synch with the rising edge of x_pulse15_625us_s");

         WAIT UNTIL rising_edge(x_pulse15_625us_s);
         p_set_data_in (STD_LOGIC_VECTOR(to_unsigned(i, 4)), 31.240 us);

         ---------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3.2." & str(i+1)& ".1",
            "Check if the dual_in_chX("& str(i) &") event was generated (Expected: FALSE)");

         tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(i) = '1',
                    expected      => FALSE,       equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         Reset_Checker("-");
      END LOOP;


      ---------------------------------------------------------------------------------------------------------
      Reset_UUT("3.3");


      --==============
      -- Step 4
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------------#");
      tfy_wr_step( report_file, now, "4",
         "Check if a diff. propagation >= 31.250us DO NOT generates an event");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1",
         "For all dual channel inputs, do:");

      FOR i IN 0 TO 8 LOOP
         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "4.1."& str(i+1),
            "Set a pulse on signal dual_in_chX("& str(i) &") with diff. propagation of 31.250us, in synch with the falling edge of x_pulse15_625us_s");

         WAIT UNTIL falling_edge(x_pulse15_625us_s);
         p_set_data_in (STD_LOGIC_VECTOR(to_unsigned(i, 4)), 31.250 us);

         ---------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "4.1." & str(i+1)& ".1",
            "Check if the dual_in_chX("& str(i) &") event was generated (Expected: FALSE)");

         tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(i) = '1',
                    expected      => FALSE,       equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         Reset_Checker("-");
      END LOOP;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2",
         "For all dual channel inputs, do:");

      FOR i IN 0 TO 8 LOOP
         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "4.2."& str(i+1),
            "Set a pulse on signal dual_in_chX("& str(i) &") with diff. propagation of 31.250us, in synch with the rising edge of x_pulse15_625us_s");

         WAIT UNTIL rising_edge(x_pulse15_625us_s);
         p_set_data_in (STD_LOGIC_VECTOR(to_unsigned(i, 4)), 31.250 us);

         ---------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "4.2." & str(i+1)& ".1",
            "Check if the dual_in_chX("& str(i) &") event was generated (Expected: FALSE)");

         tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(i) = '1',
                    expected      => FALSE,       equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         Reset_Checker("-");
      END LOOP;

      ---------------------------------------------------------------------------------------------------------
      Reset_UUT("4.3");


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
         tc_name        => "TC_RS026",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "05 Dec 2019",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s    
      );

   END PROCESS p_steps;

   p_event_latch: PROCESS(event_latch_rst_r, x_dual_channel_event)
   BEGIN
       IF rising_edge(event_latch_rst_r) THEN
           dual_channel_event_latch_r <= (OTHERS => '0');
       ELSE
           IF rising_edge(x_dual_channel_event(0)) THEN -- cab_act_chX_s
               dual_channel_event_latch_r(0) <= x_dual_channel_event(0);
           END IF;

           IF rising_edge(x_dual_channel_event(1)) THEN -- not_isol_chX_s
               dual_channel_event_latch_r(1) <= x_dual_channel_event(1);
           END IF;

           IF rising_edge(x_dual_channel_event(2)) THEN -- bcp_75_chX_s
               dual_channel_event_latch_r(2) <= x_dual_channel_event(2);
           END IF;

           IF rising_edge(x_dual_channel_event(3)) THEN -- hcs_mode_chX_s
               dual_channel_event_latch_r(3) <= x_dual_channel_event(3);
           END IF;

           IF rising_edge(x_dual_channel_event(4)) THEN -- zero_spd_chX_s
               dual_channel_event_latch_r(4) <= x_dual_channel_event(4);
           END IF;

           IF rising_edge(x_dual_channel_event(5)) THEN -- spd_lim_override_chX_s
               dual_channel_event_latch_r(5) <= x_dual_channel_event(5);
           END IF;

           IF rising_edge(x_dual_channel_event(6)) THEN -- vigi_pb_chX_s
               dual_channel_event_latch_r(6) <= x_dual_channel_event(6);
           END IF;

           IF rising_edge(x_dual_channel_event(7)) THEN -- spd_lim_chX_s
               dual_channel_event_latch_r(7) <= x_dual_channel_event(7);
           END IF;

           IF rising_edge(x_dual_channel_event(8)) THEN -- driverless_chX_s
               dual_channel_event_latch_r(8) <= x_dual_channel_event(8);
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

END ARCHITECTURE TC_RS026;
