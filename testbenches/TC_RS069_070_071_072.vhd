-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS069_070_071_072
-- Module      : External Status IF
-- Revision    : 2.0
-- Date        : 10 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Tests diagnostics interface requirements compliance
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-69
--    FPGA-REQ-70
--    FPGA-REQ-71
--    FPGA-REQ-72
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 15 Fev 2018
--    - CABelchior (1.0): Initial Release
-- Revision 1.1 - 19 Jul 2019
--    - DSOliveira: CCN03 Updates
-- Revision 2.0 - 10 Dec 2019
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- sim -tc TC_RS069_070_071_072 -nocov -numstdoff
--
-- 69    The CPLD shall support a serial interface to a microcontroller consisting of three 
--       signals, namely:
--
-- 70    sclk  (48.83 KHz Clock +- 0.1%),
--
-- 70,01 sdata (serial data representing fault conditions), and
--
-- 70,02 sync (active high 20.5us +- 0.1% strobe representing the start of fault data 
--       transmission from sdata signal).
--
-- 70,03 The VCU shall provide capacity to support up to 128 fault conditions and report 
--       these via the serial interface.
--
-- 71    The serial interface will continually poll and output the fault status every 128 
--       sclk cycles (approximately 2.6mS).
--
-- 72    Signal sync is a synchronising pulse and shall assert and be coincident during the 
--       transmission of fault 0 condition. It is up to the microcontroller to ensure the rest 
--       of the fault conditions 1 through to 127 are processed in sequential order with each 
--       subsequent falling edge of sclk. Extra bits from the sequence that are not allocated 
--       to fault conditions will be set to ‘0’.
--
-- NOTE: The tolerance for the clock must be 0.2%
--

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;
USE WORK.txt_util_p.ALL;

ARCHITECTURE TC_RS069_070_071_072 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------
   CONSTANT C_CLOCK_PERIOD                        : TIME := 20479213 ps;   -- freq = 48,83 kHz
   CONSTANT C_ACTIVE_PERIOD                       : TIME := 20.5 us;

   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------
   SIGNAL x_opmode_curst_r                        : opmode_st_t;
   SIGNAL x_vcut_curst_r                          : vcut_st_t;

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
      VARIABLE t0                                : TIME := 0 us;
      VARIABLE t1                                : TIME := 0 us;
      VARIABLE t2                                : TIME := 0 us;
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
         report_fname   => "TC_RS069_070_071_072.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS069_070_071_072",
         test_module    => "External Status IF",
         tc_revision    => "2.0",
         tc_date        => "10 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Tests diagnostics interface requirements compliance",
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
         "Check the existence of the signals of the UUT's Diagnostic Interface");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1", 
         "Wait until the rising edge of 'sync' (diag_strobe_o) with a timeout of 5ms");

      t0 := now;
      WAIT UNTIL rising_edge(uut_out.diag_strobe_s) FOR 5 ms;
      t1 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.1",
         "Check if timeout was not reached, and the signal exist (Expected: TRUE)");

      dt := t1 - t0;

      tfy_check( relative_time => now,         received        => (dt < 5 ms),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2", 
         "Wait until the rising edge of 'sclk' (diag_clk_o) with a timeout of 5ms");

      t0 := now;
      WAIT UNTIL rising_edge(uut_out.diag_clk_s) FOR 5 ms;
      t1 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.1",
         "Check if timeout was not reached, and the signal exist (Expected: TRUE)");

      dt := t1 - t0;

      tfy_check( relative_time => now,         received        => (dt < 5 ms),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3", 
         "Wait until the rising edge of 'sdata' (diag_data_o) with a timeout of 5ms");

      t0 := now;
      WAIT UNTIL rising_edge(uut_out.diag_data_s) FOR 5 ms;
      t1 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.1",
         "Check if timeout was not reached, and the signal exist (Expected: TRUE)");

      dt := t1 - t0;

      tfy_check( relative_time => now,         received        => (dt < 5 ms),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------#");
      tfy_wr_step( report_file, now, "3", 
         "Check the time constraints of the signals of the UUT's Diagnostic Interface");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1", 
         "For signal 'sync', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.1", 
         "Wait until the rising edge of 'sync' and stamp its time (t0 = now)");

      WAIT UNTIL rising_edge(uut_out.diag_strobe_s);
      t0 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.2", 
         "Wait until the falling edge of 'sync' and stamp its time (t1 = now)");

      WAIT UNTIL falling_edge(uut_out.diag_strobe_s);
      t1 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.3", 
         "Check if time between t0 and t1 is equal to C_ACTIVE_PERIOD (+- 0,1%)");

      dt := t1 - t0;

      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => C_ACTIVE_PERIOD*0.999,
                expected_max   => C_ACTIVE_PERIOD*1.001,
                report_file    => report_file,
                pass           => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.4", 
         "Wait until the next rising edge of 'sync' and stamp its time (t2 = now)");

      WAIT UNTIL rising_edge(uut_out.diag_strobe_s);
      t2 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.5", 
         "Check if time between t0 and t2 is equal to C_POOL_PERIOD (+- 1,0%)");

      dt := t2 - t0;

      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => C_POOL_PERIOD*0.99,
                expected_max   => C_POOL_PERIOD*1.01,
                report_file    => report_file,
                pass           => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2", 
         "For signal 'sclk', do:");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.1", 
         "Wait until the rising edge of 'sclk' and stamp its time  (t0 = now)");

      WAIT UNTIL rising_edge(uut_out.diag_clk_s);
      t0 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.2", 
         "Wait until the next rising edge of 'sclk' and stamp its time (t1 = now)");

      WAIT UNTIL rising_edge(uut_out.diag_clk_s);
      t1 := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.3", 
         "Check if time between t0 and t1 is equal to C_CLOCK_PERIOD (+-0,2%)");

        dt := t1 - t0;
        tfy_check(relative_time  => now, 
                  received       => dt,
                  expected_min   => C_CLOCK_PERIOD*0.998,
                  expected_max   => C_CLOCK_PERIOD*1.002,
                  report_file    => report_file,
                  pass           => pass);


      --==============
      -- Step 4
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------#");
      tfy_wr_step( report_file, now, "4", 
         "Check the size of the last data packet received");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1", 
         "Wait until rising edge of 'sync'");

      WAIT UNTIL rising_edge(uut_out.diag_strobe_s)  ;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2", 
         "Check the size of the last data packet received (Expected: 128 bits)");

      tfy_check( relative_time => now,         received        => alarm_qtd_i,
                 expected      => "10000000",  equality        => TRUE,
                 report_file   => report_file, pass            => pass);
      WAIT FOR 1 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3",
         "Check if bit C_DIAG_VCU_NORMAL_BIT is set to '1'");

      Report_Diag_IF ("-", C_DIAG_VCU_NORMAL_BIT,'1', alarm_code_i);

      --==============
      -- Step 5 \\TODO
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5: -------------------------------------#");
      tfy_wr_step( report_file, now, "5", 
         "Check if extra bits that are not allocated to fault conditions are set to '0'");

      FOR i IN 77 TO 127 LOOP
         Report_Diag_IF ("5." & str(i-76), i,'0', alarm_code_i);
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
         tc_name        => "TC_RS069_070_071_072",
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

END ARCHITECTURE TC_RS069_070_071_072;

