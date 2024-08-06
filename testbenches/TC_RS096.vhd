-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS096
-- Module      : Input IF
-- Revision    : 2.0
-- Date        : 28 Jan 2020
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Verify the logic equation for the 25km/h speed range fault
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-096
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 05 Mar 2018
--    - CABelchior (1.0): Initial Release
-- Revision 1.01 - 
--    -  (1.01): sim -tc TC_RS096 -nocov
-- Revision 1.1 - 16 May 2019
--    -  VSA (1.1): CCN03 changes
-- Revision 2.0 - 28 Jan 2020
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- sim -tc TC_RS096 -nocov -numstdoff
-- log -r /*
--
-- 96 A 25km/h speed range fault shall be implemented according to the following logic equation:
--    ( AN_R3A NAND AN_R3B ) AND ( AN_R4A OR AN_R4B )
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

ARCHITECTURE TC_RS096 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Type Definitions
   --------------------------------------------------------

   TYPE speed_cases_typ IS ARRAY(10 DOWNTO 0) OF STD_LOGIC_VECTOR(9 DOWNTO 0);

   TYPE check_typ IS RECORD
      AN_4A : STD_LOGIC; -- UUT/spd_h25kmh_a_i
      AN_4B : STD_LOGIC; -- UUT/spd_h25kmh_b_i
      AN_3A : STD_LOGIC; -- UUT/spd_h23kmh_a_i
      AN_3B : STD_LOGIC; -- UUT/spd_h23kmh_b_i
      FAULT : STD_LOGIC; -- UUT/input_if_i0/analog_if_i0/spd_err_o
   END RECORD;
   TYPE truth_table_typ IS ARRAY(1 TO 16) OF check_typ;

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

   CONSTANT C_TRUTH_TABLE : truth_table_typ := ( 
      --      4A   4B   3A   3B   R
      1  => ( '0', '0', '0', '0', '0'),
      2  => ( '0', '0', '0', '1', '0'),
      3  => ( '0', '0', '1', '0', '0'),
      4  => ( '0', '0', '1', '1', '0'),
      5  => ( '0', '1', '0', '0', '1'),
      6  => ( '0', '1', '0', '1', '1'),
      7  => ( '0', '1', '1', '0', '1'),
      8  => ( '0', '1', '1', '1', '0'),
      9  => ( '1', '0', '0', '0', '1'),
      10 => ( '1', '0', '0', '1', '1'),
      11 => ( '1', '0', '1', '0', '1'),
      12 => ( '1', '0', '1', '1', '0'),
      13 => ( '1', '1', '0', '0', '1'),
      14 => ( '1', '1', '0', '1', '1'),
      15 => ( '1', '1', '1', '0', '1'),
      16 => ( '1', '1', '1', '1', '0')
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

      PROCEDURE Set_Truth_Table_Cases(spd_cases : NATURAL) IS
      BEGIN
         uut_in.spd_h25kmh_a_s     <= C_TRUTH_TABLE(spd_cases).AN_4A;
         uut_in.spd_h25kmh_b_s     <= C_TRUTH_TABLE(spd_cases).AN_4B;
         uut_in.spd_h23kmh_a_s     <= C_TRUTH_TABLE(spd_cases).AN_3A;
         uut_in.spd_h23kmh_b_s     <= C_TRUTH_TABLE(spd_cases).AN_3B;
      END PROCEDURE Set_Truth_Table_Cases;

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
            "Set analog speed to [3 - 23 km/h]");
         Set_Speed_Cases(2);               -- Analog Speed -> 3 - 23 km/h

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
         report_fname   => "TC_RS096.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS096",
         test_module    => "Input IF",
         tc_revision    => "2.0",
         tc_date        => "28 Jan 2020",
         tester_name    => "CABelchior",
         tc_description => "Verify the logic equation for the 25km/h speed range fault",
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
         "Test the logic equation that generates a 25km/h speed range fault");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1", 
         "Set train's speed as an '3 - 23 km/h' value, i.e. C_SPEED_VALUES(2)");

      Set_Speed_Cases(2);
      WAIT FOR 10 us;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_AN_INPUT_FAULT_BIT,'0', alarm_code_i);
      Report_LED_IF  ("-", C_LED_AN_INPUT_RED_BIT,   '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("2.3", FALSE, minor_flt_report_s);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4", 
         "For all rows of the truth table of the specified logic equation, do:");

      FOR i IN 1 TO 16 LOOP
         report "For ("& str(i)&") ";

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.4." & str(i),
            "For analog inputs as Set_Truth_Table_Cases("& str(i)&"), do:");

         -----------------------------------------------------------------------------------------------------------
         Reset_UUT("2.4." & str(i) &".1");

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.4." & str(i) &".2",
            "Set analog inputs as Set_Truth_Table_Cases("& str(i)&")");

         Set_Truth_Table_Cases(i);
         WAIT FOR 2 ms;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.4." & str(i) &".3",
            "Wait a sufficient time to the fault be considered permanent (> 40*500ms)");

         WAIT FOR 40*C_COUNTER_PERIOD;
         WAIT FOR 0.2*C_COUNTER_PERIOD;

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.4." & str(i) &".4",
            "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
         WAIT FOR C_POOL_PERIOD * 2;

         Report_Diag_IF ("-", C_DIAG_AN_INPUT_FAULT_BIT, C_TRUTH_TABLE(i).FAULT, alarm_code_i);
         Report_LED_IF  ("-", C_LED_AN_INPUT_RED_BIT,    C_TRUTH_TABLE(i).FAULT, led_code_i);

         -----------------------------------------------------------------------------------------------------------
         IF C_TRUTH_TABLE(i).FAULT = '0' THEN
            Report_Minor_Fault("2.4." & str(i) &".5", FALSE, minor_flt_report_s);
         ELSE
            Report_Minor_Fault("2.4." & str(i) &".5", TRUE, minor_flt_report_s);
         END IF;
         WAIT FOR 1 ms;
   
      END LOOP;

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
         tc_name        => "TC_RS096",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "28 Jan 2020",
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

END ARCHITECTURE TC_RS096;

