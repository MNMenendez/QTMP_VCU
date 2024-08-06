-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS017
-- Module      : Input IF
-- Revision    : 2.0
-- Date        : 04 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Tests the VCU continuation of normal operating during a self-test
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-17
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 24 Fev 2018
--    - CABelchior (1.0): Initial Release
-- Revision 1.1 - 16 Apr 2016
--    - VSA (1.1): CCN03 changes
-- Revision 2.0 - 04 Dec 2019
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- Notes:
-- 
-- sim -tc TC_RS017 -numstdoff -nocov
-- log -r /*
-- 
--  17  During a self-test on a channel the VCU must continue operating and shall not be influenced 
--      by any test pulses. To guarantee this, a test channel’s input is latched before a test and 
--      presented to the VCU and de-latched following the test.
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
USE WORK.txt_util_p.ALL;

ARCHITECTURE TC_RS017 OF hcmt_cpld_tc_top IS

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
   SIGNAL st_ch1_in_ctrl_s                        : ST_BEHAVIOR_CH1;
   SIGNAL st_ch2_in_ctrl_s                        : ST_BEHAVIOR_CH2;
   SIGNAL pwm_func_model_data_s                   : pwm_func_model_inputs := C_PWM_FUNC_MODEL_INPUTS_INIT;

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
    VARIABLE t0                                : TIME := 0 us;
    VARIABLE dt                                : TIME := 0 us;

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
         st_ch1_in_ctrl_s  <= (OTHERS => C_ST_FUNC_MODEL_ARRAY_INIT);
         st_ch2_in_ctrl_s  <= (OTHERS => C_ST_FUNC_MODEL_ARRAY_INIT);
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

         -------------------------------------------------
         Reset_Checker(Step & ".9");

      END PROCEDURE Reset_UUT;


    BEGIN

      --------------------------------------------------------
      -- Testcase Start Sequence
      --------------------------------------------------------
      tfy_tc_start(
         report_fname   => "TC_RS017.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS017",
         test_module    => "Input IF",
         tc_revision    => "2.0",
         tc_date        => "04 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Tests the VCU continuation of normal operating during a self-test",
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
      -- Default TC Initializations
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
         "Check the VCU continuation of normal operating during a self-test");

      tfy_wr_step( report_file, now, "2.1", "Wait until the end of both CH1 and CH2 self-tests");
      WAIT UNTIL falling_edge(uut_out.test_low_ch1_s);    -- End of the CH1 self-test
      WAIT UNTIL falling_edge(uut_out.test_low_ch2_s);    -- End of the CH2 self-test
      WAIT UNTIL falling_edge(x_selftest_in_progress_s);  -- End of self-test routine
      WAIT FOR 10 ms;

      tfy_wr_step( report_file, now, "2.2", "Check if any dual channel event was generated by any test pulses");
      tfy_check(
         relative_time   => now, 
         received        => dual_channel_event_latch_r = "000000000",
         expected        => TRUE,
         equality        => TRUE,
         report_file     => report_file,
         pass            => pass
      );
      WAIT FOR 10 ms;

      tfy_wr_step( report_file, now, "2.3", "Check if any single channel event was generated by any test pulses");
      tfy_check(
         relative_time   => now, 
         received        => single_channel_event_latch_r = "00000",
         expected        => TRUE,
         equality        => TRUE,
         report_file     => report_file,
         pass            => pass
      );
      WAIT FOR 10 ms;

      --------------------------------------------------------
      -- END
      --------------------------------------------------------

      WAIT FOR 1 ms;

      --------------------------------------------------------
      -- Testcase End Sequence
      --------------------------------------------------------

      tfy_tc_end(
         tc_pass        => pass,
         report_file    => report_file,
         tc_name        => "TC_RS017",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchio",
         tc_date        => "04 Dec 2019",
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

    minor_flt_report_s			<= uut_out.tms_minor_fault_s AND uut_out.disp_minor_fault_s;

END ARCHITECTURE TC_RS017;

