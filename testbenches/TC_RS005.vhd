-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS005
-- Module      : DI
-- Revision    : 2.0
-- Date        : 03 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Tests the hold condition of all <Acknowledge> digital inputs with specified 'Max Activity Period'
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-5
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 07 Mar 2018
--    - CABelchior (1.0): Initial Release
-- Revision 2.0 - 03 Dec 2019
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- Notes:
--
-- sim -tc TC_RS005 -numstdoff -nocov
-- log -r /* 
--
-- 5  All digital inputs of input type 'Acknowledge' with specified 'Max Activity Period' in Table 1 
--    shall have an associated hold condition. This contion becomes valid whenever the 'Max Activity 
--    Period' is higher than the specified value and stays valid while no activity is detected in the 
--    corresponding digital input.
--
--    List of inputs with 'Acknowledge' type:
--    » Vigilance Push Button 
--
--  C_POOL_PERIOD       -> simulation\testbench\hcmt_cpld_tc_top.vhd
--  C_CLK_DERATE_BITS   -> code\hcmt_cpld\hcmt_cpld_top_p.vhd

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;
USE WORK.txt_util_p.ALL;

ARCHITECTURE TC_RS005 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Type Definitions
   --------------------------------------------------------

   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------
   SIGNAL x_opmode_curst_r                        : opmode_st_t;  -- SAS -> Figure 17
   SIGNAL x_vcut_curst_r                          : vcut_st_t;    -- SAS -> 
   SIGNAL x_single_channel_event                  : STD_LOGIC_VECTOR(CHANNEL_1_SIZE-CHANNEL_2_SIZE-1 DOWNTO 0);
   SIGNAL x_dual_channel_event                    : STD_LOGIC_VECTOR(CHANNEL_2_SIZE-1 DOWNTO 0);
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

   SIGNAL dual_in_ch1                             : STD_LOGIC_VECTOR(CHANNEL_2_SIZE-1 DOWNTO 0) := (OTHERS => '0');
   SIGNAL dual_in_ch2                             : STD_LOGIC_VECTOR(CHANNEL_2_SIZE-1 DOWNTO 0) := (OTHERS => '0');
   SIGNAL single_in_ch1                           : STD_LOGIC_VECTOR(CHANNEL_1_SIZE-CHANNEL_2_SIZE-1 DOWNTO 0) := (OTHERS => '0');

   SIGNAL dual_channel_event_latch_r              : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
   SIGNAL single_channel_event_latch_r            : STD_LOGIC_VECTOR(6 DOWNTO 0) := (OTHERS => '0');
   SIGNAL event_latch_rst_r                       : STD_LOGIC := '0';

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
      VARIABLE IDX: NATURAL;

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

      PROCEDURE Reset_Checker (Step : STRING) IS 
      BEGIN
         -------------------------------------------------
         tfy_wr_step( report_file, now, Step, 
            "Reset event checker");
         WAIT FOR 1 us;
         event_latch_rst_r <= '1';
         wait_for_clk_cycles(1, Clk);
         event_latch_rst_r <= '0';
         WAIT FOR 1 us;
      END PROCEDURE Reset_Checker;

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
         report_fname   => "TC_RS005.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS005",
         test_module    => "TS",
         tc_revision    => "2.0",
         tc_date        => "03 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Tests the hold condition of all <Acknowledge> digital inputs with specified 'Max Activity Period'",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_top_tb",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s
      );

      --------------------------------------------------------
      -- Link Spy Probes
      --------------------------------------------------------
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_fsm_i0/opmode_curst_r",      "x_opmode_curst_r", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/vcut_curst_r",    "x_vcut_curst_r", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/input_if_i0/vigi_pb_event_o",                            "x_dual_channel_event(0)", 0);

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

      -----------------------------------------------------------------------------------------------------------
      Reset_Checker("1.4");

      --==============
      -- Step 2
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 2: -------------------------------------------#");
      tfy_wr_step( report_file, now, "2",
         "For Digital Input 1 - Vigilance Push Button - do:");

      -- Rising then falling 
      -- Logic Polarity           = Active High
      -- Max Activity Period      = 1.5 sec 
      -- Activity Time-Out        = N/A
      -- Max Consecutive Events   = 8

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2",
         "Check if the 'Vigilance Push Button' event was generated (Expected: FALSE)");

      tfy_check( relative_time => now,         received        => dual_channel_event_latch_r(0) = '1',
                 expected      => FALSE,       equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      Reset_Checker("-");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3",
         "Check if the 'Vigilance Push Button' hold condition was generated (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4",
         "Check after wait for Diagnostic and LED Display Interfaces to report any change (Expected: TRUE)");
      WAIT FOR C_POOL_PERIOD * 2;

      Report_Diag_IF ("-", C_DIAG_VCU_1ST_WARN_BIT, '1', alarm_code_i);
      Report_Diag_IF ("-", C_DIAG_VCU_2ST_WARN_BIT, '0', alarm_code_i);

      -- -----------------------------------------------------------------------------------------------------------
      -- Reset_UUT("2.5");



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
         tc_name        => "TC_RS005",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "03 Dec 2019",
         s_usr_sigin_s  => s_usr_sigin_s,
         s_usr_sigout_s => s_usr_sigout_s    
      );

   END PROCESS p_steps;

    p_event_latch: PROCESS(event_latch_rst_r, x_dual_channel_event)
    BEGIN
        IF rising_edge(event_latch_rst_r) THEN
            dual_channel_event_latch_r <= (OTHERS => '0');
            single_channel_event_latch_r <= (OTHERS => '0');
        ELSE
            IF rising_edge(x_dual_channel_event(0)) THEN
                dual_channel_event_latch_r(0) <= x_dual_channel_event(0);
            END IF;

        END IF;
    END PROCESS p_event_latch;

   s_usr_sigin_s.test_select  <= test_select;
   s_usr_sigin_s.clk          <= Clk;
   test_done                  <= s_usr_sigout_s.test_done;
   pwm_func_model_data        <= pwm_func_model_data_s;
   st_ch1_in_ctrl_o           <= st_ch1_in_ctrl_s; 
   st_ch2_in_ctrl_o           <= st_ch2_in_ctrl_s; 

   minor_flt_report_s         <= uut_out.tms_minor_fault_s AND uut_out.disp_minor_fault_s;

END ARCHITECTURE TC_RS005;

