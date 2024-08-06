-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS200
-- Module      : Input IF
-- Revision    : 2.0
-- Date        : 05 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Tests the additional debouncing stage on the single and dual channel inputs
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-200
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 25 Jun 2019
--    - VSA (1.0): Initial Release
-- Revision 2.0 - 04 Dec 2019
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- Notes:
-- 
-- sim -tc TC_RS200 -numstdoff -nocov
-- log -r /*
--
-- 200  An additional debouncing stage shall be added both the single channel and
--      dual channel inputs the dual channel input compare and single channel latching.
--      The self test pulses shall be filtered out before the second debouncing stage.
--      The second debouncing stage shall measure the same logic level 10000 times 
--      consecutively with a sampling frequency of approximately 15.625uS
-- 
-- Inclusion of force_fault_ch2_i and force_fault_ch1_i in this Test Case
--
-----------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;
USE WORK.txt_util_p.ALL;

ARCHITECTURE TC_RS200 OF hcmt_cpld_tc_top IS
   --------------------------------------------------------
   -- Type Definitions
   --------------------------------------------------------
   TYPE debounce_counter_t IS ARRAY(15 DOWNTO 0) OF NATURAL RANGE 0 TO 9999;

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------

   CONSTANT C_INPUT_SAMPLE_WIDTH                  : TIME := 15.625 us; -- Input sample width
   CONSTANT C_TOLERANCE_PERIOD                    : TIME := 1.5625 us;

   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------
   SIGNAL x_debouncer_input_s                      : STD_LOGIC_VECTOR(15 DOWNTO 0);
   SIGNAL x_debouncer_output_s                     : STD_LOGIC_VECTOR(15 DOWNTO 0);
   SIGNAL x_debounce_counter_s                     : debounce_counter_t;

   -- Pulse every 15.625 us
   SIGNAL x_pulse15_625us_s                        : STD_LOGIC;

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

   VARIABLE v_expected_debouncer_out           : STD_LOGIC_VECTOR(13 DOWNTO 0); -- Expected value at the 2nd debouncer output
   
   VARIABLE t0: time;
   VARIABLE t1: time;
   VARIABLE t2: time;
   VARIABLE dt: time;

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

   PROCEDURE p_set_data_in (s_input: std_logic_vector (3 downto 0); s_value: std_logic) IS
   BEGIN
      CASE s_input is
         --------------------------------------------------------
         -- dual channel
         --------------------------------------------------------
         when "0000" =>
            uut_in.cab_act_ch1_s            <=s_value; 
            uut_in.cab_act_ch2_s            <=s_value; 
         when "0001" => 
            uut_in.not_isol_ch1_s           <=s_value;
            uut_in.not_isol_ch2_s           <=s_value; 
         when "0010" =>
            uut_in.bcp_75_ch1_s             <=s_value;
            uut_in.bcp_75_ch2_s             <=s_value; 
         when "0011" => 
            uut_in.hcs_mode_ch1_s           <=s_value;
            uut_in.hcs_mode_ch2_s           <=s_value;
         when "0100" => 
            uut_in.zero_spd_ch1_s           <=s_value;
            uut_in.zero_spd_ch2_s           <=s_value; 
         when "0101" => 
            uut_in.spd_lim_override_ch1_s   <=s_value;
            uut_in.spd_lim_override_ch2_s   <=s_value;
         when "0110" => 
            uut_in.vigi_pb_ch1_s            <=s_value;
            uut_in.vigi_pb_ch2_s            <=s_value;
         when "0111" => 
            uut_in.spd_lim_ch1_s            <=s_value;
            uut_in.spd_lim_ch2_s            <=s_value;
         when "1000" => 
            uut_in.driverless_ch1_s         <=s_value;
            uut_in.driverless_ch2_s         <=s_value;

         --------------------------------------------------------
         -- single channel
         --------------------------------------------------------
         when "1001" => 
            uut_in.ss_bypass_pb_s           <=s_value;
         when "1010" => 
            uut_in.w_wiper_pb_s             <=s_value;
         when "1011" => 
            uut_in.hl_low_s                 <=s_value;
         when "1100" => 
            uut_in.horn_high_s              <=s_value;
         when "1101" => 
            uut_in.horn_low_s               <=s_value;

         --------------------------------------------------------
         -- Extra inputs
         --------------------------------------------------------
         when "1110" => 
            uut_in.force_fault_ch2_s        <=s_value;
         when "1111" => 
            uut_in.force_fault_ch1_s        <=s_value;

         when others =>
            --------------------------------------------------------
            -- dual channel
            --------------------------------------------------------
            uut_in.cab_act_ch1_s          <='0';
            uut_in.cab_act_ch2_s          <='0';

            uut_in.not_isol_ch1_s         <='0';
            uut_in.not_isol_ch2_s         <='0';

            uut_in.bcp_75_ch1_s           <='0';
            uut_in.bcp_75_ch2_s           <='0';

            uut_in.hcs_mode_ch1_s         <='0';
            uut_in.hcs_mode_ch2_s         <='0';

            uut_in.zero_spd_ch1_s         <='0';
            uut_in.zero_spd_ch2_s         <='0';

            uut_in.spd_lim_override_ch1_s <='0';
            uut_in.spd_lim_override_ch2_s <='0';

            uut_in.vigi_pb_ch1_s          <='0';
            uut_in.vigi_pb_ch2_s          <='0';

            uut_in.spd_lim_ch1_s          <='0';
            uut_in.spd_lim_ch2_s          <='0';
            
            uut_in.driverless_ch1_s       <='0';
            uut_in.driverless_ch2_s       <='0';

            --------------------------------------------------------
            -- single channel
            --------------------------------------------------------
            uut_in.ss_bypass_pb_s         <='0';
            uut_in.w_wiper_pb_s           <='0';
            uut_in.hl_low_s               <='0';
            uut_in.horn_high_s            <='0';
            uut_in.horn_low_s             <='0';

            --------------------------------------------------------
            -- Extra inputs
            --------------------------------------------------------
            uut_in.force_fault_ch2_s      <='0';
            uut_in.force_fault_ch1_s      <='0';
      END CASE;
   END PROCEDURE p_set_data_in;

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

   BEGIN

      --------------------------------------------------------
      -- Testcase Start Sequence
      --------------------------------------------------------
      tfy_tc_start(
         report_fname   => "TC_RS200.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS200",
         test_module    => "Input IF",
         tc_revision    => "2.0",
         tc_date        => "05 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Tests the additional debouncing stage on the single and dual channel inputs",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_top_tb",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s
      );

      --------------------------------------------------------
      -- Link Spy Probes
      --------------------------------------------------------

      -- Inputs of second debouncer for dual channels
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_compare_out_s(0)",   "x_debouncer_input_s(0)", 0);      -- cab_act_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_compare_out_s(1)",   "x_debouncer_input_s(1)", 0);      -- not_isol_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_compare_out_s(2)",   "x_debouncer_input_s(2)", 0);      -- bcp_75_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_compare_out_s(3)",   "x_debouncer_input_s(3)", 0);      -- hcs_mode_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_compare_out_s(4)",   "x_debouncer_input_s(4)", 0);      -- zero_spd_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_compare_out_s(5)",   "x_debouncer_input_s(5)", 0);      -- spd_lim_override_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_compare_out_s(6)",   "x_debouncer_input_s(6)", 0);      -- vigi_pb_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_compare_out_s(7)",   "x_debouncer_input_s(7)", 0);      -- spd_lim_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_compare_out_s(8)",   "x_debouncer_input_s(8)", 0);      -- driverless_chX_i

      -- Inputs of second debouncer for single channels
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_latched_in_s(0)",    "x_debouncer_input_s(9)", 0);      -- ss_bypass_pb_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_latched_in_s(1)",    "x_debouncer_input_s(10)", 0);     -- w_wiper_pb_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_latched_in_s(2)",    "x_debouncer_input_s(11)", 0);     -- hl_low_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_latched_in_s(3)",    "x_debouncer_input_s(12)", 0);     -- horn_high_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/pre_debounce_latched_in_s(4)",    "x_debouncer_input_s(13)", 0);     -- horn_low_i

      -- Inputs of second debouncer for extra inputs
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/debounce_out_s(23)",              "x_debouncer_input_s(14)", 0);     -- force_fault_ch2_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/debounce_out_s(24)",              "x_debouncer_input_s(15)", 0);     -- force_fault_ch1_i


      -- Outputs of second debouncer for dual channels
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/compare_out_s(0)",   "x_debouncer_output_s(0)", 0);      -- cab_act_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/compare_out_s(1)",   "x_debouncer_output_s(1)", 0);      -- not_isol_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/compare_out_s(2)",   "x_debouncer_output_s(2)", 0);      -- bcp_75_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/compare_out_s(3)",   "x_debouncer_output_s(3)", 0);      -- hcs_mode_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/compare_out_s(4)",   "x_debouncer_output_s(4)", 0);      -- zero_spd_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/compare_out_s(5)",   "x_debouncer_output_s(5)", 0);      -- spd_lim_override_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/compare_out_s(6)",   "x_debouncer_output_s(6)", 0);      -- vigi_pb_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/compare_out_s(7)",   "x_debouncer_output_s(7)", 0);      -- spd_lim_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/compare_out_s(8)",   "x_debouncer_output_s(8)", 0);      -- driverless_chX_i

      -- Outputs of second debouncer for single channels
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/latched_in_s(0)",    "x_debouncer_output_s(9)", 0);      -- ss_bypass_pb_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/latched_in_s(1)",    "x_debouncer_output_s(10)", 0);     -- w_wiper_pb_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/latched_in_s(2)",    "x_debouncer_output_s(11)", 0);     -- hl_low_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/latched_in_s(3)",    "x_debouncer_output_s(12)", 0);     -- horn_high_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/latched_in_s(4)",    "x_debouncer_output_s(13)", 0);     -- horn_low_i

      -- Outputs of second debouncer for extra inputs
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/force_fault_ch2_s",  "x_debouncer_output_s(14)", 0);     -- force_fault_ch2_1
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/force_fault_ch1_s",  "x_debouncer_output_s(15)", 0);     -- force_fault_ch1_1


      -- Internal counter of second debouncer for dual channels
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/debouncer_inst_i2/debouncer_single_i0(0)/debouncer_single_i/debounce_counter_r", "x_debounce_counter_s(0)");   -- cab_act_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/debouncer_inst_i2/debouncer_single_i0(1)/debouncer_single_i/debounce_counter_r", "x_debounce_counter_s(1)");   -- not_isol_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/debouncer_inst_i2/debouncer_single_i0(2)/debouncer_single_i/debounce_counter_r", "x_debounce_counter_s(2)");   -- bcp_75_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/debouncer_inst_i2/debouncer_single_i0(3)/debouncer_single_i/debounce_counter_r", "x_debounce_counter_s(3)");   -- hcs_mode_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/debouncer_inst_i2/debouncer_single_i0(4)/debouncer_single_i/debounce_counter_r", "x_debounce_counter_s(4)");   -- zero_spd_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/debouncer_inst_i2/debouncer_single_i0(5)/debouncer_single_i/debounce_counter_r", "x_debounce_counter_s(5)");   -- spd_lim_override_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/debouncer_inst_i2/debouncer_single_i0(6)/debouncer_single_i/debounce_counter_r", "x_debounce_counter_s(6)");   -- vigi_pb_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/debouncer_inst_i2/debouncer_single_i0(7)/debouncer_single_i/debounce_counter_r", "x_debounce_counter_s(7)");   -- spd_lim_chX_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/debouncer_inst_i2/debouncer_single_i0(8)/debouncer_single_i/debounce_counter_r", "x_debounce_counter_s(8)");   -- driverless_chX_i

      -- Internal counter of second debouncer for single channels
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/debouncer_inst_i1/debouncer_single_i0(0)/debouncer_single_i/debounce_counter_r", "x_debounce_counter_s(9)");   -- ss_bypass_pb_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/debouncer_inst_i1/debouncer_single_i0(1)/debouncer_single_i/debounce_counter_r", "x_debounce_counter_s(10)");  -- w_wiper_pb_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/debouncer_inst_i1/debouncer_single_i0(2)/debouncer_single_i/debounce_counter_r", "x_debounce_counter_s(11)");  -- hl_low_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/debouncer_inst_i1/debouncer_single_i0(3)/debouncer_single_i/debounce_counter_r", "x_debounce_counter_s(12)");  -- horn_high_i
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/debouncer_inst_i1/debouncer_single_i0(4)/debouncer_single_i/debounce_counter_r", "x_debounce_counter_s(13)");  -- horn_low_i

      -- Internal counter of second debouncer for extra inputs
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/debouncer_inst_i3/debouncer_single_i0(0)/debouncer_single_i/debounce_counter_r", "x_debounce_counter_s(14)");  -- force_fault_ch2_1
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/debouncer_inst_i3/debouncer_single_i0(1)/debouncer_single_i/debounce_counter_r", "x_debounce_counter_s(15)");  -- force_fault_ch1_1

      init_signal_spy("/hcmt_cpld_top_tb/UUT/pulse15_625us_s", "x_pulse15_625us_s");

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
         "Verify the time constrains of 2nd debouncer");


      FOR i IN 0 TO 15 LOOP
         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2." & str(i+1), 
         "For digital input("& str(i) &"), do:");

         ---------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2." & str(i+1) & ".1",
            "Set the digital input("& str(i) &") to '1'");
         -- WAIT UNTIL rising_edge(x_pulse15_625us_s);
         -- WAIT UNTIL falling_edge(x_pulse15_625us_s);
         p_set_data_in (STD_LOGIC_VECTOR(to_unsigned(i, 4)), '1');   -- Sets input at '1'

         ---------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2." & str(i+1) & ".2",
            "Wait until the 2nd debouncer senses the change, and stamp its time (t0 = now)");
         WAIT UNTIL x_debouncer_input_s(i) = '1' FOR 10*C_INPUT_SAMPLE_WIDTH;
         t0 := now;

         ---------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2." & str(i+1) & ".3",
            "Wait until the 2nd debouncer counter is reset, and stamp its time (t1 = now)");
         WAIT UNTIL x_debounce_counter_s(i) = 0 FOR 10*C_INPUT_SAMPLE_WIDTH;
         t1 := now;

         ---------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2." & str(i+1) & ".4",
            "Wait until the 2nd debouncer output changes, and stamp its time (t2 = now)");
         WAIT UNTIL x_debouncer_output_s(i) = '1' FOR 10010*C_INPUT_SAMPLE_WIDTH;
         t2 := now;

         ---------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2." & str(i+1) & ".5",
            "Check if the 2nd debouncer counter for digital input("& str(i) &") is 9999 (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => x_debounce_counter_s(i) = 9999,
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         ---------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2." & str(i+1) & ".6",
            "Check if the 2nd debouncer counter goes from 0 to 9999 in aprox. 10000 x 15.625us");
         tfy_check(relative_time  => now, 
                   received       => t2 - t1,
                   expected_min   => 10000*C_INPUT_SAMPLE_WIDTH - C_TOLERANCE_PERIOD,
                   expected_max   => 10000*C_INPUT_SAMPLE_WIDTH + C_TOLERANCE_PERIOD,
                   report_file    => report_file,
                   pass           => pass);

         -----------------------------------------------------------------------------------------------------------
         Reset_UUT("2." & str(i+1) & ".7");
      END LOOP;

      --------------------------------------------------------
      -- END
      --------------------------------------------------------
      wait for 2 ms;

      --------------------------------------------------------
      -- Testcase End Sequence
      --------------------------------------------------------
      tfy_tc_end(
         tc_pass        => pass,
         report_file    => report_file,
         tc_name        => "TC_RS024",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "05 Dec 2019",
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
  
END ARCHITECTURE TC_RS200;