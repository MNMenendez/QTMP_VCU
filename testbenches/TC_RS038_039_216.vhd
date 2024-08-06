-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS038_039_216
-- Module      : Input IF
-- Revision    : 2.0
-- Date        : 05 Feb 2020
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Verify the PWM Power and Brake Demand range behavior
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-38
--    FPGA-REQ-39
--    FPGA-REQ-216
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 06 Apr 2018
--    - CABelchior (1.0): Initial Release
-- Revision 1.1 - 29 Aug 2018
--    - CABelchior (1.1): CCN2
-- Revision 1.2 - 12 Jun 2019
--    - CABelchior (1.2): CCN3
-- Revision 2.0 - 05 Feb 2020
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
--
-- sim -tc TC_RS038_039_216 -numstdoff -nocov -vopt
-- log -r /*
--
-- 38    The output range between 10% through to 43.33% shall be considered to be the braking demand phase 
--       of a TLA operation. A TLA event will occur when an accumulated movement of +/-4.16% occurs within 
--       a 3 second period. If no TLA event occurs with the 3 second timer the 3 second timer shall continue 
--       to free run. If a TLA event occurs the 3 second timer shall be restarted.
--
-- 39    The output range between 56.67% through to 90% shall be considered to be the power demand phase of a 
--       TLA operation. A TLA event will occur when an accumulated movement of +/-4.16% occurs within a 3 
--       second period. If no TLA event occurs with the 3 second timer the 3 second timer shall continue to 
--       free run. If a TLA event occurs the 3 second timer shall be restarted.
--
-- 216   PWM duty cycle measurements outside of the valid power and braking demand ranges shall be truncated to 
--       the limits of these ranges for the purposes of TLA event generation. E.g. a duty cycle measurement of 
--       5-10% shall be considered as 10% for the braking demand range.
--
--
-- Step 3: Verify the trigger based on accumulated movement of +/-4.16% in the Brake Demand Phase
-- Step 3.1:
--
-- Step 3.2: Justification of the first choosen duty cycle
--
--   38.00             /--------------------- 4.16%----------------------/
--     ^   38.87     39.17     39.47                         43.03     43.33     43.63
-- ----|-----[---------|---------]-----------------------------[---------|---------]--
--           \---.3%---\                                                 \---.3%---\     -> tolerance
-- 
-- Step 4:Verify the trigger based on accumulated movement of +/-4.16% in the Power Demand Phase
-- Step 4.1:
--
-- Step 4.2: Justification of the first choosen duty cycle
--
--                     /--------------------- 4.16%----------------------/            62.00
--         56.37     56.67     56.97                         60.53     60.83     61.13  ^
-- ----------[---------|---------]-----------------------------[---------|---------]----|-----
--           \---.3%---\                                                 \---.3%---\     -> tolerance
--
--
--
-- Note:
--       A TLA event will occur when an accumulated movement of +/-4.16% (INSIDE THE SPECIFIED RANGE) occurs within a 3 second period.
-----------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;
USE WORK.txt_util_p.ALL;

ARCHITECTURE TC_RS038_039_216 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Type Definitions
   --------------------------------------------------------

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------
   CONSTANT C_PWM_DEFAULT_PERIOD  : TIME := 2.00 ms;

   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------
   -- VCU Timing System FSM
   SIGNAL x_tla_i                                 : STD_LOGIC_VECTOR(7 DOWNTO 0); -- Aggregated Task Linked Activity

   -- -- PWM Demand Phase Detect
   SIGNAL x_pwm0_fault_o                          : STD_LOGIC;                    -- PWM0 fault
   SIGNAL x_pwm1_fault_o                          : STD_LOGIC;                    -- PWM1 fault
   SIGNAL x_pwr_brk_dmnd_o                        : STD_LOGIC;                    -- Movement of MC changing ±12.5% the braking demand or ±12.5% the power demand (req 38 and req 39)
   SIGNAL x_mc_no_pwr_o                           : STD_LOGIC;                    -- MC = No Power

   SIGNAL x_ctr_3s_s                              : UNSIGNED(12 DOWNTO 0);
   SIGNAL x_ctr_3s_r                              : UNSIGNED(12 DOWNTO 0);
   SIGNAL x_ctr_3s_rst_s                          : STD_LOGIC;

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

   SIGNAL prev_timer                              : UNSIGNED(12 DOWNTO 0);
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

      PROCEDURE Set_PWM_DutyCycle (duty : REAL) IS
      BEGIN
         pwm_func_model_data_s  <= ( time_high_1 => 2.00 ms * ( duty / 100.00 ),
                                     time_high_2 => 2.00 ms * ( duty / 100.00 ),
                                     offset      => 0 us,
                                     on_off      => '1', 
                                     period_1    => 2.00 ms,
                                     period_2    => 2.00 ms);
      END PROCEDURE Set_PWM_DutyCycle;

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
         report_fname   => "TC_RS038_039_216.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS038_039_216",
         test_module    => "TS",
         tc_revision    => "2.0",
         tc_date        => "05 Feb 2020",
         tester_name    => "CABelchior",
         tc_description => "Tests Case Template",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_top_tb",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s
      );

      --------------------------------------------------------
      -- Link Spy Probes
      --------------------------------------------------------
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/tla_i",   "x_tla_i", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm0_fault_o",   "x_pwm0_fault_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwm1_fault_o",   "x_pwm1_fault_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/pwr_brk_dmnd_o", "x_pwr_brk_dmnd_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/mc_no_pwr_o",    "x_mc_no_pwr_o", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/ctr_3s_s",       "x_ctr_3s_s", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/ctr_3s_r",       "x_ctr_3s_r", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/demand_phase_det_i0/ctr_3s_rst_s",   "x_ctr_3s_rst_s", 0);

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
         "Verify the 3 second Timer behavior");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "Verify if, when a TLA event occurs the 3 second Timer is restarted");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.1",
         "Store the current Timer value");

      prev_timer <= x_ctr_3s_s;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.2",
         "Wait 50ms and check that the Timer was NOT frozen");

      WAIT FOR 50 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_ctr_3s_s) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.3", 
         "Force a 'MC Movement as Break Demand' TLA event, and stamp its time (ta = now)");

      --pwm_func_model_data_s  <= C_PWM_FMI_BRK_DEMAND;
      Set_PWM_DutyCycle(25.0);
      WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;
      ta := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.4", 
         "Check if the 3 second Timer is reset (Expected: TRUE)");

      WAIT FOR 1 ns; -- race condition with 'x_pwr_brk_dmnd_o'
      tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),  -- 3 sec counter (pulse500us_i)
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "Verify the actual size of the 3 sec Timer");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.1", 
         "Wait for another pulse of 'x_ctr_3s_rst_s', and stamp its time (tb = now)");

      WAIT UNTIL x_ctr_3s_rst_s = '1' FOR 3.1 sec;
      tb := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.2",
         "Check if 'dt = tb - ta' is equal to the specified 3 sec windows period (Expected: TRUE)");

      dt := tb - ta;

      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => (3 sec * 0.98),
                expected_max   => (3 sec * 1.02),
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "Verify the trigger based on accumulated (incremental) movement of +/-4.16% in the Brake Demand Phase");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1",
         "Check the TLA trigger behavior starting close to the minimum of the Brake Demand Phase range");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.1",
         "Change PWM Module with a Duty-Cycle from 50.0% to 10.0% and wait for the TLA event generation");

      Set_PWM_DutyCycle(10.0);
      WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.1.1",
         "Check if the 3 second Timer is reset (Expected: TRUE)");

      WAIT FOR 1 ns; -- race condition with 'x_pwr_brk_dmnd_o'
      tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.2",
         "Change the Duty-Cycle incrementally until 15.0% (> 4.16%) and, only after the last change, wait for the TLA event generation");

      Set_PWM_DutyCycle(11.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(12.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(13.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(14.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(15.0); 
      WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.2.1",
         "Check if the 3 second Timer is reset (Expected: TRUE)");

      WAIT FOR 1 ns;
      tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.3",
         "Change the Duty-Cycle incrementally until 20.0% (> 4.16%), but with a wait greater than 3sec before the last change");

      Set_PWM_DutyCycle(16.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(17.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(18.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(19.0); WAIT UNTIL x_ctr_3s_rst_s = '1' FOR 3.1 sec; -- «««««««««

      Set_PWM_DutyCycle(20.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.3.1",
         "Check if the 3 second Timer is reset (Expected: FALSE)");

      WAIT FOR 1 ns;
      tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- ----------------------------------------------------------------------
      -- Set_PWM_DutyCycle(21.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      -- Set_PWM_DutyCycle(22.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      -- Set_PWM_DutyCycle(23.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      -- Set_PWM_DutyCycle(24.0); 
      -- WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;

      -- WAIT FOR 1 ns;
      -- tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.1.4"); -- DC goes to 50.00%

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2",                    -- ] (5.00%) 10.00% --- 43.33% [  Delta = +/-4.16%
         "Check the TLA trigger behavior starting close to the maximum of the Brake Demand Phase range");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.1",
         "Change PWM Module with a Duty-Cycle from 50.0% to 38.0% and wait for the TLA event generation");
      Set_PWM_DutyCycle(38.0); -- +/-4.16% inside the specified range       0,3% tolerance
      WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.1.1",
         "Check if the 3 second Timer is reset (Expected: TRUE)");

      WAIT FOR 1 ns; -- race condition with 'x_pwr_brk_dmnd_o'
      tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.2",
         "Change the Duty-Cycle decrementally until 33.0% (> 4.16%) and, only after the last change, wait for the TLA event generation");

      Set_PWM_DutyCycle(37.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(36.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(35.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(34.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(33.0); 
      WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.2.1",
         "Check if the 3 second Timer is reset (Expected: TRUE)");

      WAIT FOR 1 ns;
      tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.3",
         "Change the Duty-Cycle decrementally until 28.0% (> 4.16%), but with a wait greater than 3sec before the last change");

      Set_PWM_DutyCycle(32.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(31.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(30.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(29.0); WAIT UNTIL x_ctr_3s_rst_s = '1' FOR 3.1 sec; -- «««««««««

      Set_PWM_DutyCycle(28.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.3.1",
         "Check if the 3 second Timer is reset (Expected: FALSE)");

      WAIT FOR 1 ns;
      tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- ----------------------------------------------------------------------
      -- Set_PWM_DutyCycle(27.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      -- Set_PWM_DutyCycle(26.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      -- Set_PWM_DutyCycle(25.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      -- Set_PWM_DutyCycle(24.0); 
      -- WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;

      -- WAIT FOR 1 ns;
      -- tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.2.4");


      --==============
      -- Step 4
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------------#");
      tfy_wr_step( report_file, now, "4",
         "Verify the trigger based on accumulated movement of +/-4.16% in the Power Demand Phase");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1",
         "Check the TLA trigger behavior starting close to the maximum of the Power Demand Phase range");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.1",
         "Change PWM Module with a Duty-Cycle from 50.0% to 90.0% and wait for the TLA event generation");

      Set_PWM_DutyCycle(90.0);
      WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.1.1",
         "Check if the 3 second Timer is reset (Expected: TRUE)");

      WAIT FOR 1 ns; -- race condition with 'x_pwr_brk_dmnd_o'
      tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.2",
         "Change the Duty-Cycle decrementally until 85.0% (> 4.16%) and, only after the last change, wait for the TLA event generation");

      Set_PWM_DutyCycle(89.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(88.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(87.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(86.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(85.0); 
      WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.2.1",
         "Check if the 3 second Timer is reset (Expected: TRUE)");

      WAIT FOR 1 ns;
      tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.3",
         "Change the Duty-Cycle decrementally until 80.0% (> 4.16%), but with a wait greater than 3sec before the last change");

      Set_PWM_DutyCycle(84.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(83.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(82.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(81.0); WAIT UNTIL x_ctr_3s_rst_s = '1' FOR 3.1 sec; -- «««««««««

      Set_PWM_DutyCycle(80.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.3.1",
         "Check if the 3 second Timer is reset (Expected: FALSE)");

      WAIT FOR 1 ns;
      tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- ----------------------------------------------------------------------
      -- Set_PWM_DutyCycle(79.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      -- Set_PWM_DutyCycle(78.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      -- Set_PWM_DutyCycle(77.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      -- Set_PWM_DutyCycle(76.0); 
      -- WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;

      -- WAIT FOR 1 ns;
      -- tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.1.4"); -- DC goes to 50.00%

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2",                    -- ] 56.67% --- 90.00% (95.00%) [  Delta = +/-4.16%
         "Check the TLA trigger behavior starting close to the minimum of the Power Demand Phase range");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.1",
         "Change PWM Module with a Duty-Cycle from 50.0% to 62.0% and wait for the TLA event generation");

      Set_PWM_DutyCycle(62.0); -- +/-4.16% inside the specified range
      WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.1.1",
         "Check if the 3 second Timer is reset (Expected: TRUE)");

      WAIT FOR 1 ns;
      tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.2",
         "Change the Duty-Cycle incrementally until 67.0% (> 4.16%) and, only after the last change, wait for the TLA event generation");

      Set_PWM_DutyCycle(63.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(64.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(65.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(66.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(67.0); 
      WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.2.1",
         "Check if the 3 second Timer is reset (Expected: TRUE)");

      WAIT FOR 1 ns;
      tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.3",
         "Change the Duty-Cycle incrementally until 72.0% (> 4.16%), but with a wait greater than 3sec before the last change");

      Set_PWM_DutyCycle(68.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(69.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(70.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(71.0); WAIT UNTIL x_ctr_3s_rst_s = '1' FOR 3.1 sec; -- «««««««««
      Set_PWM_DutyCycle(72.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.3.1",
         "Check if the 3 second Timer is reset (Expected: FALSE)");

      WAIT FOR 1 ns;
      tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -- ----------------------------------------------------------------------
      -- Set_PWM_DutyCycle(73.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      -- Set_PWM_DutyCycle(74.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      -- Set_PWM_DutyCycle(75.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      -- Set_PWM_DutyCycle(76.0); 
      -- WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;

      -- WAIT FOR 1 ns;
      -- tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -- tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),
      --            expected      => TRUE,        equality        => TRUE,
      --            report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.2.4");


      --==============
      -- Step 5
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5: -------------------------------------------#");
      tfy_wr_step( report_file, now, "5",
         "Verify the truncation of PWM duty cycle measurements outside of the valid brake demand range");
         -- E.g. a duty cycle measurement of 5-10% shall be considered as 10% for the braking demand range.

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1",
         "Change PWM Module with a Duty-Cycle from 50.0% to 6.0% and wait for the TLA event generation");

      Set_PWM_DutyCycle(6.0);
      WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.1",
         "Check if the 3 second Timer is reset (Expected: TRUE)");

      WAIT FOR 1 ns; -- race condition with 'x_pwr_brk_dmnd_o'
      tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2",
         "Change the Duty-Cycle incrementally until 11.0% (> 4.16%) and, only after the last change, wait for the TLA event generation");

      Set_PWM_DutyCycle(7.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(8.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(9.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(10.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(11.0); 
      WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.1",
         "Check if the 3 second Timer is reset (Expected: FALSE)");

      WAIT FOR 1 ns;
      tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.3");


      --==============
      -- Step 6
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6: -------------------------------------------#");
      tfy_wr_step( report_file, now, "6",
         "Verify the truncation of PWM duty cycle measurements outside of the valid power demand range");
         -- E.g. a duty cycle measurement of 90-95% shall be considered as 90% for the braking demand range.

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1",
         "Change PWM Module with a Duty-Cycle from 50.0% to 94.0% and wait for the TLA event generation");

      Set_PWM_DutyCycle(94.0);
      WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1.1",
         "Check if the 3 second Timer is reset (Expected: TRUE)");

      WAIT FOR 1 ns; -- race condition with 'x_pwr_brk_dmnd_o'
      tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2",
         "Change the Duty-Cycle decrementally until 89.0% (> 4.16%) and, only after the last change, wait for the TLA event generation");

      Set_PWM_DutyCycle(93.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(92.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(91.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(90.0); WAIT FOR C_PWM_DEFAULT_PERIOD*15;
      Set_PWM_DutyCycle(89.0); 
      WAIT UNTIL x_pwr_brk_dmnd_o = '1' FOR C_PWM_DEFAULT_PERIOD*5;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2.1",
         "Check if the 3 second Timer is reset (Expected: FALSE)");

      WAIT FOR 1 ns;
      tfy_check( relative_time => now,         received        => x_ctr_3s_rst_s = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_ctr_3s_s = (6000 - 1),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("6.3");


      --------------------------------------------------------
      -- END
      --------------------------------------------------------
      WAIT FOR 20 ms;
      --------------------------------------------------------
      -- Testcase End Sequence
      --------------------------------------------------------

      tfy_tc_end(
         tc_pass        => pass,
         report_file    => report_file,
         tc_name        => "TC_RS038_039_216",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "05 Feb 2020",
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

END ARCHITECTURE TC_RS038_039_216;

