-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS024
-- Module      : Input IF
-- Revision    : 2.0
-- Date        : 05 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Tests the minimum pulse width requirement compliance
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-24
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
-- sim -tc TC_RS024 -numstdoff -nocov
-- log -r /*
--
-- 24 Each digital input shall be digitally filtered to eliminate spurious glitches that
--    may occur during sampling. It is expected that all valid pulse transitions will have
--    a minimum pulse width > 46.875 us + 15.625us. Any transitions not meeting this shall be
--    masked out prior to the comparison stage.
--
-- » 15.625us pulse. 3 samples => 46.875us, one sample implicit
--
-- Borderline conditions:
--  Scenario 1: input pulses sync with the falling_edge(x_pulse15_625us_s)
--  Scenario 2: input pulses sync with the rising_edge (x_pulse15_625us_s)
--
--  Results:
--                                                            |---  1   ---|---  2   ---|
--   --> guaranteed pulse width is >= 62.5us                  |  generate  |  generate  |
--   --> eventually, can be        >  46.875us and < 62.5us   |   block    |  generate  |
--   --> never                     <= 46.875us                |   block    |   block    |
--
-- ATTENTION:
--    st_ch1_in_ctrl_s  <= (OTHERS => BYPASS);
--    st_ch2_in_ctrl_s  <= (OTHERS => BYPASS);
--
--  C_POOL_PERIOD       -> simulation\testbench\hcmt_cpld_tc_top.vhd
--  C_CLK_DERATE_BITS   -> code\hcmt_cpld\hcmt_cpld_top_p.vhd
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

ARCHITECTURE TC_RS024 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Type Definitions
   --------------------------------------------------------

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------

   CONSTANT C_INPUT_SAMPLE_WIDTH                  : TIME := 15.625 us; -- Input sample width

   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------
   SIGNAL x_debounce_out_s                        : STD_LOGIC_VECTOR(24 DOWNTO 0) := (OTHERS => '0'); -- Debouncer output spy probe
   SIGNAL x_pulse15_625us_s                       : STD_LOGIC;                                        -- pulse every 15.625 us

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
   VARIABLE pass                                : BOOLEAN := true;

   --------------------------------------------------------
   -- Other Testcase Variables
   --------------------------------------------------------
   VARIABLE v_expected_debouncer_out            : STD_LOGIC_VECTOR(24 DOWNTO 0); -- Expected value at the debouncer output

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

   PROCEDURE p_set_data_in (s_input: std_logic_vector (4 downto 0); s_value: std_logic) IS
   BEGIN
      CASE s_input is
         --------------------------------------------------------
         -- dual channel 2
         --------------------------------------------------------
         when "00000" => uut_in.cab_act_ch2_s            <=s_value; -- debounce_in_s(0)
         when "00001" => uut_in.not_isol_ch2_s           <=s_value; -- debounce_in_s(1)
         when "00010" => uut_in.bcp_75_ch2_s             <=s_value; -- debounce_in_s(2)
         when "00011" => uut_in.hcs_mode_ch2_s           <=s_value; -- debounce_in_s(3)
         when "00100" => uut_in.zero_spd_ch2_s           <=s_value; -- debounce_in_s(4)
         when "00101" => uut_in.spd_lim_override_ch2_s   <=s_value; -- debounce_in_s(5)
         when "00110" => uut_in.vigi_pb_ch2_s            <=s_value; -- debounce_in_s(6)
         when "00111" => uut_in.spd_lim_ch2_s            <=s_value; -- debounce_in_s(7)
         when "01000" => uut_in.driverless_ch2_s         <=s_value; -- debounce_in_s(8)

         --------------------------------------------------------
         -- single channel
         --------------------------------------------------------
         when "01001" => uut_in.ss_bypass_pb_s           <=s_value; -- debounce_in_s(9)
         when "01010" => uut_in.w_wiper_pb_s             <=s_value; -- debounce_in_s(10)
         when "01011" => uut_in.hl_low_s                 <=s_value; -- debounce_in_s(11)
         when "01100" => uut_in.horn_high_s              <=s_value; -- debounce_in_s(12)
         when "01101" => uut_in.horn_low_s               <=s_value; -- debounce_in_s(13)

         --------------------------------------------------------
         -- dual channel 1
         --------------------------------------------------------
         when "01110" => uut_in.cab_act_ch1_s            <=s_value; -- debounce_in_s(14)
         when "01111" => uut_in.not_isol_ch1_s           <=s_value; -- debounce_in_s(15)
         when "10000" => uut_in.bcp_75_ch1_s             <=s_value; -- debounce_in_s(16)
         when "10001" => uut_in.hcs_mode_ch1_s           <=s_value; -- debounce_in_s(17)
         when "10010" => uut_in.zero_spd_ch1_s           <=s_value; -- debounce_in_s(18)
         when "10011" => uut_in.spd_lim_override_ch1_s   <=s_value; -- debounce_in_s(19)
         when "10100" => uut_in.vigi_pb_ch1_s            <=s_value; -- debounce_in_s(20)
         when "10101" => uut_in.spd_lim_ch1_s            <=s_value; -- debounce_in_s(21)
         when "10110" => uut_in.driverless_ch1_s         <=s_value; -- debounce_in_s(22)

         --------------------------------------------------------
         -- Extra inputs
         --------------------------------------------------------
         when "10111" => uut_in.force_fault_ch2_s        <=s_value; -- debounce_in_s(23)
         when "11000" => uut_in.force_fault_ch1_s        <=s_value; -- debounce_in_s(24)

         when others =>
            --------------------------------------------------------
            -- dual channel 2
            --------------------------------------------------------
            uut_in.cab_act_ch2_s          <='0';
            uut_in.not_isol_ch2_s         <='0';
            uut_in.bcp_75_ch2_s           <='0';
            uut_in.hcs_mode_ch2_s         <='0';
            uut_in.zero_spd_ch2_s         <='0';
            uut_in.spd_lim_override_ch2_s <='0';
            uut_in.vigi_pb_ch2_s          <='0';
            uut_in.spd_lim_ch2_s          <='0';
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
            -- dual channel 1
            --------------------------------------------------------
            uut_in.cab_act_ch1_s          <='0';
            uut_in.not_isol_ch1_s         <='0';
            uut_in.bcp_75_ch1_s           <='0';
            uut_in.hcs_mode_ch1_s         <='0';
            uut_in.zero_spd_ch1_s         <='0';
            uut_in.spd_lim_override_ch1_s <='0';
            uut_in.vigi_pb_ch1_s          <='0';
            uut_in.spd_lim_ch1_s          <='0';
            uut_in.driverless_ch1_s       <='0';

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
      report_fname   => "TC_RS024.rep",
      report_file    => report_file,
      project_name   => "VCU",
      tc_name        => "TC_RS024",
      test_module    => "Input IF",
      tc_revision    => "2.0",
      tc_date        => "05 Dec 2019",
      tester_name    => "CABelchior",
      tc_description => "Tests the minimum pulse width requirement compliance",
      tb_name        => "hcmt_cpld_top_tb",
      dut_name       => "hcmt_cpld_top_tb",
      s_usr_sigin_s  => s_usr_sigin_s,
      s_usr_sigout_s => s_usr_sigout_s
   );

   --------------------------------------------------------
   -- Link Spy Probes
   --------------------------------------------------------
   init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/debounce_out_s",  "x_debounce_out_s");
   init_signal_spy("/hcmt_cpld_top_tb/UUT/pulse15_625us_s",             "x_pulse15_625us_s");

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
         "Check if a pulse width equal or greater than 62.5us effectively generates a pulse at the  debouncer output");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1", 
         "For all digital inputs, do:");

      v_expected_debouncer_out := "0000000000000000000000001";

      FOR i IN 0 TO 24  LOOP
         ---------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.1." & str(i+1),
            "Set a pulse on digital input("& str(i) &") with pulse width of 62.5us");

         p_set_data_in (STD_LOGIC_VECTOR(to_unsigned(i, 5)), '1');   -- Sets input at '1'
         WAIT FOR 62.5 us;

         p_set_data_in (STD_LOGIC_VECTOR(to_unsigned(i, 5)), '0');   -- Sets input at '0'
         WAIT FOR C_INPUT_SAMPLE_WIDTH;

         ---------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "2.1." & str(i+1)& ".1",
            "Check if the pulse for digital input("& str(i) &") was generated (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => x_debounce_out_s = v_expected_debouncer_out,
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         v_expected_debouncer_out := v_expected_debouncer_out(23 downto 0) & '0'; -- Shifts the expected debouncer out for next input
      END LOOP;


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "Check if a pulse width lesser than 62.5us and greater than 46.875us, when synch with the  rising edge of x_pulse15_625us, effectively generates a pulse at the debouncer output");

         -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1", 
         "For all digital inputs, do:");

      v_expected_debouncer_out := "0000000000000000000000001";

      FOR i IN 0 TO 24  LOOP
         ---------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3.1." & str(i+1),
            "Set a pulse on digital input("& str(i) &") with pulse width of 62.4us, in sync with rising edge of   'x_pulse15_625us_s'");

         WAIT UNTIL rising_edge(x_pulse15_625us_s);
         p_set_data_in (STD_LOGIC_VECTOR(to_unsigned(i, 5)), '1');   -- Sets input at '1'
         WAIT FOR 62.4 us;

         p_set_data_in (STD_LOGIC_VECTOR(to_unsigned(i, 5)), '0');   -- Sets input at '0'
         WAIT FOR C_INPUT_SAMPLE_WIDTH;

         ---------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "3.1." & str(i+1)& ".1",
            "Check if the pulse for digital input("& str(i) &") was generated (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => x_debounce_out_s = v_expected_debouncer_out,
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         v_expected_debouncer_out := v_expected_debouncer_out(23 downto 0) & '0'; -- Shifts the expected debouncer out for next input
      END LOOP;


      --==============
      -- Step 4
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------------#");
      tfy_wr_step( report_file, now, "4",
         "Check if a pulse width lesser than 62.5us and greater than 46.875us, when synch with the  falling edge of x_pulse15_625us, DO NOT generates a pulse at the debouncer output");

         -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1", 
         "For all digital inputs, do:");

      v_expected_debouncer_out := "0000000000000000000000000"; -- This is different from step 3

      FOR i IN 0 TO 24  LOOP
         ---------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "4.1." & str(i+1),
            "Set a pulse on digital input("& str(i) &") with pulse width of 62.4us, in sync with falling edge of 'x_pulse15_625us_s'");

         WAIT UNTIL falling_edge(x_pulse15_625us_s);
         p_set_data_in (STD_LOGIC_VECTOR(to_unsigned(i, 5)), '1');   -- Sets input at '1'
         WAIT FOR 62.4 us;

         p_set_data_in (STD_LOGIC_VECTOR(to_unsigned(i, 5)), '0');   -- Sets input at '0'
         WAIT FOR C_INPUT_SAMPLE_WIDTH;

         ---------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "4.1." & str(i+1)& ".1",
            "Check if the pulse for digital input("& str(i) &") was NOT generated (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => x_debounce_out_s = v_expected_debouncer_out,
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         v_expected_debouncer_out := v_expected_debouncer_out(23 downto 0) & '0'; -- Shifts the expected debouncer out for next input
      END LOOP;


      --==============
      -- Step 5
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5: -------------------------------------------#");
      tfy_wr_step( report_file, now, "5",
         "Check if a pulse width equal or lesser than 46.875us DO NOT generates a pulse at the debouncer output");

         -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1", 
         "For all digital inputs, do:");

      v_expected_debouncer_out := "0000000000000000000000000"; -- This is different from step 3

      FOR i IN 0 TO 24  LOOP
         ---------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "5.1." & str(i+1),
            "Set a pulse on digital input("& str(i) &") with pulse width of 46.875us");

         p_set_data_in (STD_LOGIC_VECTOR(to_unsigned(i, 5)), '1');   -- Sets input at '1'
         WAIT FOR 46.875 us;

         p_set_data_in (STD_LOGIC_VECTOR(to_unsigned(i, 5)), '0');   -- Sets input at '0'
         WAIT FOR C_INPUT_SAMPLE_WIDTH;

         ---------------------------------------------------------------------------------------------------------
         tfy_wr_step( report_file, now, "5.1." & str(i+1)& ".1",
            "Check if the pulse for digital input("& str(i) &") was NOT generated (Expected: TRUE)");

         tfy_check( relative_time => now,         received        => x_debounce_out_s = v_expected_debouncer_out,
                    expected      => TRUE,        equality        => TRUE,
                    report_file   => report_file, pass            => pass);

         v_expected_debouncer_out := v_expected_debouncer_out(23 downto 0) & '0'; -- Shifts the expected debouncer out for next input
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
       tc_name        => "TC_RS024",
       tb_name        => "hcmt_cpld_top_tb",
       dut_name       => "hcmt_cpld_tc_top",
       tester_name    => "CABelchior",
       tc_date        => "05 Dec 2019",
       s_usr_sigin_s  => s_usr_sigin_s,
       s_usr_sigout_s => s_usr_sigout_s    
    );
  END PROCESS p_steps;

   -----------------------------------------------------------------------------------------------------------
   s_usr_sigin_s.test_select  <= test_select;
   s_usr_sigin_s.clk          <= Clk;
   test_done                  <= s_usr_sigout_s.test_done;
   pwm_func_model_data        <= pwm_func_model_data_s;
   st_ch1_in_ctrl_o           <= st_ch1_in_ctrl_s; 
   st_ch2_in_ctrl_o           <= st_ch2_in_ctrl_s; 
   minor_flt_report_s         <= uut_out.tms_minor_fault_s AND uut_out.disp_minor_fault_s;
  
END ARCHITECTURE TC_RS024;
