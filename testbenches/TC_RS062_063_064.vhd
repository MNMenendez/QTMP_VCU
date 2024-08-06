-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS062_063_064
-- Module      : VCU Timing System
-- Revision    : 1.0
-- Date        : 02 Jan 2020
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Check Gateway Warning requirements at OpMode NORMAL and DEPRESSED
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-062
--    FPGA-REQ-063
--    FPGA-REQ-064
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 02 Jan 2020
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- Notes:
--
-- sim -tc TC_RS062_063_064 -numstdoff -nocov
-- log -r /*
--
-- 62    In Normal or Depressed operating modes, entering the following states:
--       - Permanent Light Warning Reset Allowed (Norm)  » VCUT_NORMAL
--       - Permanent Light Warning Reset Allowed (Dep)   » VCUT_DEPRESSED
-- 
--       shall enable an independent timing process to drive the Gateway Warning circuitry. At all other states,
--       enabling of this timer shall be de-asserted and the timing process shall be held in reset.
--
-- 63    The FPGA shall implement a timer for the Gateway Warning Circuitry with duration of 30 seconds, defined as T6 period.
--
-- 64    The timer will be used to count a period of T6 and when reached, the Radio Warning output signal shall be asserted.
--
--
-- Step 2: Check that while in OpMode NORMAL, the UUT transit from VCUT_NO_WARNING to VCUT_NORMAL
--    2.6: Wait for the VCU change state to VCUT_NORMAL, and stamp its time (ta = now)
--    2.7: Wait until the Gateway Alarm (x_rly_out1_3V_o) IS applied and stamp its time (tb = now)
-- 
-- Step 3: After an UUT Reset, force the transit from OpMode NORMAL to DEPRESSED
--
-- Step 4: Check that while in OpMode DEPRESSED, the UUT transit from VCUT_NO_WARNING to VCUT_DEPRESSED
--    4.4: Wait for the VCU change state to VCUT_DEPRESSED, and stamp its time (ta = now)
--    4.5: Wait until the Gateway Alarm (x_rly_out1_3V_o) IS applied and stamp its time (tb = now)
--
-----------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;

ARCHITECTURE TC_RS062_063_064 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------
   CONSTANT C_TIMER_DEFAULT       : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(89999, 17);   -- 45s timer
   
   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------
   SIGNAL x_vcut_curst_r                          : vcut_st_t;

   -- VCU Timing System HLB » Inputs
   SIGNAL x_pulse500us_i                          : STD_LOGIC;      -- Internal 500us synch pulse
   SIGNAL x_hcs_mode_i                            : STD_LOGIC;      -- Communication-based train control (sets VCU in depressed mode)

   --  VCU Timing System HLB » Outputs
   SIGNAL x_rly_out1_3V_o                         : STD_LOGIC;     -- Gateway Warning

   SIGNAL x_opmode_mft_o                          : STD_LOGIC;     -- Notify Major Fault opmode
   SIGNAL x_opmode_tst_o                          : STD_LOGIC;     -- Notify Test opmode
   SIGNAL x_opmode_dep_o                          : STD_LOGIC;     -- Notify Depression opmode
   SIGNAL x_opmode_sup_o                          : STD_LOGIC;     -- Notify Suppression opmode
   SIGNAL x_opmode_nrm_o                          : STD_LOGIC;     -- Notify Normal opmode

   -- VCU Timing System FSM
   SIGNAL x_init_tmr_s                            : STD_LOGIC;             -- Initialize Centralized VCU Timer (indicates the reset)
   SIGNAL x_radio_ctr_r                           : UNSIGNED(16 DOWNTO 0); -- Gateway Warning Timer

   --------------------------------------------------------
   -- User Signals
   --------------------------------------------------------
   SIGNAL s_usr_sigout_s                          : tfy_user_out;
   SIGNAL s_usr_sigin_s                           : tfy_user_in;
   SIGNAL pwm_func_model_data_s                   : pwm_func_model_inputs := C_PWM_FUNC_MODEL_INPUTS_INIT;   
   SIGNAL st_ch1_in_ctrl_s                        : ST_BEHAVIOR_CH1;
   SIGNAL st_ch2_in_ctrl_s                        : ST_BEHAVIOR_CH2;

   SIGNAL minor_flt_report_s                      : STD_LOGIC := '0';

   SIGNAL prev_timer                              : UNSIGNED(16 DOWNTO 0);


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
            "Set analog speed to [90 - 110 km/h]");
         Set_Speed_Cases(6);               -- Analog Speed -> 90 - 110 km/h

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
         report_fname   => "TC_RS062_063_064.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS062_063_064",
         test_module    => "VCU Timing System",
         tc_revision    => "2.0",
         tc_date        => "02 Jan 2020",
         tester_name    => "CABelchior",
         tc_description => "Check VCU FSM transitions at OpMode NORMAL",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_top_tb",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s
      );   

      --------------------------------------------------------
      -- Link Spy Probes
      --------------------------------------------------------

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/vcut_curst_r", "x_vcut_curst_r", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/pulse500us_i", "x_pulse500us_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/hcs_mode_i",   "x_hcs_mode_i", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/rly_out1_3V_o",  "x_rly_out1_3V_o ", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_mft_o", "x_opmode_mft_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_tst_o", "x_opmode_tst_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_dep_o", "x_opmode_dep_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_sup_o", "x_opmode_sup_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_nrm_o", "x_opmode_nrm_o", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/init_tmr_s",   "x_init_tmr_s", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/radio_ctr_r",  "x_radio_ctr_r", 0);

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
         "Check that while in OpMode NORMAL, the UUT transit from VCUT_NO_WARNING to VCUT_NORMAL");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "Check if the VCU is in the OpMode NORMAL and VCU is in the VCUT_NO_WARNING");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.1",
         "Check if the VCU is in the OpMode NORMAL (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_opmode_mft_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_tst_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_dep_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_sup_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_nrm_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.2",
         "Check if the VCU is in the VCUT_NO_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NO_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.3",
         "Check if the Gateway Warning Timer is in reset state (Expected: TRUE)");

      prev_timer <= x_radio_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = 0,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.4",
         "Check if the Gateway Alarm (x_rly_out1_3V_o) is NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_rly_out1_3V_o = '0', -- Energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2",
         "Force the UUT to transit from VCUT_NO_WARNING to VCUT_1ST_WARNING");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.2",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.3",
         "Check if the Gateway Warning Timer is in reset state (Expected: TRUE)");

      prev_timer <= x_radio_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = 0,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.4",
         "Check if the Gateway Alarm (x_rly_out1_3V_o) is NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_rly_out1_3V_o = '0', -- Energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3",
         "Wait for the VCU change state to VCUT_2ST_WARNING");

      WAIT UNTIL falling_edge(x_init_tmr_s) FOR 5.5 sec;    -- T2 Expired

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.1",
         "Check if the VCU is in the VCUT_2ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_2ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.2",
         "Check if the Gateway Warning Timer is in reset state (Expected: TRUE)");

      prev_timer <= x_radio_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = 0,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.3",
         "Check if the Gateway Alarm (x_rly_out1_3V_o) is NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_rly_out1_3V_o = '0', -- Energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4",
         "Wait for the VCU change state to VCUT_BRK_NORST");

      WAIT UNTIL falling_edge(x_init_tmr_s) FOR 5.5 sec;   -- T3 Expired

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.1",
         "Check if the VCU is in the VCUT_BRK_NORST state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_BRK_NORST,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.2",
         "Check if the Gateway Warning Timer is in reset state (Expected: TRUE)");

      prev_timer <= x_radio_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = 0,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.3",
         "Check if the Gateway Alarm (x_rly_out1_3V_o) is NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_rly_out1_3V_o = '0', -- Energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5",
         "Force the UUT to transit from VCUT_BRK_NORST to VCUT_TRN_STOP_NORST after SPD Good AND Train Standstill");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.1",
         "Force the 'Train Standstill' state along with SPD Good (no faults)");

      -- Set analog speed to [0 - 3 km/h]
      Set_Speed_Cases(1);

      -- Set logic level '1' on signal zero_spd_chX_i
      uut_in.zero_spd_ch1_s <= '1'; 
      uut_in.zero_spd_ch2_s <= '1';

      -- Wait until 'Reset T4 (On entry)'
      WAIT UNTIL falling_edge(x_init_tmr_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.2",
         "Check if the VCU is in the VCUT_TRN_STOP_NORST state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_TRN_STOP_NORST,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.3",
         "Check if the Gateway Warning Timer is in reset state (Expected: TRUE)");

      prev_timer <= x_radio_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = 0,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5.4",
         "Check if the Gateway Alarm (x_rly_out1_3V_o) is NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_rly_out1_3V_o = '0', -- Energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.6",
         "Wait for the VCU change state to VCUT_NORMAL, and stamp its time (ta = now)");

      WAIT UNTIL falling_edge(x_init_tmr_s) FOR 3.5 sec;    -- T4 Expired
      ta := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.6.1",
         "Check if the VCU is in the VCUT_NORMAL state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NORMAL,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.6.2",
         "Check if the Gateway Warning Timer is in reset state (Expected: FALSE)");

      prev_timer <= x_radio_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = unsigned(prev_timer),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = 0,
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.6.3",
         "Check if the Gateway Alarm (x_rly_out1_3V_o) is NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_rly_out1_3V_o = '0', -- Energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.7",
         "Wait until the Gateway Alarm (x_rly_out1_3V_o) IS applied and stamp its time (tb = now)");

      WAIT UNTIL x_rly_out1_3V_o = '1' FOR 30.5 sec;
      tb := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.7.1",
         "Check if the VCU is in the VCUT_NORMAL state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NORMAL,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.7.2",
         "Check if the Gateway Warning Timer reached zero");

      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = 0,
                 expected      => TRUE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.7.3",
         "Check if the time between the entry in the VCUT_NORMAL and the 'x_rly_out1_3V_o' change to '1' is 30sec");

      dt := tb - ta;
      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => (30 sec)*0.998,
                expected_max   => (30 sec)*1.002,
                report_file    => report_file,
                pass           => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.8");


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "After an UUT Reset, force the transit from OpMode NORMAL to DEPRESSED");

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.1");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2",
         "Set logic level '1' on signal hcs_mode_chX_i to force the transit from OpMode NORMAL to DEPRESSED");

      uut_in.hcs_mode_ch1_s         <= '1';
      uut_in.hcs_mode_ch2_s         <= '1';

      WAIT UNTIL x_hcs_mode_i = '1' FOR 200 ms;   -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);    -- for TMS output sync


      --==============
      -- Step 4
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------------#");
      tfy_wr_step( report_file, now, "4",
         "Check that while in OpMode DEPRESSED, the UUT transit from VCUT_NO_WARNING to VCUT_DEPRESSED");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1",
         "Check if the VCU is in the OpMode DEPRESSED and VCU is in the VCUT_NO_WARNING");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.1",
         "Check if the VCU is in the OpMode DEPRESSED (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_opmode_mft_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_tst_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_dep_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_sup_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_nrm_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.2",
         "Check if the VCU is in the VCUT_NO_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NO_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.3",
         "Check if the Gateway Warning Timer is in reset state (Expected: TRUE)");

      prev_timer <= x_radio_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = 0,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.4",
         "Check if the Gateway Alarm (x_rly_out1_3V_o) is NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_rly_out1_3V_o = '0', -- Energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2",
         "Force the UUT to transit from VCUT_NO_WARNING to VCUT_1ST_WARNING");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.2",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.3",
         "Check if the Gateway Warning Timer is in reset state (Expected: TRUE)");

      prev_timer <= x_radio_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = 0,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.4",
         "Check if the Gateway Alarm (x_rly_out1_3V_o) is NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_rly_out1_3V_o = '0', -- Energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3",
         "Wait for the VCU change state to VCUT_2ST_WARNING");

      WAIT UNTIL falling_edge(x_init_tmr_s) FOR 5.5 sec;    -- T2 Expired

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.1",
         "Check if the VCU is in the VCUT_2ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_2ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.2",
         "Check if the Gateway Warning Timer is in reset state (Expected: TRUE)");

      prev_timer <= x_radio_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = 0,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.3",
         "Check if the Gateway Alarm (x_rly_out1_3V_o) is NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_rly_out1_3V_o = '0', -- Energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4",
         "Wait for the VCU change state to VCUT_DEPRESSED, and stamp its time (ta = now)");

      WAIT UNTIL falling_edge(x_init_tmr_s) FOR 5.5 sec;   -- T3 Expired
      ta := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.1",
         "Check if the VCU is in the VCUT_DEPRESSED state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_DEPRESSED,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.2",
         "Check if the Gateway Warning Timer is in reset state (Expected: FALSE)");

      prev_timer <= x_radio_ctr_r;
      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = unsigned(prev_timer),
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = 0,
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.3",
         "Check if the Gateway Alarm (x_rly_out1_3V_o) is NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_rly_out1_3V_o = '0', -- Energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5",
         "Wait until the Gateway Alarm (x_rly_out1_3V_o) IS applied and stamp its time (tb = now)");

      WAIT UNTIL x_rly_out1_3V_o = '1' FOR 30.5 sec;
      tb := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5.1",
         "Check if the VCU is in the VCUT_DEPRESSED state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_DEPRESSED,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5.2",
         "Check if the Gateway Warning Timer reached zero");

      tfy_check( relative_time => now,         received        => unsigned(x_radio_ctr_r) = 0,
                 expected      => TRUE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5.3",
         "Check if the time between the entry in the VCUT_DEPRESSED and the 'x_rly_out1_3V_o' change to '1' is 30sec");

      dt := tb - ta;
      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => (30 sec)*0.998,
                expected_max   => (30 sec)*1.002,
                report_file    => report_file,
                pass           => pass);


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
         tc_name        => "TC_RS062_063_064",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "02 Jan 2020",
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
END ARCHITECTURE TC_RS062_063_064;

