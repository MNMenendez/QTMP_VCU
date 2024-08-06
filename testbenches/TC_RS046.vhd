-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS046
-- Module      : VCU Timing System
-- Revision    : 1.0
-- Date        : 15 Jan 2020
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Check the Operation Mode Request Logic
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-46
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 15 Jan 2020
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- Notes:
--
-- sim -tc TC_RS046 -numstdoff -nocov
-- log -r /*
--
-- 46    The Operation Mode Request Logic diagram depicted in drawing 4044 3100 r8 sheet 1 Figure 1 specifies 
--       the logic equations for requesting a FPGA Operation Mode change to Suppression, Depression and Test Mode.
--
-----------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;

ARCHITECTURE TC_RS046 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------
   CONSTANT C_TIMER_DEFAULT       : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(89999, 17);   -- 45s timer
   
   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------
   SIGNAL x_vcut_curst_r                          : vcut_st_t;
   SIGNAL x_opmode_curst_r                        : opmode_st_t;

   --  OpMode Request Decoder - Timing
   SIGNAL x_pulse500us_i                          : STD_LOGIC;                     -- Internal 500us synch pulse

   --  OpMode Request Decoder - Raw Inputs
   SIGNAL x_bcp_75_i                              : STD_LOGIC;                     -- Brake Cylinder Pressure above 75% (external input)
   SIGNAL x_cab_act_i                             : STD_LOGIC;                     -- Cab Active (external input)
   SIGNAL x_cbtc_i                                : STD_LOGIC;                     -- Communication-based train control
   SIGNAL x_digi_zero_spd_i                       : STD_LOGIC;                     -- Digital zero Speed (external input)
   SIGNAL x_driverless_i                          : STD_LOGIC;                     -- Driverless (external input)
   SIGNAL x_anlg_spd_i                            : STD_LOGIC_VECTOR(7 DOWNTO 0);  -- Aggregated speed signals
   SIGNAL x_vigi_pb_i                             : STD_LOGIC;                     -- Vigilance Push Button
   SIGNAL x_tmod_xt_i                             : STD_LOGIC;                     -- Exit test mode

   --  OpMode Request Decoder - Fault Inputs
   SIGNAL x_anlg_spd_err_i                        : STD_LOGIC;                     -- Analog Speed Error (OPL ID#40)
   SIGNAL x_digi_zero_spd_flt_i                   : STD_LOGIC;                     -- Digital zero speed fault, processed from external input

   --  OpMode Request Decoder - Outputs
   SIGNAL x_zero_spd_o                            : STD_LOGIC;                    -- Calculated Zero Speed
   SIGNAL x_sup_req_o                             : STD_LOGIC;                    -- Suppression Request
   SIGNAL x_dep_req_o                             : STD_LOGIC;                    -- Depression Request
   SIGNAL x_tst_req_o                             : STD_LOGIC;                    -- Test Mode Request

   --  OpMode Request Decoder - Internal signals
   SIGNAL x_zero_spd_fault_s                      : STD_LOGIC;
   SIGNAL x_anlg_zero_spd_s                       : STD_LOGIC;
   SIGNAL x_vpb_hld_s                             : STD_LOGIC;
   SIGNAL x_tmod_req_ff_r                         : STD_LOGIC;

   -- Operation Mode FSM - Inputs
   SIGNAL x_mjr_flt_i                             : STD_LOGIC;                     -- Major Fault
   SIGNAL x_tst_req_i                             : STD_LOGIC;                     -- Test Mode Request
   SIGNAL x_dep_req_i                             : STD_LOGIC;                     -- Depression Request
   SIGNAL x_sup_req_i                             : STD_LOGIC;                     -- Suppression Request

   -- Operation Mode FSM - Outputs
   SIGNAL x_opmode_o                              : STD_LOGIC_VECTOR(4 DOWNTO 0);  -- Current Operation Mode

   --------------------------------------------------------
   -- User and check signals
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

      PROCEDURE Set_ZeroSpeed_Fault(s1,s2 : STD_LOGIC) IS
      BEGIN

         IF s1 = '1' THEN 
            -- '4-20mA Zero Speed' as FAULT
            Set_Speed_Cases(9);
            WAIT ON x_anlg_spd_err_i FOR 20.1 sec;
         END IF;

         IF s2 = '1' THEN 
            -- 'Digital Zero Speed' as FAULT
            st_ch1_in_ctrl_s(2)  <= TEST_FAIL_HIGH;
            st_ch2_in_ctrl_s(2)  <= TEST_FAIL_HIGH;
            WAIT ON x_digi_zero_spd_flt_i FOR 1.1 sec;
         END IF;

      END PROCEDURE Set_ZeroSpeed_Fault;

      PROCEDURE Set_ZeroSpeed(s1,s2 : STD_LOGIC) IS
      BEGIN

         IF s1 = '1' THEN 
            -- '4-20mA Zero Speed' as '1'
            Set_Speed_Cases(1);
            WAIT FOR 10 ms;
         END IF;

         IF s2 = '1' THEN 
            -- 'Digital Zero Speed' as '1'
            uut_in.zero_spd_ch1_s <= '1';
            uut_in.zero_spd_ch2_s <= '1';
            WAIT FOR 160 ms;
         END IF;

      END PROCEDURE Set_ZeroSpeed;

      PROCEDURE Set_InactiveMode(s1,s2,s3,s4 : STD_LOGIC) IS
      BEGIN

         IF s1 = '1' THEN 
            -- 'Driverless' as '1'
            uut_in.driverless_ch1_s <= '1';
            uut_in.driverless_ch2_s <= '1';
            WAIT FOR 160 ms;
         END IF;

         IF s2 = '1' THEN 
            -- 'BCP > 75' as '1'
            uut_in.bcp_75_ch1_s <= '1';
            uut_in.bcp_75_ch2_s <= '1';
            WAIT FOR 160 ms;
         END IF;

         IF s3 = '1' THEN 
            -- 'Zero Speed'  as '1'
            Set_ZeroSpeed('1','1');
         END IF;

         IF s4 = '1' THEN 
            -- 'Cab Active' as '1'
            uut_in.cab_act_ch1_s <= '1';
            uut_in.cab_act_ch2_s <= '1';
            WAIT FOR 160 ms;
         END IF;
      END PROCEDURE Set_InactiveMode;

      PROCEDURE Set_InhibitionMode(s1 : STD_LOGIC) IS
      BEGIN

         IF s1 = '1' THEN 
            -- 'CBTC HCS Mode' as '1'
            uut_in.hcs_mode_ch1_s <= '1';
            uut_in.hcs_mode_ch2_s <= '1';
            WAIT FOR 160 ms;
         END IF;

      END PROCEDURE Set_InhibitionMode;

      PROCEDURE Set_TestFlipFlop(s1,s2 : STD_LOGIC) IS
      BEGIN

         IF s1 = '1' THEN 
            -- 'Inactive Request' as '1'
            uut_in.driverless_ch1_s <= '1';
            uut_in.driverless_ch2_s <= '1';
            WAIT FOR 160 ms;
         END IF;

         IF s1 = '0' THEN
            -- 'Inactive Request' as '0'
            uut_in.driverless_ch1_s <= '0';
            uut_in.driverless_ch2_s <= '0';
            WAIT FOR 160 ms;
         END IF;

         IF s2 = '1' THEN 
            -- 'VPB > 3sec' as '1'
            uut_in.vigi_pb_ch1_s <= '1';
            uut_in.vigi_pb_ch2_s <= '1';
            WAIT FOR 160 ms;
            WAIT FOR 3.01 sec;
         END IF;

         IF s2 = '0' THEN
            -- 'VPB > 3sec' as '0'
            uut_in.vigi_pb_ch1_s <= '0';
            uut_in.vigi_pb_ch2_s <= '0';
            WAIT FOR 160 ms;
         END IF;

      END PROCEDURE Set_TestFlipFlop;

      PROCEDURE Set_TestMode(s1,s2,s3,s4 : STD_LOGIC) IS
      BEGIN

         IF s1 = '1' THEN 
            -- 'Test Request Flip-Flop' as '1'
            Set_TestFlipFlop('1','1');
            Set_TestFlipFlop('0','0');
         END IF;

         IF s2 = '1' THEN 
            -- 'Inactive Request' as '1'
            uut_in.driverless_ch1_s <= '1';
            uut_in.driverless_ch2_s <= '1';
            WAIT FOR 160 ms;
         END IF;

         IF s3 = '1' THEN 
            -- 'Zero Speed' as '1'
            Set_ZeroSpeed('1','1');
         END IF;

         IF s4 = '1' THEN 
            -- 'Cab Active' as '1' (Active Low)
            uut_in.cab_act_ch1_s <= '1';
            uut_in.cab_act_ch2_s <= '1';
            WAIT FOR 160 ms;
         END IF;

      END PROCEDURE Set_TestMode;

      PROCEDURE Set_ActiveMode(s1,s2,s3,s4 : STD_LOGIC) IS
      BEGIN

         IF s1 = '1' THEN 
            -- 'Inactive Request' as '1'
            Set_InactiveMode('1','0','0','0');
         END IF;

         IF s2 = '1' THEN 
            -- 'Inhibition Request' as '1'
            Set_InhibitionMode('1');
         END IF;

         IF s3 = '1' THEN 
            -- 'Test Request' as '1'
            Set_TestMode('1','1','1','0');
         END IF;

         IF s4 = '1' THEN 
            -- 'Major Fault' as '1'
            fb_func_model_behaviour(PENALTY2_FB) <= FEEDBACK_FAIL;
            WAIT FOR 150 ms;
         END IF;

      END PROCEDURE Set_ActiveMode;

   BEGIN

      --------------------------------------------------------
      -- Testcase Start Sequence
      --------------------------------------------------------
      tfy_tc_start(
         report_fname   => "TC_RS046.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS046",
         test_module    => "VCU Timing System",
         tc_revision    => "1.0",
         tc_date        => "15 Jan 2020",
         tester_name    => "CABelchior",
         tc_description => "Check the Operation Mode Request Logic",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_top_tb",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s
      );   

      --------------------------------------------------------
      -- Link Spy Probes
      --------------------------------------------------------

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/vcut_curst_r", "x_vcut_curst_r", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_fsm_i0/opmode_curst_r",   "x_opmode_curst_r", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_req_i0/pulse500us_i", "x_pulse500us_i", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_req_i0/bcp_75_i",        "x_bcp_75_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_req_i0/cab_act_i",       "x_cab_act_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_req_i0/cbtc_i",          "x_cbtc_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_req_i0/digi_zero_spd_i", "x_digi_zero_spd_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_req_i0/driverless_i",    "x_driverless_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_req_i0/anlg_spd_i",      "x_anlg_spd_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_req_i0/vigi_pb_i",       "x_vigi_pb_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_req_i0/tmod_xt_i",       "x_tmod_xt_i", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_req_i0/anlg_spd_err_i",      "x_anlg_spd_err_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_req_i0/digi_zero_spd_flt_i", "x_digi_zero_spd_flt_i", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_req_i0/zero_spd_o", "x_zero_spd_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_req_i0/sup_req_o",  "x_sup_req_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_req_i0/dep_req_o",  "x_dep_req_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_req_i0/tst_req_o",  "x_tst_req_o", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_req_i0/zero_spd_fault_s", "x_zero_spd_fault_s", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_req_i0/anlg_zero_spd_s",  "x_anlg_zero_spd_s", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_req_i0/vpb_hld_s",        "x_vpb_hld_s", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_req_i0/tmod_req_ff_r",    "x_tmod_req_ff_r", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_fsm_i0/mjr_flt_i",   "x_mjr_flt_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_fsm_i0/tst_req_i",   "x_tst_req_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_fsm_i0/dep_req_i",   "x_dep_req_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_fsm_i0/sup_req_i",   "x_sup_req_i", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_fsm_i0/opmode_o",    "x_opmode_o", 0);

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
         "Verify the 'Zero Speed Fault Logic' as per depicted on drawing 4044 3100");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1", 
         "Set and check signals as following: '4-20mA Fault' as '0', 'Digital Zero Speed Fault' as '0'");

      Set_ZeroSpeed_Fault('0','0');

      tfy_check( relative_time => now,         received        => x_anlg_spd_err_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_digi_zero_spd_flt_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1.1",
         "Check if the signal 'Zero Speed Fault' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_zero_spd_fault_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2", 
         "Set and check signals as following: '4-20mA Fault' as '0', 'Digital Zero Speed Fault' as '1'");

      Set_ZeroSpeed_Fault('0','1');

      tfy_check( relative_time => now,         received        => x_anlg_spd_err_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_digi_zero_spd_flt_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.1",
         "Check if the signal 'Zero Speed Fault' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_zero_spd_fault_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.2.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3", 
         "Set and check signals as following: '4-20mA Fault' as '1', 'Digital Zero Speed Fault' as '0'");

      Set_ZeroSpeed_Fault('1','0');

      tfy_check( relative_time => now,         received        => x_anlg_spd_err_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_digi_zero_spd_flt_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.1",
         "Check if the signal 'Zero Speed Fault' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_zero_spd_fault_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.3.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4", 
         "Set and check signals as following: '4-20mA Fault' as '1', 'Digital Zero Speed Fault' as '1'");

      Set_ZeroSpeed_Fault('1','1');

      tfy_check( relative_time => now,         received        => x_anlg_spd_err_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_digi_zero_spd_flt_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4.1",
         "Check if the signal 'Zero Speed Fault' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_zero_spd_fault_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("2.4.2");


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "Verify the 'Zero Speed Logic' as per depicted on drawing 4044 3100");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1", 
         "Set and check signals as following: '4-20mA Zero Speed' as '0', 'Digital Zero Speed' as   '0', 'Zero Speed Fault' as '0'");

      Set_ZeroSpeed('0','0');
      Set_ZeroSpeed_Fault('0','0');

      tfy_check( relative_time => now,         received        => x_anlg_zero_spd_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_digi_zero_spd_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_fault_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1.1",
         "Check if the signal 'Zero Speed' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.1.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2", 
         "Set and check signals as following: '4-20mA Zero Speed' as '0', 'Digital Zero Speed' as   '0', 'Zero Speed Fault' as '1'");

      Set_ZeroSpeed('0','0');
      Set_ZeroSpeed_Fault('0','1');

      tfy_check( relative_time => now,         received        => x_anlg_zero_spd_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_digi_zero_spd_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_fault_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.1",
         "Check if the signal 'Zero Speed' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.2.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3", 
         "Set and check signals as following: '4-20mA Zero Speed' as '0', 'Digital Zero Speed' as   '1', 'Zero Speed Fault' as '0'");

      -- 'Digital Zero Speed' as '1'
      uut_in.zero_spd_ch1_s <= '1';
      uut_in.zero_spd_ch2_s <= '1';
      WAIT FOR 160 ms;

      tfy_check( relative_time => now,         received        => x_anlg_zero_spd_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_digi_zero_spd_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_fault_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3.1",
         "Check if the signal 'Zero Speed' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.3.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4", 
         "Set and check signals as following: '4-20mA Zero Speed' as '0', 'Digital Zero Speed' as   '1', 'Zero Speed Fault' as '1'");

      -- 'Digital Zero Speed' as '1'
      uut_in.zero_spd_ch1_s <= '1';
      uut_in.zero_spd_ch2_s <= '1';
      WAIT FOR 160 ms;

      -- 'Zero Speed Fault' as '1'
      Set_Speed_Cases(9);
      WAIT ON x_anlg_spd_err_i FOR 20.1 sec;

      tfy_check( relative_time => now,         received        => x_anlg_zero_spd_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_digi_zero_spd_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_fault_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.1",
         "Check if the signal 'Zero Speed' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.4.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5", 
         "Set and check signals as following: '4-20mA Zero Speed' as '1', 'Digital Zero Speed' as   '0', 'Zero Speed Fault' as '0'");

      -- '4-20mA Zero Speed' as '1'
      Set_Speed_Cases(1);
      WAIT UNTIL falling_edge(x_pulse500us_i);

      tfy_check( relative_time => now,         received        => x_anlg_zero_spd_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_digi_zero_spd_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_fault_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5.1",
         "Check if the signal 'Zero Speed' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.5.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.6", 
         "Set and check signals as following: '4-20mA Zero Speed' as '1', 'Digital Zero Speed' as   '0', 'Zero Speed Fault' as '1'");

      -- '4-20mA Zero Speed' as '1'
      Set_Speed_Cases(1);
      WAIT UNTIL falling_edge(x_pulse500us_i);

      -- 'Zero Speed Fault' as '1'
      st_ch1_in_ctrl_s(2)  <= TEST_FAIL_HIGH;
      st_ch2_in_ctrl_s(2)  <= TEST_FAIL_HIGH;
      WAIT ON x_digi_zero_spd_flt_i FOR 1.1 sec;

      tfy_check( relative_time => now,         received        => x_anlg_zero_spd_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_digi_zero_spd_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_fault_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.6.1",
         "Check if the signal 'Zero Speed' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.6.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.7", 
         "Set and check signals as following: '4-20mA Zero Speed' as '1', 'Digital Zero Speed' as   '1', 'Zero Speed Fault' as '0'");

      -- '4-20mA Zero Speed' as '1'
      Set_Speed_Cases(1);
      WAIT UNTIL falling_edge(x_pulse500us_i);

      -- 'Digital Zero Speed' as '1'
      uut_in.zero_spd_ch1_s <= '1';
      uut_in.zero_spd_ch2_s <= '1';
      WAIT FOR 160 ms;

      tfy_check( relative_time => now,         received        => x_anlg_zero_spd_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_digi_zero_spd_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_fault_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.7.1",
         "Check if the signal 'Zero Speed' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("3.7.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.8", 
         "Set and check signals as following: '4-20mA Zero Speed' as '1', 'Digital Zero Speed' as   '1', 'Zero Speed Fault' as '1'");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.8.1",
         "This step is not possible: Zero Speed = 1 and Zero Speed Fault = 1 (at the same time)");


      --==============
      -- Step 4
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------------#");
      tfy_wr_step( report_file, now, "4",
         "Verify the 'Inactive Request Logic' as per depicted on drawing 4044 3100");        -- SUPPRESSED

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1", 
         "Set and check signals as following: 'Driverless' as '0', 'BCP > 75' as '0', 'Zero Speed'  as '0', 'Cab Active' as '0'");

      Set_InactiveMode('0','0','0','0');

      tfy_check( relative_time => now,         received        => x_driverless_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_bcp_75_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1.1",
         "Check if the signal 'Inactive Request' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_sup_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.1.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2", 
         "Set and check signals as following: 'Driverless' as '0', 'BCP > 75' as '0', 'Zero Speed'  as '0', 'Cab Active' as '1'");

      Set_InactiveMode('0','0','0','1');

      tfy_check( relative_time => now,         received        => x_driverless_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_bcp_75_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.1",
         "Check if the signal 'Inactive Request' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.2.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3", 
         "Set and check signals as following: 'Driverless' as '0', 'BCP > 75' as '0', 'Zero Speed'  as '1', 'Cab Active' as '0'");

      Set_InactiveMode('0','0','1','0');

      tfy_check( relative_time => now,         received        => x_driverless_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_bcp_75_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3.1",
         "Check if the signal 'Inactive Request' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_sup_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.3.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4", 
         "Set and check signals as following: 'Driverless' as '0', 'BCP > 75' as '0', 'Zero Speed'  as '1', 'Cab Active' as '1'");

      Set_InactiveMode('0','0','1','1');

      tfy_check( relative_time => now,         received        => x_driverless_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_bcp_75_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.1",
         "Check if the signal 'Inactive Request' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.4.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5", 
         "Set and check signals as following: 'Driverless' as '0', 'BCP > 75' as '1', 'Zero Speed'  as '0', 'Cab Active' as '0'");

      Set_InactiveMode('0','1','0','0');

      tfy_check( relative_time => now,         received        => x_driverless_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_bcp_75_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5.1",
         "Check if the signal 'Inactive Request' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_sup_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.5.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.6", 
         "Set and check signals as following: 'Driverless' as '0', 'BCP > 75' as '1', 'Zero Speed'  as '0', 'Cab Active' as '1'");

      Set_InactiveMode('0','1','0','1');

      tfy_check( relative_time => now,         received        => x_driverless_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_bcp_75_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.6.1",
         "Check if the signal 'Inactive Request' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.6.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.7", 
         "Set and check signals as following: 'Driverless' as '0', 'BCP > 75' as '1', 'Zero Speed'  as '1', 'Cab Active' as '0'");

      Set_InactiveMode('0','1','1','0');

      tfy_check( relative_time => now,         received        => x_driverless_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_bcp_75_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.7.1",
         "Check if the signal 'Inactive Request' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.7.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.8", 
         "Set and check signals as following: 'Driverless' as '0', 'BCP > 75' as '1', 'Zero Speed'  as '1', 'Cab Active' as '1'");

      Set_InactiveMode('0','1','1','1');

      tfy_check( relative_time => now,         received        => x_driverless_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_bcp_75_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.8.1",
         "Check if the signal 'Inactive Request' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.8.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.9", 
         "Set and check signals as following: 'Driverless' as '1', 'BCP > 75' as '0', 'Zero Speed'  as '0', 'Cab Active' as '0'");

      Set_InactiveMode('1','0','0','0');

      tfy_check( relative_time => now,         received        => x_driverless_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_bcp_75_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.9.1",
         "Check if the signal 'Inactive Request' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.9.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.10", 
         "Set and check signals as following: 'Driverless' as '1', 'BCP > 75' as '0', 'Zero Speed'  as '0', 'Cab Active' as '1'");

      Set_InactiveMode('1','0','0','1');

      tfy_check( relative_time => now,         received        => x_driverless_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_bcp_75_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.10.1",
         "Check if the signal 'Inactive Request' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.10.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.11", 
         "Set and check signals as following: 'Driverless' as '1', 'BCP > 75' as '0', 'Zero Speed'  as '1', 'Cab Active' as '0'");

      Set_InactiveMode('1','0','1','0');

      tfy_check( relative_time => now,         received        => x_driverless_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_bcp_75_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.11.1",
         "Check if the signal 'Inactive Request' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.11.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.12", 
         "Set and check signals as following: 'Driverless' as '1', 'BCP > 75' as '0', 'Zero Speed'  as '1', 'Cab Active' as '1'");

      Set_InactiveMode('1','0','1','1');

      tfy_check( relative_time => now,         received        => x_driverless_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_bcp_75_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.12.1",
         "Check if the signal 'Inactive Request' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.12.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.13", 
         "Set and check signals as following: 'Driverless' as '1', 'BCP > 75' as '1', 'Zero Speed'  as '0', 'Cab Active' as '0'");

      Set_InactiveMode('1','1','0','0');

      tfy_check( relative_time => now,         received        => x_driverless_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_bcp_75_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.13.1",
         "Check if the signal 'Inactive Request' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.13.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.14", 
         "Set and check signals as following: 'Driverless' as '1', 'BCP > 75' as '1', 'Zero Speed'  as '0', 'Cab Active' as '1'");

      Set_InactiveMode('1','1','0','1');

      tfy_check( relative_time => now,         received        => x_driverless_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_bcp_75_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.14.1",
         "Check if the signal 'Inactive Request' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.14.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.15", 
         "Set and check signals as following: 'Driverless' as '1', 'BCP > 75' as '1', 'Zero Speed'  as '1', 'Cab Active' as '0'");

      Set_InactiveMode('1','1','1','0');

      tfy_check( relative_time => now,         received        => x_driverless_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_bcp_75_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.15.1",
         "Check if the signal 'Inactive Request' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.15.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.16", 
         "Set and check signals as following: 'Driverless' as '1', 'BCP > 75' as '1', 'Zero Speed'  as '1', 'Cab Active' as '1'");

      Set_InactiveMode('1','1','1','1');

      tfy_check( relative_time => now,         received        => x_driverless_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_bcp_75_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.16.1",
         "Check if the signal 'Inactive Request' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("4.16.2");


      --==============
      -- Step 5
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5: -------------------------------------------#");
      tfy_wr_step( report_file, now, "5",
         "Verify the 'Inhibition Request Logic' as per depicted on drawing 4044 3100");      -- DEPRESSED

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1", 
         "Set and check signals as following: 'CBTC HCS Mode' as '0'");

      Set_InhibitionMode('0');

      tfy_check( relative_time => now,         received        => x_cbtc_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.1",
         "Check if the signal 'Inhibition Request' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_dep_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.1.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2", 
         "Set and check signals as following: 'CBTC HCS Mode' as '1'");

      Set_InhibitionMode('1');

      tfy_check( relative_time => now,         received        => x_cbtc_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.1",
         "Check if the signal 'Inhibition Request' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_dep_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("5.2.2");


      --==============
      -- Step 6
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6: -------------------------------------------#");
      tfy_wr_step( report_file, now, "6",
         "Verify the 'Test Request Flip-Flop' as per depicted on drawing 4044 3100");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1", 
         "Set and check signals as following: 'Inactive Request' as '0', 'VPB > 3sec' as '0'");

      Set_TestFlipFlop('0','0');

      tfy_check( relative_time => now,         received        => x_sup_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_vpb_hld_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1.1",
         "Check if the signal 'Test Request Flip-Flop' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_tmod_req_ff_r = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("6.1.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2", 
         "Set and check signals as following: 'Inactive Request' as '0', 'VPB > 3sec' as '1'");

      Set_TestFlipFlop('0','1');

      tfy_check( relative_time => now,         received        => x_sup_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_vpb_hld_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2.1",
         "Check if the signal 'Test Request Flip-Flop' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_tmod_req_ff_r = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("6.2.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3", 
         "Set and check signals as following: 'Inactive Request' as '1', 'VPB > 3sec' as '0'");

      Set_TestFlipFlop('1','0');

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_vpb_hld_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3.1",
         "Check if the signal 'Test Request Flip-Flop' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_tmod_req_ff_r = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("6.3.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4", 
         "Set and check signals as following: 'Inactive Request' as '1', 'VPB > 3sec' as '1'");

      Set_TestFlipFlop('1','1');

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_vpb_hld_s = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4.1",
         "Check if the signal 'Test Request Flip-Flop' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_tmod_req_ff_r = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.5", 
         "Verify the signal latch after 'Inactive Request' as '1' and 'VPB > 3sec' as '1'");

      Set_TestFlipFlop('0','0');

      tfy_check( relative_time => now,         received        => x_sup_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_vpb_hld_s = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.5.1",
         "Check if the signal 'Test Request Flip-Flop' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_tmod_req_ff_r = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("6.5.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.6", 
         "Verify the Flip-Flop reset once 'Exit from Test Mode'"); -- To be corrected

      Set_TestMode('1','1','1','0');
      WAIT FOR 100 ms;

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 10 ms);
      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 10 ms);
      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 10 ms);
      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 10 ms);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.6.1",
         "Check if the signal 'Test Request Flip-Flop' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_tmod_req_ff_r = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("6.6.2");


      --==============
      -- Step 7
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 7: -------------------------------------------#");
      tfy_wr_step( report_file, now, "7",
         "Verify the remaining 'Test Request Logic' as per depicted on drawing 4044 3100");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.1", 
         "Set and check signals as following: 'Test Request Flip-Flop' as '0', 'Inactive Request' as '0', 'Zero Speed' as '0', 'Cab Active' as '0'");

      Set_TestMode('0','0','0','0');

      tfy_check( relative_time => now,         received        => x_tmod_req_ff_r = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_sup_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.1.1",
         "Check if the signal 'Test Mode Request' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_tst_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("7.1.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.2", 
         "Set and check signals as following: 'Test Request Flip-Flop' as '0', 'Inactive Request' as '0', 'Zero Speed' as '0', 'Cab Active' as '1'");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.2.1",
         "This step is not possible: Inactive Request = 0 and Cab Active = 1 (at the same time)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.3", 
         "Set and check signals as following: 'Test Request Flip-Flop' as '0', 'Inactive Request' as '0', 'Zero Speed' as '1', 'Cab Active' as '0'");

      Set_TestMode('0','0','1','0');

      tfy_check( relative_time => now,         received        => x_tmod_req_ff_r = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_sup_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.3.1",
         "Check if the signal 'Test Mode Request' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_tst_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("7.3.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.4", 
         "Set and check signals as following: 'Test Request Flip-Flop' as '0', 'Inactive Request' as '0', 'Zero Speed' as '1', 'Cab Active' as '1'");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.4.1",
         "This step is not possible: Inactive Request = 0 and Cab Active = 1 (at the same time)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.5", 
         "Set and check signals as following: 'Test Request Flip-Flop' as '0', 'Inactive Request' as '1', 'Zero Speed' as '0', 'Cab Active' as '0'");

      Set_TestMode('0','1','0','0');

      tfy_check( relative_time => now,         received        => x_tmod_req_ff_r = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.5.1",
         "Check if the signal 'Test Mode Request' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_tst_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("7.5.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.6", 
         "Set and check signals as following: 'Test Request Flip-Flop' as '0', 'Inactive Request' as '1', 'Zero Speed' as '0', 'Cab Active' as '1'");

      Set_TestMode('0','1','0','1');

      tfy_check( relative_time => now,         received        => x_tmod_req_ff_r = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.6.1",
         "Check if the signal 'Test Mode Request' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_tst_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("7.6.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.7", 
         "Set and check signals as following: 'Test Request Flip-Flop' as '0', 'Inactive Request' as '1', 'Zero Speed' as '1', 'Cab Active' as '0'");

      Set_TestMode('0','1','1','0');

      tfy_check( relative_time => now,         received        => x_tmod_req_ff_r = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.7.1",
         "Check if the signal 'Test Mode Request' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_tst_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("7.7.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.8", 
         "Set and check signals as following: 'Test Request Flip-Flop' as '0', 'Inactive Request' as '1', 'Zero Speed' as '1', 'Cab Active' as '1'");

      Set_TestMode('0','1','1','1');

      tfy_check( relative_time => now,         received        => x_tmod_req_ff_r = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.8.1",
         "Check if the signal 'Test Mode Request' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_tst_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("7.8.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.9", 
         "Set and check signals as following: 'Test Request Flip-Flop' as '1', 'Inactive Request' as '0', 'Zero Speed' as '0', 'Cab Active' as '0'");

      Set_TestMode('1','0','0','0');

      tfy_check( relative_time => now,         received        => x_tmod_req_ff_r = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_sup_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.9.1",
         "Check if the signal 'Test Mode Request' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_tst_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("7.9.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.10", 
         "Set and check signals as following: 'Test Request Flip-Flop' as '1', 'Inactive Request' as '0', 'Zero Speed' as '0', 'Cab Active' as '1'");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.10.1",
         "This step is not possible: Inactive Request = 0 and Cab Active = 1 (at the same time)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.11", 
         "Set and check signals as following: 'Test Request Flip-Flop' as '1', 'Inactive Request' as '0', 'Zero Speed' as '1', 'Cab Active' as '0'");

      Set_TestMode('1','0','1','0');

      tfy_check( relative_time => now,         received        => x_tmod_req_ff_r = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_sup_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.11.1",
         "Check if the signal 'Test Mode Request' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_tst_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("7.11.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.12", 
         "Set and check signals as following: 'Test Request Flip-Flop' as '1', 'Inactive Request' as '0', 'Zero Speed' as '1', 'Cab Active' as '1'");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.12.1",
         "This step is not possible: Inactive Request = 0 and Cab Active = 1 (at the same time)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.13", 
         "Set and check signals as following: 'Test Request Flip-Flop' as '1', 'Inactive Request' as '1', 'Zero Speed' as '0', 'Cab Active' as '0'");

      Set_TestMode('1','1','0','0');

      tfy_check( relative_time => now,         received        => x_tmod_req_ff_r = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.13.1",
         "Check if the signal 'Test Mode Request' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_tst_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("7.13.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.14", 
         "Set and check signals as following: 'Test Request Flip-Flop' as '1', 'Inactive Request' as '1', 'Zero Speed' as '0', 'Cab Active' as '1'");

      Set_TestMode('1','1','0','1');

      tfy_check( relative_time => now,         received        => x_tmod_req_ff_r = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.14.1",
         "Check if the signal 'Test Mode Request' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_tst_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("7.14.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.15", 
         "Set and check signals as following: 'Test Request Flip-Flop' as '1', 'Inactive Request' as '1', 'Zero Speed' as '1', 'Cab Active' as '0'");

      Set_TestMode('1','1','1','0');

      tfy_check( relative_time => now,         received        => x_tmod_req_ff_r = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.15.1",
         "Check if the signal 'Test Mode Request' is '1' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_tst_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("7.15.2");

      -- The next step is only possible if a particular sequence of actions takes place, instead of Set_TestMode sequence
      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.16", 
         "Set and check signals as following: 'Test Request Flip-Flop' as '1', 'Inactive Request' as '1', 'Zero Speed' as '1', 'Cab Active' as '1'");

      -- usual sequence of events
      --------------------------------------
      -- Set_TestMode('1','1','1','1');

      -- new sequence of events
      --------------------------------------
      -- 'Test Request Flip-Flop' as '1'
      Set_TestFlipFlop('1','1');
      Set_TestFlipFlop('0','0');

      -- 'Inactive Request' as '1'
      uut_in.driverless_ch1_s <= '1';
      uut_in.driverless_ch2_s <= '1';
      WAIT FOR 160 ms;

      -- 'Cab Active' as '1' (Active Low)
      uut_in.cab_act_ch1_s <= '1';
      uut_in.cab_act_ch2_s <= '1';
      WAIT FOR 160 ms;

      -- 'Zero Speed' as '1'
      Set_ZeroSpeed('1','1');

      tfy_check( relative_time => now,         received        => x_tmod_req_ff_r = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_sup_req_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_zero_spd_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_cab_act_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.16.1",
         "Check if the signal 'Test Mode Request' is '0' (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_tst_req_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("7.16.2");


      --==============
      -- Step 8
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 8: -------------------------------------------#");
      tfy_wr_step( report_file, now, "8",
         "Verify the remaining 'Active Request Logic' as per depicted on drawing 4044 3100");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.1", 
         "Set and check signals as following: 'Inactive Request' as '0', 'Inhibition Request' as '0', 'Test Request' as '0', 'Major Fault' as '0'");

      Set_ActiveMode('0','0','0','0');

      tfy_check( relative_time => now,         received        => x_sup_req_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_dep_req_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_tst_req_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_mjr_flt_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.1.1",
         "Check if the vector 'Current OpMode' is '00001', i.e. OpMode NORMAL/ACTIVE (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_opmode_o = "00001",
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("8.1.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.2", 
         "Set and check signals as following: 'Inactive Request' as '0', 'Inhibition Request' as '0', 'Test Request' as '0', 'Major Fault' as '1'");

      Set_ActiveMode('0','0','0','1');

      tfy_check( relative_time => now,         received        => x_sup_req_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_dep_req_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_tst_req_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_mjr_flt_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.2.1",
         "Check if the vector 'Current OpMode' is '00001', i.e. OpMode NORMAL/ACTIVE (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_opmode_o = "00001",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("8.2.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.3", 
         "Set and check signals as following: 'Inactive Request' as '0', 'Inhibition Request' as '0', 'Test Request' as '1', 'Major Fault' as '0'");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.3.1",
         "This step is not possible: Inactive Request = 0 and Test Request = 1 (at the same time)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.4", 
         "Set and check signals as following: 'Inactive Request' as '0', 'Inhibition Request' as '0', 'Test Request' as '1', 'Major Fault' as '1'");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.4.1",
         "This step is not possible: Inactive Request = 0 and Test Request = 1 (at the same time)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.5", 
         "Set and check signals as following: 'Inactive Request' as '0', 'Inhibition Request' as '1', 'Test Request' as '0', 'Major Fault' as '0'");

      Set_ActiveMode('0','1','0','0');

      tfy_check( relative_time => now,         received        => x_sup_req_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_dep_req_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_tst_req_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_mjr_flt_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.5.1",
         "Check if the vector 'Current OpMode' is '00001', i.e. OpMode NORMAL/ACTIVE (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_opmode_o = "00001",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("8.5.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.6", 
         "Set and check signals as following: 'Inactive Request' as '0', 'Inhibition Request' as '1', 'Test Request' as '0', 'Major Fault' as '1'");

      Set_ActiveMode('0','1','0','1');

      tfy_check( relative_time => now,         received        => x_sup_req_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_dep_req_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_tst_req_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_mjr_flt_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.6.1",
         "Check if the vector 'Current OpMode' is '00001', i.e. OpMode NORMAL/ACTIVE (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_opmode_o = "00001",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("8.6.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.7", 
         "Set and check signals as following: 'Inactive Request' as '0', 'Inhibition Request' as '1', 'Test Request' as '1', 'Major Fault' as '0'");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.7.1",
         "This step is not possible: Inactive Request = 0 and Test Request = 1 (at the same time)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.8", 
         "Set and check signals as following: 'Inactive Request' as '0', 'Inhibition Request' as '1', 'Test Request' as '1', 'Major Fault' as '1'");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.8.1",
         "This step is not possible: Inactive Request = 0 and Test Request = 1 (at the same time)");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.9", 
         "Set and check signals as following: 'Inactive Request' as '1', 'Inhibition Request' as '0', 'Test Request' as '0', 'Major Fault' as '0'");

      Set_ActiveMode('1','0','0','0');

      tfy_check( relative_time => now,         received        => x_sup_req_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_dep_req_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_tst_req_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_mjr_flt_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.9.1",
         "Check if the vector 'Current OpMode' is '00001', i.e. OpMode NORMAL/ACTIVE (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_opmode_o = "00001",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("8.9.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.10", 
         "Set and check signals as following: 'Inactive Request' as '1', 'Inhibition Request' as '0', 'Test Request' as '0', 'Major Fault' as '1'");

      Set_ActiveMode('1','0','0','1');

      tfy_check( relative_time => now,         received        => x_sup_req_i = '1',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_dep_req_i = '0',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_tst_req_i = '0',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_mjr_flt_i = '1',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.10.1",
         "Check if the vector 'Current OpMode' is '00001', i.e. OpMode NORMAL/ACTIVE (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_opmode_o = "00001",
                  expected      => FALSE,       equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("8.10.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.11", 
         "Set and check signals as following: 'Inactive Request' as '1', 'Inhibition Request' as '0', 'Test Request' as '1', 'Major Fault' as '0'");

      Set_ActiveMode('1','0','1','0');

      tfy_check( relative_time => now,         received        => x_sup_req_i = '1',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_dep_req_i = '0',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_tst_req_i = '1',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_mjr_flt_i = '0',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.11.1",
         "Check if the vector 'Current OpMode' is '00001', i.e. OpMode NORMAL/ACTIVE (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_opmode_o = "00001",
                  expected      => FALSE,       equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("8.11.2");
   
      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.12", 
         "Set and check signals as following: 'Inactive Request' as '1', 'Inhibition Request' as '0', 'Test Request' as '1', 'Major Fault' as '1'");

      Set_ActiveMode('1','0','1','1');

      tfy_check( relative_time => now,         received        => x_sup_req_i = '1',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_dep_req_i = '0',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_tst_req_i = '1',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_mjr_flt_i = '1',
                  expected      => TRUE,        equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.12.1",
         "Check if the vector 'Current OpMode' is '00001', i.e. OpMode NORMAL/ACTIVE (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_opmode_o = "00001",
                  expected      => FALSE,       equality        => TRUE,
                  report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("8.12.2");
   
      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.13", 
         "Set and check signals as following: 'Inactive Request' as '1', 'Inhibition Request' as '1', 'Test Request' as '0', 'Major Fault' as '0'");

      Set_ActiveMode('1','1','0','0');

      tfy_check( relative_time => now,         received        => x_sup_req_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_dep_req_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_tst_req_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_mjr_flt_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.13.1",
         "Check if the vector 'Current OpMode' is '00001', i.e. OpMode NORMAL/ACTIVE (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_opmode_o = "00001",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("8.13.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.14", 
         "Set and check signals as following: 'Inactive Request' as '1', 'Inhibition Request' as '1', 'Test Request' as '0', 'Major Fault' as '1'");

      Set_ActiveMode('1','1','0','1');

      tfy_check( relative_time => now,         received        => x_sup_req_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_dep_req_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_tst_req_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_mjr_flt_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.14.1",
         "Check if the vector 'Current OpMode' is '00001', i.e. OpMode NORMAL/ACTIVE (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_opmode_o = "00001",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("8.14.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.15", 
         "Set and check signals as following: 'Inactive Request' as '1', 'Inhibition Request' as '1', 'Test Request' as '1', 'Major Fault' as '0'");

      Set_ActiveMode('1','1','1','0');

      tfy_check( relative_time => now,         received        => x_sup_req_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_dep_req_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_tst_req_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_mjr_flt_i = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.15.1",
         "Check if the vector 'Current OpMode' is '00001', i.e. OpMode NORMAL/ACTIVE (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_opmode_o = "00001",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("8.15.2");

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.16", 
         "Set and check signals as following: 'Inactive Request' as '1', 'Inhibition Request' as '1', 'Test Request' as '1', 'Major Fault' as '1'");

      Set_ActiveMode('1','1','1','1');

      tfy_check( relative_time => now,         received        => x_sup_req_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_dep_req_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_tst_req_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_mjr_flt_i = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.16.1",
         "Check if the vector 'Current OpMode' is '00001', i.e. OpMode NORMAL/ACTIVE (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => x_opmode_o = "00001",
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("8.16.2");


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
         tc_name        => "TC_RS046",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "15 Jan 2020",
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
END ARCHITECTURE TC_RS046;

