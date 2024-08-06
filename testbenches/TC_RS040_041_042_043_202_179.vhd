-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS040_041_042_043_202_179
-- Module      : Input IF
-- Revision    : 2.0
-- Date        : 11 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Tests the digitally encoded analog inputs requirement compliance
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-40
--    FPGA-REQ-41
--    FPGA-REQ-42
--    FPGA-REQ-43
--    FPGA-REQ-202
--    FPGA-REQ-179
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 13 Jun 2019
--    - CABelchior (1.0): Initial Release for CCN03
-- Revision 2.0 - 11 Dec 2019
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- sim -tc TC_RS040_041_042_043_202_179 -nocov -numstdoff
-- log -r /*
-- 
-- 40       The train’s instantaneous speed which is obtained from on-board sensors is digitally 
--          encoded and shall be presented as a 8-bit input signal to the CPLD. 
--
-- 41,01    “00000000”  - Under Range
-- 41,02    “00000001”  - 0 – 3 km/h
-- 41,03    "00000011"  - 3 – 23 km/h
-- 41,04    "00000111"  - 23 – 25 km/h
-- 41,05    “00001111”  - 25 – 75 km/h
-- 41,06    “00011111”  - 75 – 90 km/h
-- 41,07    “00111111”  - 90 – 110 km/h
-- 41,08    “01111111”  - >110 km/h (default value if under range or over range is detected)
-- 41,09    “11111111”  - Over Range
-- 
-- 42       If the speed value indicates either “Under Range” or “Over Range” the analogue input 
--          shall trigger a corresponding fault flag.
--
-- 43       If the speed value indicates a ‘0’ interspersed between ‘1’s, the analogue input 
--          shall trigger a corresponding fault flag.
--
-- 202      The analog input shall have an error counter associated with the four types of error 
--          that can occur, detailed in requirements 42, 43 and 179. They shall be incremented if 
--          there is a fault or decremented in the absence of a fault at a rate of 500mS. If a 
--          counter reaches 40 then the fault shall be considerred permanent, a minor fault flag 
--          shall be set and the speed input shall default to the maximum speed for the purposes of 
--          the VCU timing system. Any further decrementing shall be prevented.
--
-- 179      A 25km/h speed range fault shall contribute to the analog speed error fault.
--
--          Maximum counter value = 40 -> '101000'
-----------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;
USE WORK.txt_util_p.ALL;

ARCHITECTURE TC_RS040_041_042_043_202_179 OF hcmt_cpld_tc_top IS

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
   SIGNAL udr_rng_s0                              : STD_LOGIC; -- under range flag before counter
   SIGNAL udr_rng_s1                              : STD_LOGIC; -- under range flag after counter
   SIGNAL x_counter_r_i0                          : UNSIGNED(5 DOWNTO 0); -- udr_rng_s0

   SIGNAL ovr_rng_s0                              : STD_LOGIC; -- over range flag before counter
   SIGNAL ovr_rng_s1                              : STD_LOGIC; -- over range flag after counter
   SIGNAL x_counter_r_i1                          : UNSIGNED(5 DOWNTO 0); -- ovr_rng_s0

   SIGNAL inv_spd_s0                              : STD_LOGIC; -- invalid speed flag before counter
   SIGNAL inv_spd_s1                              : STD_LOGIC; -- invalid speed flag after counter
   SIGNAL x_counter_r_i2                          : UNSIGNED(5 DOWNTO 0); -- inv_spd_s0

   SIGNAL spd_25km_flt_2_s0                       : STD_LOGIC; -- 25km/h range flag before counter
   SIGNAL spd_25km_flt_2_s1                       : STD_LOGIC; -- 25km/h range flag after counter
   SIGNAL x_counter_r_i3                          : UNSIGNED(5 DOWNTO 0); -- spd_25km_flt_2_s0   

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
         report_fname   => "TC_RS040_041_042_043_202_179.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS040_041_042_043_202_179",
         test_module    => "Input IF",
         tc_revision    => "2.0",
         tc_date        => "11 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Tests the digitally encoded analog inputs requirement compliance",
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

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i0/fault_i",   "udr_rng_s0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i0/fault_o",   "udr_rng_s1", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i0/counter_r", "x_counter_r_i0", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i1/fault_i",   "ovr_rng_s0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i1/fault_o",   "ovr_rng_s1", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i1/counter_r", "x_counter_r_i1", 0);
      
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i2/fault_i",   "inv_spd_s0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i2/fault_o",   "inv_spd_s1", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i2/counter_r", "x_counter_r_i2", 0);
      
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i3/fault_i",   "spd_25km_flt_2_s0", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/analog_if_i0/error_counter_filter_i3/fault_o",   "spd_25km_flt_2_s1", 0);
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
         "Test if the train's instantaneous speed is correctly received as an 8-bit input signal by the CPLD (REQ 40_41)");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "For all available speed values, do:");

      FOR i IN 0 TO 10 LOOP
         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.1." & str(i+1),
            "Set train's analog speed as C_SPEED_VALUES("& str(i) &")");

         Set_Speed_Cases(i);
         WAIT FOR 5 ms;   

         -----------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.1." & str(i+1) &".1", 
            "Check if analog input signals were correctly received by the CPLD and wait for 1ms");

         tfy_check( relative_time => now,         received        => x_spd_in_s = C_SPEED_VALUES(i),
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         WAIT FOR 1 ms; 
      END LOOP;

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.2");


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------#");
      tfy_wr_step( report_file, now, "3", 
         "Verify the permanent fault capability due to an 'Under Range' fault (REQ 42_202)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.1");
      tfy_wr_step( report_file, now, "3.1", 
         "Set the analog input signals with valid values, i.e. C_SPEED_VALUES(1)");

      Set_Speed_Cases(1);
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.1",
         "Check if the output speed is the default maximum speed (> 110km/h) (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_spd_out_r = "01111111",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);       

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.2",
         "Check if the no-persistent 'Under Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => udr_rng_s0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.3",
         "Check if the persistent 'Under Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => udr_rng_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.4",
         "Check if the 'Under Range' error counter is '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i0 = "000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.5",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_AN_UNDERRANGE_BIT, '0', alarm_code_i);  -- Analog Speed Under-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_OVERRANGE_BIT,  '0', alarm_code_i);  -- Analog Speed Over-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_INPUT_FAULT_BIT,'0', alarm_code_i);  -- Analog Speed Error / Minor Fault (under/over range/inconsistent 6-bit value)
      Report_LED_IF  ("-", C_LED_AN_INPUT_GREEN_BIT, '1', led_code_i);
      Report_LED_IF  ("-", C_LED_AN_INPUT_RED_BIT,   '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("3.1.6", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------                 
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.2");
      tfy_wr_step( report_file, now, "3.2",
         "Force an 'Under Range' error, i.e. C_SPEED_VALUES(0)");

      Set_Speed_Cases(0);
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.1",
         "Check if the output speed is the default maximum speed (> 110km/h) (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_spd_out_r = "01111111",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);       

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.2",
         "Check if the no-persistent 'Under Range' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => udr_rng_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.3",
         "Check if the persistent 'Under Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => udr_rng_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.4",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_AN_UNDERRANGE_BIT, '0', alarm_code_i);  -- Analog Speed Under-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_OVERRANGE_BIT,  '0', alarm_code_i);  -- Analog Speed Over-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_INPUT_FAULT_BIT,'0', alarm_code_i);  -- Analog Speed Error / Minor Fault (under/over range/inconsistent 6-bit value)
      Report_LED_IF  ("-", C_LED_AN_INPUT_GREEN_BIT, '1', led_code_i);
      Report_LED_IF  ("-", C_LED_AN_INPUT_RED_BIT,   '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("3.2.5", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------                 
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.3");
      tfy_wr_step( report_file, now, "3.3",
         "Wait a sufficient time to the fault be considered permanent (> 40*500ms)");

      WAIT FOR 40*C_COUNTER_PERIOD;
      WAIT FOR 0.2*C_COUNTER_PERIOD;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.1",
         "Check if the output speed is the default maximum speed (> 110km/h) (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_spd_out_r = "01111111",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);       

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.2",
         "Check if the no-persistent 'Under Range' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => udr_rng_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.3",
         "Check if the persistent 'Under Range' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => udr_rng_s1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.4",
         "Check if the 'Under Range' error counter is '101000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i0 = "101000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.5",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_AN_UNDERRANGE_BIT, '1', alarm_code_i);  -- Analog Speed Under-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_OVERRANGE_BIT,  '0', alarm_code_i);  -- Analog Speed Over-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_INPUT_FAULT_BIT,'1', alarm_code_i);  -- Analog Speed Error / Minor Fault (under/over range/inconsistent 6-bit value)
      Report_LED_IF  ("-", C_LED_AN_INPUT_GREEN_BIT, '0', led_code_i);
      Report_LED_IF  ("-", C_LED_AN_INPUT_RED_BIT,   '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("3.3.6", TRUE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------         
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.4");
      tfy_wr_step( report_file, now, "3.4", 
         "Set the analog input signals with valid values, i.e. C_SPEED_VALUES(1), and wait 1 sec");

      Set_Speed_Cases(1);
      WAIT FOR 1 sec;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.1",
         "Check if the output speed is the default maximum speed (> 110km/h) (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_spd_out_r = "01111111",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);       

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.2",
         "Check if the no-persistent 'Under Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => udr_rng_s0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.3",
         "Check if the persistent 'Under Range' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => udr_rng_s1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.4",
         "Check if the 'Under Range' error counter is '101000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i0 = "101000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.5",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_AN_UNDERRANGE_BIT, '1', alarm_code_i);  -- Analog Speed Under-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_OVERRANGE_BIT,  '0', alarm_code_i);  -- Analog Speed Over-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_INPUT_FAULT_BIT,'1', alarm_code_i);  -- Analog Speed Error / Minor Fault (under/over range/inconsistent 6-bit value)
      Report_LED_IF  ("-", C_LED_AN_INPUT_GREEN_BIT, '0', led_code_i);
      Report_LED_IF  ("-", C_LED_AN_INPUT_RED_BIT,   '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("3.4.6", TRUE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3.5");
      Reset_UUT("3.5");


      --==============
      -- Step 4
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------#");
      tfy_wr_step( report_file, now, "4", 
         "Verify the permanent fault capability due to an 'Over Range' fault (REQ 42_202)");      

      -----------------------------------------------------------------------------------------------------------         
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.1");
      tfy_wr_step( report_file, now, "4.1", 
         "Set the analog input signals with valid values, i.e. C_SPEED_VALUES(1)");

      Set_Speed_Cases(1);
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.1",
         "Check if the output speed is the default maximum speed (> 110km/h) (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_spd_out_r = "01111111",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);       

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.2",
         "Check if the no-persistent 'Over Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => ovr_rng_s0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.3",
         "Check if the persistent 'Over Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => ovr_rng_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.4",
         "Check if the 'Over Range' error counter is '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i1 = "000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.5",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_AN_UNDERRANGE_BIT, '0', alarm_code_i);  -- Analog Speed Under-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_OVERRANGE_BIT,  '0', alarm_code_i);  -- Analog Speed Over-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_INPUT_FAULT_BIT,'0', alarm_code_i);  -- Analog Speed Error / Minor Fault (under/over range/inconsistent 6-bit value)
      Report_LED_IF  ("-", C_LED_AN_INPUT_GREEN_BIT, '1', led_code_i);
      Report_LED_IF  ("-", C_LED_AN_INPUT_RED_BIT,   '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("4.1.6", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------                 
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.2");
      tfy_wr_step( report_file, now, "4.2",
         "Force an 'Over Range' error, i.e. C_SPEED_VALUES(8)");

      Set_Speed_Cases(8);
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.1",
         "Check if the output speed is the default maximum speed (> 110km/h) (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_spd_out_r = "01111111",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);       

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.2",
         "Check if the no-persistent 'Over Range' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => ovr_rng_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.3",
         "Check if the persistent 'Over Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => ovr_rng_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.4",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_AN_UNDERRANGE_BIT, '0', alarm_code_i);  -- Analog Speed Under-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_OVERRANGE_BIT,  '0', alarm_code_i);  -- Analog Speed Over-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_INPUT_FAULT_BIT,'0', alarm_code_i);  -- Analog Speed Error / Minor Fault (under/over range/inconsistent 6-bit value)
      Report_LED_IF  ("-", C_LED_AN_INPUT_GREEN_BIT, '1', led_code_i);
      Report_LED_IF  ("-", C_LED_AN_INPUT_RED_BIT,   '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("4.2.5", FALSE, minor_flt_report_s);      

      -----------------------------------------------------------------------------------------------------------                 
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.3");
      tfy_wr_step( report_file, now, "4.3",
         "Wait a sufficient time to the fault be considered permanent (> 40*500ms)");

      WAIT FOR 40*C_COUNTER_PERIOD;
      WAIT FOR 0.2*C_COUNTER_PERIOD;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.1",
         "Check if the output speed is the default maximum speed (> 110km/h) (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_spd_out_r = "01111111",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);       

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.2",
         "Check if the no-persistent 'Over Range' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => ovr_rng_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.3",
         "Check if the persistent 'Over Range' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => ovr_rng_s1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.4",
         "Check if the 'Over Range' error counter is '101000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i1 = "101000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.5",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_AN_UNDERRANGE_BIT, '0', alarm_code_i);  -- Analog Speed Under-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_OVERRANGE_BIT,  '1', alarm_code_i);  -- Analog Speed Over-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_INPUT_FAULT_BIT,'1', alarm_code_i);  -- Analog Speed Error / Minor Fault (under/over range/inconsistent 6-bit value)
      Report_LED_IF  ("-", C_LED_AN_INPUT_GREEN_BIT, '0', led_code_i);
      Report_LED_IF  ("-", C_LED_AN_INPUT_RED_BIT,   '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("4.3.6", TRUE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------         
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4.4");
      tfy_wr_step( report_file, now, "4.4", 
         "Set the analog input signals with valid values, i.e. C_SPEED_VALUES(1), and wait 1 sec");

      Set_Speed_Cases(1);
      WAIT FOR 1 sec;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.1",
         "Check if the output speed is the default maximum speed (> 110km/h) (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_spd_out_r = "01111111",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);       

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.2",
         "Check if the no-persistent 'Over Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => ovr_rng_s0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.3",
         "Check if the persistent 'Over Range' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => ovr_rng_s1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.4",
         "Check if the 'Over Range' error counter is '101000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i1 = "101000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.5",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_AN_UNDERRANGE_BIT, '0', alarm_code_i);  -- Analog Speed Under-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_OVERRANGE_BIT,  '1', alarm_code_i);  -- Analog Speed Over-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_INPUT_FAULT_BIT,'1', alarm_code_i);  -- Analog Speed Error / Minor Fault (under/over range/inconsistent 6-bit value)
      Report_LED_IF  ("-", C_LED_AN_INPUT_GREEN_BIT, '0', led_code_i);
      Report_LED_IF  ("-", C_LED_AN_INPUT_RED_BIT,   '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("4.4.6", TRUE, minor_flt_report_s);

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
         "Verify the permanent fault capability due to an 'Invalid Speed' fault (REQ 43_202)");      

      -----------------------------------------------------------------------------------------------------------         
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.1");
      tfy_wr_step( report_file, now, "5.1", 
         "Set the analog input signals with valid values, i.e. C_SPEED_VALUES(1)");

      Set_Speed_Cases(1);
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.1",
         "Check if the output speed is the default maximum speed (> 110km/h) (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_spd_out_r = "01111111",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);       

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.2",
         "Check if the no-persistent 'Invalid Speed' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => inv_spd_s0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.3",
         "Check if the persistent 'Invalid Speed' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => inv_spd_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.4",
         "Check if the 'Invalid Speed' error counter is '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i2 = "000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.5",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_AN_UNDERRANGE_BIT, '0', alarm_code_i);  -- Analog Speed Under-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_OVERRANGE_BIT,  '0', alarm_code_i);  -- Analog Speed Over-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_INPUT_FAULT_BIT,'0', alarm_code_i);  -- Analog Speed Error / Minor Fault (under/over range/inconsistent 6-bit value)
      Report_LED_IF  ("-", C_LED_AN_INPUT_GREEN_BIT, '1', led_code_i);
      Report_LED_IF  ("-", C_LED_AN_INPUT_RED_BIT,   '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("5.1.6", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------                 
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.2");
      tfy_wr_step( report_file, now, "5.2",
         "Force an 'Invalid Speed' error, i.e. C_SPEED_VALUES(9)");

      Set_Speed_Cases(9);
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.1",
         "Check if the output speed is the default maximum speed (> 110km/h) (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_spd_out_r = "01111111",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);       

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.2",
         "Check if the no-persistent 'Invalid Speed' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => inv_spd_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.3",
         "Check if the persistent 'Invalid Speed' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => inv_spd_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.4",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_AN_UNDERRANGE_BIT, '0', alarm_code_i);  -- Analog Speed Under-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_OVERRANGE_BIT,  '0', alarm_code_i);  -- Analog Speed Over-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_INPUT_FAULT_BIT,'0', alarm_code_i);  -- Analog Speed Error / Minor Fault (under/over range/inconsistent 6-bit value)
      Report_LED_IF  ("-", C_LED_AN_INPUT_GREEN_BIT, '1', led_code_i);
      Report_LED_IF  ("-", C_LED_AN_INPUT_RED_BIT,   '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("5.2.5", FALSE, minor_flt_report_s);      

      -----------------------------------------------------------------------------------------------------------                 
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.3");
      tfy_wr_step( report_file, now, "5.3",
         "Wait a sufficient time to the fault be considered permanent (> 40*500ms)");

      WAIT FOR 40*C_COUNTER_PERIOD;
      WAIT FOR 0.2*C_COUNTER_PERIOD;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.1",
         "Check if the output speed is the default maximum speed (> 110km/h) (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_spd_out_r = "01111111",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);       

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.2",
         "Check if the no-persistent 'Invalid Speed' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => inv_spd_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.3",
         "Check if the persistent 'Invalid Speed' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => inv_spd_s1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.4",
         "Check if the 'Invalid Speed' error counter is '101000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i2 = "101000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3.5",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_AN_UNDERRANGE_BIT, '0', alarm_code_i);  -- Analog Speed Under-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_OVERRANGE_BIT,  '0', alarm_code_i);  -- Analog Speed Over-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_INPUT_FAULT_BIT,'1', alarm_code_i);  -- Analog Speed Error / Minor Fault (under/over range/inconsistent 6-bit value)
      Report_LED_IF  ("-", C_LED_AN_INPUT_GREEN_BIT, '0', led_code_i);
      Report_LED_IF  ("-", C_LED_AN_INPUT_RED_BIT,   '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("5.3.6", TRUE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------         
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.4");
      tfy_wr_step( report_file, now, "5.4", 
         "Set the analog input signals with valid values, i.e. C_SPEED_VALUES(1), and wait 1 sec");

      Set_Speed_Cases(1);
      WAIT FOR 1 sec;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.1",
         "Check if the output speed is the default maximum speed (> 110km/h) (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_spd_out_r = "01111111",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);       

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.2",
         "Check if the no-persistent 'Invalid Speed' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => inv_spd_s0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.3",
         "Check if the persistent 'Invalid Speed' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => inv_spd_s1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.4",
         "Check if the 'Invalid Speed' error counter is '101000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i2 = "101000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.5",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_AN_UNDERRANGE_BIT, '0', alarm_code_i);  -- Analog Speed Under-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_OVERRANGE_BIT,  '0', alarm_code_i);  -- Analog Speed Over-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_INPUT_FAULT_BIT,'1', alarm_code_i);  -- Analog Speed Error / Minor Fault (under/over range/inconsistent 6-bit value)
      Report_LED_IF  ("-", C_LED_AN_INPUT_GREEN_BIT, '0', led_code_i);
      Report_LED_IF  ("-", C_LED_AN_INPUT_RED_BIT,   '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("5.4.6", TRUE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5.5");
      Reset_UUT("5.5");

      --==============
      -- Step 6
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6: -------------------------------------#");
      tfy_wr_step( report_file, now, "6", 
         "Verify the permanent fault capability due to an '25km/h Speed Range' fault (REQ 179_202)");      

      -----------------------------------------------------------------------------------------------------------         
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6.1");
      tfy_wr_step( report_file, now, "6.1", 
         "Set the analog input signals with valid values, i.e. C_SPEED_VALUES(1)");

      Set_Speed_Cases(1);
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1.1",
         "Check if the output speed is the default maximum speed (> 110km/h) (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_spd_out_r = "01111111",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);       

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1.2",
         "Check if the no-persistent '25km/h Speed Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => spd_25km_flt_2_s0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1.3",
         "Check if the persistent '25km/h Speed Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => spd_25km_flt_2_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1.4",
         "Check if the '25km/h Speed Range' error counter is '000000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i3 = "000000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1.5",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_AN_UNDERRANGE_BIT, '0', alarm_code_i);  -- Analog Speed Under-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_OVERRANGE_BIT,  '0', alarm_code_i);  -- Analog Speed Over-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_INPUT_FAULT_BIT,'0', alarm_code_i);  -- Analog Speed Error / Minor Fault (under/over range/inconsistent 6-bit value)
      Report_LED_IF  ("-", C_LED_AN_INPUT_GREEN_BIT, '1', led_code_i);
      Report_LED_IF  ("-", C_LED_AN_INPUT_RED_BIT,   '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("6.1.6", FALSE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------                 
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6.2");
      tfy_wr_step( report_file, now, "6.2",
         "Force an '25km/h Speed Range' error, i.e. C_SPEED_VALUES(10)");

      Set_Speed_Cases(10);
      WAIT FOR 2 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2.1",
         "Check if the output speed is the default maximum speed (> 110km/h) (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_spd_out_r = "01111111",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);       

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2.2",
         "Check if the no-persistent '25km/h Speed Range' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => spd_25km_flt_2_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2.3",
         "Check if the persistent '25km/h Speed Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => spd_25km_flt_2_s1 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2.4",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_AN_UNDERRANGE_BIT, '0', alarm_code_i);  -- Analog Speed Under-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_OVERRANGE_BIT,  '0', alarm_code_i);  -- Analog Speed Over-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_INPUT_FAULT_BIT,'0', alarm_code_i);  -- Analog Speed Error / Minor Fault (under/over range/inconsistent 6-bit value)
      Report_LED_IF  ("-", C_LED_AN_INPUT_GREEN_BIT, '1', led_code_i);
      Report_LED_IF  ("-", C_LED_AN_INPUT_RED_BIT,   '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("6.2.5", FALSE, minor_flt_report_s);      

      -----------------------------------------------------------------------------------------------------------                 
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6.3");
      tfy_wr_step( report_file, now, "6.3",
         "Wait a sufficient time to the fault be considered permanent (> 40*500ms)");

      WAIT FOR 40*C_COUNTER_PERIOD;
      WAIT FOR 0.2*C_COUNTER_PERIOD;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.1",
         "Check if the output speed is the default maximum speed (> 110km/h) (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_spd_out_r = "01111111",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);       

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.2",
         "Check if the no-persistent '25km/h Speed Range' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => spd_25km_flt_2_s0 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.3",
         "Check if the persistent '25km/h Speed Range' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => spd_25km_flt_2_s1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.4",
         "Check if the '25km/h Speed Range' error counter is '101000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i3 = "101000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.5",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_AN_UNDERRANGE_BIT, '0', alarm_code_i);  -- Analog Speed Under-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_OVERRANGE_BIT,  '0', alarm_code_i);  -- Analog Speed Over-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_INPUT_FAULT_BIT,'1', alarm_code_i);  -- Analog Speed Error / Minor Fault (under/over range/inconsistent 6-bit value)
      Report_LED_IF  ("-", C_LED_AN_INPUT_GREEN_BIT, '0', led_code_i);
      Report_LED_IF  ("-", C_LED_AN_INPUT_RED_BIT,   '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("6.3.6", TRUE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------         
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6.4");
      tfy_wr_step( report_file, now, "6.4", 
         "Set the analog input signals with valid values, i.e. C_SPEED_VALUES(1), and wait 1 sec");

      Set_Speed_Cases(1);
      WAIT FOR 1 sec;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4.1",
         "Check if the output speed is the default maximum speed (> 110km/h) (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_spd_out_r = "01111111",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);       

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4.2",
         "Check if the no-persistent '25km/h Speed Range' error flag is '1' (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => spd_25km_flt_2_s0 = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4.3",
         "Check if the persistent '25km/h Speed Range' error flag is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => spd_25km_flt_2_s1 = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4.4",
         "Check if the '25km/h Speed Range' error counter is '101000' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_counter_r_i3 = "101000",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4.5",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_AN_UNDERRANGE_BIT, '0', alarm_code_i);  -- Analog Speed Under-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_OVERRANGE_BIT,  '0', alarm_code_i);  -- Analog Speed Over-Range reading
      Report_Diag_IF ("-", C_DIAG_AN_INPUT_FAULT_BIT,'1', alarm_code_i);  -- Analog Speed Error / Minor Fault (under/over range/inconsistent 6-bit value)
      Report_LED_IF  ("-", C_LED_AN_INPUT_GREEN_BIT, '0', led_code_i);
      Report_LED_IF  ("-", C_LED_AN_INPUT_RED_BIT,   '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("6.4.6", TRUE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6.5");
      Reset_UUT("6.5");

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
         tc_name        => "TC_RS040_041_042_043_202_179",
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

END ARCHITECTURE TC_RS040_041_042_043_202_179;

