-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS045_100
-- Module      : VCU Timing System
-- Revision    : 2.0
-- Date        : 15 Jan 2020
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Check VCU OpMode priority
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-45
--    FPGA-REQ-100
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 15 Jan 2020
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- Notes:
--
-- sim -tc TC_RS045_100 -numstdoff -nocov
-- log -r /*
--
-- 45    The FPGA shall support five modes of operation listed in the following prioritized order (from highest to lowest):
-- 45,01 Major Fault Mode (Internal Sources)
-- 45,02 Test Mode (External Sources)
-- 45,03 Inactive (Suppressed) Mode (External Sources)
-- 45,04 Inhibitted (Depressed) Mode (External Sources)
-- 45,05 Active (Normal) Mode (Default mode)
--
-- 100   Assertion of the driveless input shall trigger a suppression mode request.
--
--    OPMODE_IDLE
--    OPMODE_MFAULT
--    OPMODE_TEST
--    OPMODE_DEPRESSED
--    OPMODE_SUPPRESSED
--    OPMODE_NORMAL
--
-----------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;

ARCHITECTURE TC_RS045_100 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Applicable Constants
   --------------------------------------------------------
   CONSTANT C_TIMER_DEFAULT       : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(89999, 17);   -- 45s timer
   
   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------
   SIGNAL x_vcut_curst_r                          : vcut_st_t;
   SIGNAL x_opmode_curst_r                        : opmode_st_t;

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
         report_fname   => "TC_RS045_100.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS045_100",
         test_module    => "VCU Timing System",
         tc_revision    => "2.0",
         tc_date        => "15 Jan 2020",
         tester_name    => "CABelchior",
         tc_description => "Check VCU OpMode priority",
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
         "Verify if the OpMode Active (NORMAL) is the default mode");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "Reset UUT and wait for 10ms for system power-up");

      uut_in.arst_n_s     <= '0';       -- Reset UUT
      wait_for_clk_cycles(30, Clk);
      uut_in.arst_n_s     <= '1';
      WAIT FOR 10 ms;                   -- System Power Up

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2",
         "Check if the VCU is in OpMode NORMAL (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_opmode_curst_r = OPMODE_NORMAL,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      -- OpModes
      Report_Diag_IF ("-", C_DIAG_VCU_MAJOR_FAULT_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_TEST_BIT,       '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_SUPPRESSED_BIT, '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_DEPRESSED_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_NORMAL_BIT,     '1', alarm_code_i);


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "Verify if the OpMode Inhibitted (DEPRESSED) has higher priority than OpMode Active (NORMAL)");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1",
         "Set logic level '1' on signal hcs_mode_chX_i to force the transit from OpMode NORMAL to DEPRESSED");

      uut_in.hcs_mode_ch1_s <= '1';
      uut_in.hcs_mode_ch2_s <= '1';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2",
         "Check if the VCU is in OpMode DEPRESSED (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_opmode_curst_r = OPMODE_DEPRESSED,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      -- OpModes
      Report_Diag_IF ("-", C_DIAG_VCU_MAJOR_FAULT_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_TEST_BIT,       '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_SUPPRESSED_BIT, '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_DEPRESSED_BIT,  '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_NORMAL_BIT,     '0', alarm_code_i);


      --==============
      -- Step 4
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------------#");
      tfy_wr_step( report_file, now, "4",
         "Verify if the OpMode Inactive (SUPPRESSED) has higher priority than OpMode Inhibitted (DEPRESSED)");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1",
         "Set logic level '1' on signal hcs_mode_chX_i to force the transit from OpMode DEPRESSED to SUPPRESSED");

      uut_in.driverless_ch1_s <= '1';
      uut_in.driverless_ch2_s <= '1';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2",
         "Check if the VCU is in OpMode SUPPRESSED (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_opmode_curst_r = OPMODE_SUPPRESSED,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      -- OpModes
      Report_Diag_IF ("-", C_DIAG_VCU_MAJOR_FAULT_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_TEST_BIT,       '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_SUPPRESSED_BIT, '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_DEPRESSED_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_NORMAL_BIT,     '0', alarm_code_i);


      --==============
      -- Step 5
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5: -------------------------------------------#");
      tfy_wr_step( report_file, now, "5",
         "Verify if the OpMode Test (TEST) has higher priority than OpMode Inactive (SUPPRESSED)");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1",
         "Set all that is required to force the transit from OpMode SUPPRESSED to TEST");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.1",
         "Force Train Standstill state");

      -- Analog Speed
      Set_Speed_Cases(1); -- [0 - 3 km/h]

      -- Digital Speed
      uut_in.zero_spd_ch1_s <= '1';
      uut_in.zero_spd_ch2_s <= '1';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.2",
         "Set logic level '0' on signal cab_act_chX_i to force the Cab Active state");

      uut_in.cab_act_ch1_s <= '0';
      uut_in.cab_act_ch2_s <= '0';
      WAIT FOR 160 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1.3",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 3 sec, i.e. 3.1 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 3.1 sec);   -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2",
         "Check if the VCU is in OpMode TEST (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_opmode_curst_r = OPMODE_TEST,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      -- OpModes
      Report_Diag_IF ("-", C_DIAG_VCU_MAJOR_FAULT_BIT,'0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_TEST_BIT,       '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_SUPPRESSED_BIT, '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_DEPRESSED_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_NORMAL_BIT,     '0', alarm_code_i);


      --==============
      -- Step 6
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6: -------------------------------------------#");
      tfy_wr_step( report_file, now, "6",
         "Verify if the OpMode Major Fault (MFAULT) has higher priority than OpMode Test (TEST)");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1",
         "Force a fault on feedback signals for Penalty Brake 1 to force the transit from OpMode TEST to MFAULT");

      fb_func_model_behaviour(PENALTY1_FB) <= FEEDBACK_FAIL;
      WAIT FOR 150 ms;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2",
         "Check if the VCU is in OpMode MFAULT (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_opmode_curst_r = OPMODE_MFAULT,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2.1",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      -- OpModes
      Report_Diag_IF ("-", C_DIAG_VCU_MAJOR_FAULT_BIT,'1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_TEST_BIT,       '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_SUPPRESSED_BIT, '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_DEPRESSED_BIT,  '0', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_NORMAL_BIT,     '0', alarm_code_i);


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
         tc_name        => "TC_RS045_100",
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
END ARCHITECTURE TC_RS045_100;

