-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS065_067_137_164
-- Module      : VCU Timing System
-- Revision    : 1.0
-- Date        : 10 Jan 2020
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Check 'Penalty Brake 1 and 2 Output' behavior
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-137
--    FPGA-REQ-65
--    FPGA-REQ-66
--    FPGA-REQ-164
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 10 Jan 2020
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- Notes:
--
-- sim -tc TC_RS065_067_137_164 -numstdoff -nocov
-- log -r /*
--
-- 137   Output behaviour in Suppressed Operating modes shall be in accordance with column 'Inactive Behaviour' 
--       in drawing 4044 3105 r6 sheet 2. Output behaviour in Depressed Operating modes shall be in accordance 
--       with column 'Inhibited Behaviour' in drawing 4044 3105 r6 sheet 2.
--
-- 163   Penalty Brake Output 1 and 2 (Dry Contact)
-- 164   These outputs are active low.
--
-- 65    Each output signal that is driven by the FPGA has a feedback input signal that shall be compared after 
--       128ms from the time it is driven.
--
-- 67    Any compare error detected on any relay output (referred to as Dry Outputs) shall cause a minor fault 
--       to be flagged but will remain in current state.
--
-- Note: 
--    - Penalty Brake 1 and 2 are 'de-energise to assert'
--    - According to drawing 4044 3100 sheet 5, when in VCUT_BRK_NORST state, the transition to OpMode DEPRESSED is NOT ALLOWED
--    - According to drawing 4044 3100 sheet 5, when in VCUT_BRK_NORST state, the transition to OpMode SUPPRESSED is NOT ALLOWED
--    - A fault on Penalty Brake 1 or 2 triggers a Major Fault on top of the Minor Fault. Thus, although REQ 67 states that the output 
--      should remain in current state,  in this particular case, the Penalty Brake 1 and 2 must go to the 'asserted state' 
--      ( de-energized value ).
-----------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;

ARCHITECTURE TC_RS065_067_137_164 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------
   CONSTANT C_TIMER_DEFAULT       : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(89999, 17);   -- 45s timer
   CONSTANT C_COUNTER_PERIOD      : TIME := 250 ms;
   
   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------

   -- VCU Timing System HLB
   SIGNAL x_opmode_curst_r                        : opmode_st_t;
   SIGNAL x_vcut_curst_r                          : vcut_st_t;
   SIGNAL x_init_tmr_s                            : STD_LOGIC;     -- Initialize Centralized VCU Timer (indicates the reset)

   SIGNAL x_pulse500us_i                          : STD_LOGIC;      -- Internal 500us synch pulse
   SIGNAL x_hcs_mode_i                            : STD_LOGIC;      -- Communication-based train control (sets VCU in depressed mode)
   SIGNAL x_driverless_i                          : STD_LOGIC;      -- Driverless (external input)

   -- Output IF
   SIGNAL x_dry_flt_o                             : STD_LOGIC_VECTOR(4 DOWNTO 0);  -- persistent compare error flag

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
   SIGNAL prev_output                             : STD_LOGIC;

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
         report_fname   => "TC_RS065_067_137_164.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS065_067_137_164",
         test_module    => "VCU Timing System",
         tc_revision    => "1.0",
         tc_date        => "10 Jan 2020",
         tester_name    => "CABelchior",
         tc_description => "Check 'Penalty Brake 1 and 2 Output' behavior",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_top_tb",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s
      );   

      --------------------------------------------------------
      -- Link Spy Probes
      --------------------------------------------------------
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_fsm_i0/opmode_curst_r",   "x_opmode_curst_r", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/vcut_curst_r", "x_vcut_curst_r", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/init_tmr_s",   "x_init_tmr_s", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/pulse500us_i", "x_pulse500us_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/hcs_mode_i",   "x_hcs_mode_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/driverless_i", "x_driverless_i", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/output_if_i0/dry_flt_o",  "x_dry_flt_o", 0);

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
         "Check the 'Penalty Brake 1 Output' (penalty1_out_o) High-Logic Level scenario"); 

      fb_func_model_behaviour(PENALTY1_FB) <= FEEDBACK_OK;

      uut_in.arst_n_s     <= '0';       -- Reset UUT
      wait_for_clk_cycles(30, Clk);
      uut_in.arst_n_s     <= '1';
      WAIT FOR 10 ms;                   -- System Power Up

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "Set 'Penalty Brake 1 Output' (penalty1_out_o) from '0' to '1'");  -- forcing a transition from VCUT_NORMAL to VCUT_NO_WARNING state

      -- to VCUT_1ST_WARNING
      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -- to VCUT_BRK_NORST
      WAIT UNTIL uut_out.penalty1_out_s = '0' FOR 10.5 sec;    -- T2 and T3 Expired

      -- to VCUT_TRN_STOP_NORST
      Set_Speed_Cases(1); -- Analog Speed -> 0 – 3 km/h
      uut_in.zero_spd_ch1_s <= '1'; 
      uut_in.zero_spd_ch2_s <= '1';
      WAIT FOR 200 ms;

      -- to VCUT_NORMAL
      WAIT UNTIL falling_edge(x_init_tmr_s) FOR 3.5 sec;       -- T4 Expired

      -- to VCUT_NO_WARNING
      uut_in.cab_act_ch1_s <= '1'; 
      uut_in.cab_act_ch2_s <= '1';
      WAIT UNTIL uut_out.penalty1_out_s = '1' FOR 2.5 sec;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2",
         "Check if the 'Penalty Brake 1 Output' (penalty1_out_o) is is solid on '1' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output <= uut_out.penalty1_out_s;
      WAIT ON uut_out.penalty1_out_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => uut_out.penalty1_out_s = prev_output,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output <= uut_out.penalty1_out_s;
      WAIT ON uut_out.penalty1_out_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => uut_out.penalty1_out_s = prev_output,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => uut_out.penalty1_out_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_PEN_1_FAULT_BIT, '0', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PEN_1_RED_BIT,    '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.4");


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "Verify that a driven signal is compared after 128ms from the time it is driven");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1",
         "Set 'Penalty Brake 1 Output' (penalty1_out_o) from '0' to '1' and stamp its time (ta = now)");

      -- to VCUT_1ST_WARNING
      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -- to VCUT_BRK_NORST
      WAIT UNTIL uut_out.penalty1_out_s = '0' FOR 10.5 sec;    -- T2 and T3 Expired

      -- to VCUT_TRN_STOP_NORST
      Set_Speed_Cases(1); -- Analog Speed -> 0 – 3 km/h
      uut_in.zero_spd_ch1_s <= '1'; 
      uut_in.zero_spd_ch2_s <= '1';
      WAIT FOR 200 ms;

      -- to VCUT_NORMAL
      WAIT UNTIL falling_edge(x_init_tmr_s) FOR 3.5 sec;       -- T4 Expired

      -- to VCUT_NO_WARNING
      uut_in.cab_act_ch1_s <= '1'; 
      uut_in.cab_act_ch2_s <= '1';
      WAIT UNTIL uut_out.penalty1_out_s = '1' FOR 2.5 sec;
      ta := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2",
         "Force a feedback compare error on 'penalty1_out_o'");

      fb_func_model_behaviour(PENALTY1_FB) <= FEEDBACK_FAIL;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.1",
         "Wait until the persistent error flag is '1' and stamp its time (tb = now)");

      WAIT UNTIL x_dry_flt_o(4) = '1' FOR 200 ms;
      tb := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.2",
         "Check that a driven signal is compared after 128ms from the time it is driven (Expected: TRUE)");

      dt := tb - ta;
      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => (128 ms * 0.98),
                expected_max   => (128 ms * 1.02),
                report_file    => report_file,
                pass           => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3",
         "Check if the 'Penalty Brake 1 Output' (penalty1_out_o) is is solid on '0' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output <= uut_out.penalty1_out_s;
      WAIT ON uut_out.penalty1_out_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => uut_out.penalty1_out_s = prev_output,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output <= uut_out.penalty1_out_s;
      WAIT ON uut_out.penalty1_out_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => uut_out.penalty1_out_s = prev_output,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => uut_out.penalty1_out_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_PEN_1_FAULT_BIT, '1', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PEN_1_RED_BIT,    '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("3.6", TRUE, minor_flt_report_s);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.7");


      --==============
      -- Step 4
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------------#");
      tfy_wr_step( report_file, now, "4",
         "Check the 'Penalty Brake 2 Output' (penalty2_out_o) High-Logic Level scenario"); 

      fb_func_model_behaviour(PENALTY2_FB) <= FEEDBACK_OK;

      uut_in.arst_n_s     <= '0';       -- Reset UUT
      wait_for_clk_cycles(30, Clk);
      uut_in.arst_n_s     <= '1';
      WAIT FOR 10 ms;                   -- System Power Up

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1",
         "Set 'Penalty Brake 2 Output' (penalty2_out_o) from '0' to '1'");  -- forcing a transition from VCUT_NORMAL to VCUT_NO_WARNING state

      -- to VCUT_1ST_WARNING
      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -- to VCUT_BRK_NORST
      WAIT UNTIL uut_out.penalty2_out_s = '0' FOR 10.5 sec;

      -- to VCUT_TRN_STOP_NORST
      Set_Speed_Cases(1); -- Analog Speed -> 0 – 3 km/h
      uut_in.zero_spd_ch1_s <= '1'; 
      uut_in.zero_spd_ch2_s <= '1';
      WAIT FOR 200 ms;

      -- to VCUT_NORMAL
      WAIT UNTIL falling_edge(x_init_tmr_s);

      -- to VCUT_NO_WARNING
      uut_in.cab_act_ch1_s <= '1'; 
      uut_in.cab_act_ch2_s <= '1';
      WAIT UNTIL uut_out.penalty2_out_s = '1' FOR 2.5 sec;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2",
         "Check if the 'Penalty Brake 2 Output' (penalty2_out_o) is is solid on '1' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output <= uut_out.penalty2_out_s;
      WAIT ON uut_out.penalty2_out_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => uut_out.penalty2_out_s = prev_output,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output <= uut_out.penalty2_out_s;
      WAIT ON uut_out.penalty2_out_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => uut_out.penalty2_out_s = prev_output,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => uut_out.penalty2_out_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_PEN_2_FAULT_BIT, '0', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PEN_2_RED_BIT,    '0', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.4");


      --==============
      -- Step 5
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5: -------------------------------------------#");
      tfy_wr_step( report_file, now, "5",
         "Verify that a driven signal is compared after 128ms from the time it is driven");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1",
         "Set 'Penalty Brake 2 Output' (penalty2_out_o) from '0' to '1' and stamp its time (ta = now)");

      -- to VCUT_1ST_WARNING
      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -- to VCUT_BRK_NORST
      WAIT UNTIL uut_out.penalty2_out_s = '0' FOR 10.5 sec;

      -- to VCUT_TRN_STOP_NORST
      Set_Speed_Cases(1); -- Analog Speed -> 0 – 3 km/h
      uut_in.zero_spd_ch1_s <= '1'; 
      uut_in.zero_spd_ch2_s <= '1';
      WAIT FOR 200 ms;

      -- to VCUT_NORMAL
      WAIT UNTIL falling_edge(x_init_tmr_s);

      -- to VCUT_NO_WARNING
      uut_in.cab_act_ch1_s <= '1'; 
      uut_in.cab_act_ch2_s <= '1';
      WAIT UNTIL uut_out.penalty2_out_s = '1' FOR 2.5 sec;
      ta := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2",
         "Force a feedback compare error on 'penalty1_out_o'");

      fb_func_model_behaviour(PENALTY2_FB) <= FEEDBACK_FAIL;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.1",
         "Wait until the persistent error flag is '1' and stamp its time (tb = now)");

      WAIT UNTIL x_dry_flt_o(3) = '1' FOR 200 ms;
      tb := now;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.2",
         "Check that a driven signal is compared after 128ms from the time it is driven (Expected: TRUE)");

      dt := tb - ta;
      tfy_check(relative_time  => now, 
                received       => dt,
                expected_min   => (128 ms * 0.98),
                expected_max   => (128 ms * 1.02),
                report_file    => report_file,
                pass           => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3",
         "Check if the 'Penalty Brake 2 Output' (penalty2_out_o) is is solid on '0' (Expected: TRUE)");

      WAIT FOR 10 ms; prev_output <= uut_out.penalty2_out_s;
      WAIT ON uut_out.penalty2_out_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => uut_out.penalty2_out_s = prev_output,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_output <= uut_out.penalty2_out_s;
      WAIT ON uut_out.penalty2_out_s FOR 500 ms;

      tfy_check( relative_time => now,         received        => uut_out.penalty2_out_s = prev_output,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => uut_out.penalty2_out_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_PEN_2_FAULT_BIT, '1', alarm_code_i);
      Report_LED_IF  ("-", C_LED_PEN_2_RED_BIT,    '1', led_code_i);

      -----------------------------------------------------------------------------------------------------------
      Report_Minor_Fault("5.6", TRUE, minor_flt_report_s);


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
         tc_name        => "TC_RS065_067_137_164",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "10 Jan 2020",
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
END ARCHITECTURE TC_RS065_067_137_164;
