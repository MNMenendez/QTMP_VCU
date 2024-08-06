-----------------------------------------------------------------
-- (c) Copyright 2017
-- Critical Software S.A.
-- All Rights Reserved
-----------------------------------------------------------------
-- Project     : VCU
-- Filename    : TC_RS115_052_053_056_054
-- Module      : VCU Timing System
-- Revision    : 2.0
-- Date        : 16 Dec 2019
-- Author      : CABelchior
-----------------------------------------------------------------
-- Description : Check Inactive (Suppressed) OpMode requirements complieance
-----------------------------------------------------------------
-- Requirements:
--    FPGA-REQ-115
--    FPGA-REQ-52
--    FPGA-REQ-53
--    FPGA-REQ-56
--    FPGA-REQ-54
-----------------------------------------------------------------
-- History:
-- Revision 1.0 - 07 Mar 2018
--    - J.Sousa (1.0): Initial Release
-- Revision 1.1 - 02 May 2019
-- -  VSA (1.1): CCN03 changes
-- Revision 2.0 - 16 Dec 2019
--    - CABelchior (2.0): CCN04 Updates (also test bench updates)
-----------------------------------------------------------------
-- Notes:
--
-- sim -tc TC_RS115_052_053_056_054 -numstdoff -nocov
-- log -r /*
--
-- 115   The following constraints shall be applied to Inactive (Suppressed) Operating Mode:
--       - All timers are paused;
--       - No penalty brake output;
--       - Can only enter suppressed mode from certain VCU FSM states in Normal Operating 
--         Mode or Depressed Mode, namely: 'No Warning', '1st Stage Warning' and '2nd Stage Warning'.
--
-- 52    Entering into Suppression Mode shall be inhibited if the FPGA is in (or transitioning between) any of the following Normal Mode states:
--       - (52,01) Brake Application No Reset
--       - (52,02) Train Stopped No Reset
--       - (52,03) Permanent Light Warning Reset Allowed (Normal Mode)
--
-- 53    Aside from this exception (REQ 52), Suppression Mode shall take precedence over Normal Mode.
--
-- 56    Exiting from Suppression Mode shall cause the FPGA to resume operation from where it exited at the time when the Suppression active input 
--       occurred. This also means that any associated flashing lights, buzzers and timers shall resume from where they were at the time they were 
--       paused.
--
-- 54    When exiting from Normal Mode or Depression Mode to Suppression Mode, the FPGA stops updating and all associated timers are paused. All 
--       buzzers and flashing lights shall also be deactivated when entering Suppression Mode.
--
-- Brief description of steps:
--
-- Step 2  - OpMode NORMAL to SUPPRESSED (Inactive) and back when in VCUT_NO_WARNING         » No Warning
--           » Penalty Brake at '0'
--           » Solid light_out_o at '0'
-- Step 3  - OpMode NORMAL to SUPPRESSED (Inactive) and back when in VCUT_1ST_WARNING        » 1st Stage Warning
--           » Penalty Brake at '0'
--           » Flashing light_out_o
-- Step 4  - OpMode NORMAL to SUPPRESSED (Inactive) and back when in VCUT_2ST_WARNING        » 2nd Stage Warning
--           » Penalty Brake at '0'
--           » Flashing light_out_o
--           » Audible Warning (buzzer_o)
-- Step 5  - OpMode NORMAL to SUPPRESSED (Inactive) when in VCUT_BRK_NORST                   » Brake Application No Reset
--           » Penalty Brake at '1'
--           » Flashing light_out_o
-- Step 6  - OpMode NORMAL to SUPPRESSED (Inactive) when in VCUT_TRN_STOP_NORST              » Train Stopped No Reset
--           » Penalty Brake at '1'
--           » Flashing light_out_o
-- Step 7  - OpMode NORMAL to SUPPRESSED (Inactive) when in VCUT_NORMAL                      » Normal Permanent Light Reset Allowed
--           » Penalty Brake at '1'
--           » Solid light_out_o at '1'
--
--
-- Step 8  - Force the transit from OpMode NORMAL to DEPRESSED
--
--
-- Step 9  - OpMode DEPRESSED to SUPPRESSED (Inactive) and back when in VCUT_NO_WARNING      » No Warning
-- Step 10 - OpMode DEPRESSED to SUPPRESSED (Inactive) and back when in VCUT_1ST_WARNING     » 1st Stage Warning
-- Step 11 - OpMode DEPRESSED to SUPPRESSED (Inactive) and back when in VCUT_2ST_WARNING     » 2nd Stage Warning
-- Step 12 - OpMode DEPRESSED to SUPPRESSED (Inactive) when in VCUT_DEPRESSED                » Depressed Permanent Light Reset Allowed
--
--
-- One should note that the Penalty Brake behavior is the same for OpModes NORMAL, SUPPRESSED and DEPRESSED,
-- being dependant only of the VCU State
--
--
-- @See 3.4.5.6.1. OPERATION <CSW-ARTHCMT-2018-SAS-01166-software_architecture_design_and_interface_specification_CCN04>
--    The VCU Timing FSM block interprets all inputs fed by the Analog IF to perform actions over the HCMT CPLD outputs 
--    depending on the current operation mode fed by the Operation Mode FSM block. The block implements a centralized timer, 
--    hereafter denoted as VCU Timer, that is initialized with the counter values necessary by specific states. 
-----------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.All;
USE IEEE.NUMERIC_STD.All;
USE IEEE.MATH_REAL.All;

LIBRARY modelsim_lib;
USE     modelsim_lib.util.ALL;
USE WORK.testify_p.ALL;

ARCHITECTURE TC_RS115_052_053_056_054 OF hcmt_cpld_tc_top IS

   --------------------------------------------------------
   -- Spy Probes
   --------------------------------------------------------
   SIGNAL x_opmode_curst_r                        : opmode_st_t;
   SIGNAL x_vcut_curst_r                          : vcut_st_t;

   -- Top-Level of the VCU Timing System HLB
   --------------------------------------------------------

   --  Timing
   SIGNAL x_pulse500ms_i                          : STD_LOGIC;      -- Internal 500ms synch pulse
   SIGNAL x_pulse500us_i                          : STD_LOGIC;      -- Internal 500us synch pulse

   --  Mode Selector Inputs
   SIGNAL x_bcp_75_i                              : STD_LOGIC;      -- Brake Cylinder Pressure above 75% (external input)
   SIGNAL x_cab_act_i                             : STD_LOGIC;      -- Cab Active (external input)
   SIGNAL x_hcs_mode_i                            : STD_LOGIC;      -- Communication-based train control (sets VCU in depressed mode)
   SIGNAL x_zero_spd_i                            : STD_LOGIC;      -- Zero Speed (external input)
   SIGNAL x_driverless_i                          : STD_LOGIC;      -- Driverless (external input)

   --  VCU Timing System HLB » Outputs
   SIGNAL x_vis_warn_stat_o                       : STD_LOGIC;     -- Visible Warning Status
   SIGNAL x_light_out_o                           : STD_LOGIC;     -- Flashing Light (1st Stage Warning)
   SIGNAL x_buzzer_o                              : STD_LOGIC;     -- Buzzer Output (2nd Stage Warning)
   SIGNAL x_penalty1_out_o                        : STD_LOGIC;     -- Penalty Brake 1
   SIGNAL x_penalty2_out_o                        : STD_LOGIC;     -- Penalty Brake 2
   SIGNAL x_rly_out1_3V_o                         : STD_LOGIC;     -- Gateway Warning
   SIGNAL x_vcu_rst_o                             : STD_LOGIC;     -- VCU RST (for TMS)

   SIGNAL x_opmode_mft_o                          : STD_LOGIC;     -- Notify Major Fault opmode
   SIGNAL x_opmode_tst_o                          : STD_LOGIC;     -- Notify Test opmode
   SIGNAL x_opmode_dep_o                          : STD_LOGIC;     -- Notify Depression opmode
   SIGNAL x_opmode_sup_o                          : STD_LOGIC;     -- Notify Suppression opmode
   SIGNAL x_opmode_nrm_o                          : STD_LOGIC;     -- Notify Normal opmode

   -- VCU Timing System FSM
   --------------------------------------------------------
   SIGNAL x_init_tmr_s                            : STD_LOGIC;             -- Initialize Timer
   SIGNAL x_timer_ctr_r                           : UNSIGNED(16 DOWNTO 0); -- Centralized VCU Timer » T1 | T2 | T3 | T4

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
   SIGNAL prev_light_out_state                    : STD_LOGIC;
   
BEGIN

   p_steps: PROCESS

      --------------------------------------------------------
      -- Common Test Case variable declarations
      --------------------------------------------------------
      VARIABLE pass                              : BOOLEAN := true;

      --------------------------------------------------------
      -- Other Testcase Variables
      --------------------------------------------------------
      VARIABLE t0                                : TIME;
      VARIABLE t1                                : TIME;
      VARIABLE t2                                : TIME;
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
         report_fname   => "TC_RS115_052_053_056_054.rep",
         report_file    => report_file,
         project_name   => "VCU",
         tc_name        => "TC_RS115_052_053_056_054",
         test_module    => "VCU Timing System",
         tc_revision    => "2.0",
         tc_date        => "16 Dec 2019",
         tester_name    => "CABelchior",
         tc_description => "Check Inactive (Suppressed) OpMode requirements complieance",
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

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/pulse500ms_i",       "x_pulse500ms_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/pulse500us_i",       "x_pulse500us_i", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/bcp_75_i",           "x_bcp_75_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/cab_act_i",          "x_cab_act_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/hcs_mode_i",         "x_hcs_mode_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/zero_spd_i",         "x_zero_spd_i", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/driverless_i",       "x_driverless_i", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vis_warn_stat_o",    "x_vis_warn_stat_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/light_out_o",        "x_light_out_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/buzzer_o",           "x_buzzer_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/penalty1_out_o",     "x_penalty1_out_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/penalty2_out_o",     "x_penalty2_out_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/rly_out1_3V_o",      "x_rly_out1_3V_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_rst_o",          "x_vcu_rst_o", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_mft_o",       "x_opmode_mft_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_tst_o",       "x_opmode_tst_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_dep_o",       "x_opmode_dep_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_sup_o",       "x_opmode_sup_o", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/opmode_nrm_o",       "x_opmode_nrm_o", 0);

      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/init_tmr_s",  "x_init_tmr_s", 0);
      init_signal_spy("/hcmt_cpld_top_tb/UUT/vcu_timing_system_i0/vcu_timing_fsm_i0/timer_ctr_r",  "x_timer_ctr_r", 0);

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
         "Test if the UUT is able to transit from OpMode NORMAL to SUPPRESSED (Inactive) and back when in VCUT_NO_WARNING");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.1",
         "Check if the VCU is in the VCUT_NO_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NO_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.2",
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
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3",
         "Set logic level '1' on signal driverless_chX_i");

      uut_in.driverless_ch1_s       <= '1'; 
      uut_in.driverless_ch2_s       <= '1'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.3.1",
         "Wait the input of the TMS module to change and store the current Timer value");

      WAIT UNTIL x_driverless_i = '1' FOR 200 ms; -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);    -- for TMS output sync

      prev_timer <= x_timer_ctr_r;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.4",
         "Check if the VCU is in the VCUT_NO_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NO_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.5",
         "Check if the VCU is in the OpMode SUPPRESSED (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_opmode_mft_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_tst_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_dep_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_sup_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_nrm_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.6",
         "Wait 500ms and check that the Timer was frozen");

      WAIT FOR 500 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = prev_timer,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.7",
         "Verify the related output for the current VCU state and current OpMode");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.7.1",
         "Check if the Penalty Brake are NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_penalty1_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_penalty2_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.7.2",
         "Check if the light_out_o is solid on '0' (Expected: TRUE)");

      prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      tfy_check( relative_time => now,         received        => x_light_out_o = prev_light_out_state,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      tfy_check( relative_time => now,         received        => x_light_out_o = prev_light_out_state,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_light_out_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.8",
         "Set logic level '0' on signal driverless_chX_i");

      uut_in.driverless_ch1_s       <= '0'; 
      uut_in.driverless_ch2_s       <= '0'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.8.1",
         "Wait the input of the TMS module to change");

      WAIT UNTIL x_driverless_i = '0' FOR 200 ms;  -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);     -- for TMS output sync

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.9",
         "Check if the VCU is in the VCUT_NO_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NO_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.10",
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
      tfy_wr_step( report_file, now, "2.11",
         "Wait 200ms and check that the Timer was resumed");

      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.12",
         "Verify the related output for the current VCU state and current OpMode");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.12.1",
         "Check if the Penalty Brake are NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_penalty1_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_penalty2_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "2.12.2",
         "Check if the light_out_o is solid on '0' (Expected: TRUE)");

      prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      tfy_check( relative_time => now,         received        => x_light_out_o = prev_light_out_state,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      tfy_check( relative_time => now,         received        => x_light_out_o = prev_light_out_state,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_light_out_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);


      --==============
      -- Step 3
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 3: -------------------------------------------#");
      tfy_wr_step( report_file, now, "3",
         "Test if the UUT is able to transit from OpMode NORMAL to SUPPRESSED (Inactive) and back when in VCUT_1ST_WARNING");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.2",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.3",
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
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4",
         "Set logic level '1' on signal driverless_chX_i");

      uut_in.driverless_ch1_s       <= '1'; 
      uut_in.driverless_ch2_s       <= '1'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.4.1",
         "Wait the input of the TMS module to change and store the current Timer value");

      WAIT UNTIL x_driverless_i = '1' FOR 200 ms; -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);    -- for TMS output sync

      prev_timer <= x_timer_ctr_r;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.5",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.6",
         "Check if the VCU is in the OpMode SUPPRESSED (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_opmode_mft_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_tst_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_dep_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_sup_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_nrm_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.7",
         "Wait 500ms and check that the Timer was frozen");

      WAIT FOR 500 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = prev_timer,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.8",
         "Verify the related output for the current VCU state and current OpMode");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.8.1",
         "Check if the Penalty Brake are NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_penalty1_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_penalty2_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.8.2",
         "Check if the light_out_o is solid on '0' (Expected: TRUE)");

      prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      tfy_check( relative_time => now,         received        => x_light_out_o = prev_light_out_state,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      tfy_check( relative_time => now,         received        => x_light_out_o = prev_light_out_state,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_light_out_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.9",
         "Set logic level '0' on signal driverless_chX_i");

      uut_in.driverless_ch1_s       <= '0'; 
      uut_in.driverless_ch2_s       <= '0'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.9.1",
         "Wait the input of the TMS module to change");

      WAIT UNTIL x_driverless_i = '0' FOR 200 ms;  -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);     -- for TMS output sync

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.10",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.11",
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
      tfy_wr_step( report_file, now, "3.12",
         "Wait 200ms and check that the Timer was resumed");

      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.13",
         "Verify the related output for the current VCU state and current OpMode");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.13.1",
         "Check if the Penalty Brake are NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_penalty1_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_penalty2_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "3.13.2",
         "Check if the light_out_o is flashing at freq. equal to 1Hz (50% Duty) (Expected: TRUE)");

      WAIT FOR 10 ms; prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      t0 := now;
      tfy_check( relative_time => now,         received        => x_light_out_o = (NOT prev_light_out_state),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      t1 := now;
      tfy_check( relative_time => now,         received        => x_light_out_o = (NOT prev_light_out_state),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      t2 := now;
      tfy_check( relative_time => now,         received        => x_light_out_o = (NOT prev_light_out_state),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; dt := t1 - t0;
      tfy_check(relative_time  => now, 
                received       => dT,
                expected_min   => (500 ms)*0.998,
                expected_max   => (500 ms)*1.002,
                report_file    => report_file,
                pass           => pass);

      WAIT FOR 10 ms; dt := t2 - t1;
      tfy_check(relative_time  => now, 
                received       => dT,
                expected_min   => (500 ms)*0.998,
                expected_max   => (500 ms)*1.002,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 4
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 4: -------------------------------------------#");
      tfy_wr_step( report_file, now, "4",
         "Test if the UUT is able to transit from OpMode NORMAL to SUPPRESSED (Inactive) and back when in VCUT_2ST_WARNING");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.1",
         "Wait until 'T2=5 sec' expires");

      WAIT UNTIL unsigned(x_timer_ctr_r) = 0 FOR 5 sec;
      WAIT UNTIL falling_edge(x_init_tmr_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.2",
         "Check if the VCU is in the VCUT_2ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_2ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.3",
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
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4",
         "Set logic level '1' on signal driverless_chX_i");

      uut_in.driverless_ch1_s       <= '1'; 
      uut_in.driverless_ch2_s       <= '1'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.4.1",
         "Wait the input of the TMS module to change and store the current Timer value");

      WAIT UNTIL x_driverless_i = '1' FOR 200 ms; -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);    -- for TMS output sync

      prev_timer <= x_timer_ctr_r;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.5",
         "Check if the VCU is in the VCUT_2ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_2ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.6",
         "Check if the VCU is in the OpMode SUPPRESSED (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_opmode_mft_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_tst_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_dep_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_sup_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_nrm_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.7",
         "Wait 500ms and check that the Timer was frozen");

      WAIT FOR 500 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = prev_timer,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.8",
         "Verify the related output for the current VCU state and current OpMode");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.8.1",
         "Check if the Penalty Brake are NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_penalty1_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_penalty2_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.8.2",
         "Check if the light_out_o is solid on '0' (Expected: TRUE)");

      prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      tfy_check( relative_time => now,         received        => x_light_out_o = prev_light_out_state,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      tfy_check( relative_time => now,         received        => x_light_out_o = prev_light_out_state,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_light_out_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.8.3",
         "Check if the Audible Warning (buzzer_o) is NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_buzzer_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.9",
         "Set logic level '0' on signal driverless_chX_i");

      uut_in.driverless_ch1_s       <= '0'; 
      uut_in.driverless_ch2_s       <= '0'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.9.1",
         "Wait the input of the TMS module to change");

      WAIT UNTIL x_driverless_i = '0' FOR 200 ms;  -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);     -- for TMS output sync

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.10",
         "Check if the VCU is in the VCUT_2ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_2ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.11",
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
      tfy_wr_step( report_file, now, "4.12",
         "Wait 200ms and check that the Timer was resumed");

      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.13",
         "Verify the related output for the current VCU state and current OpMode");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.13.1",
         "Check if the Penalty Brake are NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_penalty1_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_penalty2_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.13.2",
         "Check if the light_out_o is flashing at freq. equal to 1Hz (50% Duty) (Expected: TRUE)");

      WAIT FOR 10 ms; prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      t0 := now;
      tfy_check( relative_time => now,         received        => x_light_out_o = (NOT prev_light_out_state),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      t1 := now;
      tfy_check( relative_time => now,         received        => x_light_out_o = (NOT prev_light_out_state),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      t2 := now;
      tfy_check( relative_time => now,         received        => x_light_out_o = (NOT prev_light_out_state),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; dt := t1 - t0;
      tfy_check(relative_time  => now, 
                received       => dT,
                expected_min   => (500 ms)*0.998,
                expected_max   => (500 ms)*1.002,
                report_file    => report_file,
                pass           => pass);

      WAIT FOR 10 ms; dt := t2 - t1;
      tfy_check(relative_time  => now, 
                received       => dT,
                expected_min   => (500 ms)*0.998,
                expected_max   => (500 ms)*1.002,
                report_file    => report_file,
                pass           => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "4.13.3",
         "Check if the Audible Warning (buzzer_o) is applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_buzzer_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);


      --==============
      -- Step 5
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 5: -------------------------------------------#");
      tfy_wr_step( report_file, now, "5",
         "Check that the UUT is NOT able to transit from OpMode NORMAL to SUPPRESSED (Inactive) when in VCUT_BRK_NORST");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.1",
         "Wait until 'T3=5 sec' expires"); -- Analog Speed -> 90 - 110 km/h

      WAIT UNTIL unsigned(x_timer_ctr_r) = 0 FOR 5 sec;
      WAIT UNTIL falling_edge(x_init_tmr_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.2",
         "Check if the VCU is in the VCUT_BRK_NORST state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_BRK_NORST,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.3",
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
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4",
         "Set logic level '1' on signal driverless_chX_i");

      uut_in.driverless_ch1_s       <= '1'; 
      uut_in.driverless_ch2_s       <= '1'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.4.1",
         "Wait the input of the TMS module to change and store the current Timer value");

      WAIT UNTIL x_driverless_i = '1' FOR 200 ms; -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);    -- for TMS output sync

      prev_timer <= x_timer_ctr_r;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.5",
         "Check if the VCU is in the VCUT_BRK_NORST state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_BRK_NORST,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.6",
         "Check if the VCU is NOT in the OpMode SUPPRESSED (Expected: TRUE)");

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
      tfy_wr_step( report_file, now, "5.7",
         "Wait 500ms and check that the Timer was NOT frozen");

      WAIT FOR 500 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.8",
         "Verify the related output for the current VCU state and current OpMode");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.8.1",
         "Check if the Penalty Brake are applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_penalty1_out_o = '0', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_penalty2_out_o = '0', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "5.8.2",
         "Check if the light_out_o is flashing at freq. equal to 1Hz (50% Duty) (Expected: TRUE)");

      WAIT FOR 10 ms; prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      t0 := now;
      tfy_check( relative_time => now,         received        => x_light_out_o = (NOT prev_light_out_state),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      t1 := now;
      tfy_check( relative_time => now,         received        => x_light_out_o = (NOT prev_light_out_state),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      t2 := now;
      tfy_check( relative_time => now,         received        => x_light_out_o = (NOT prev_light_out_state),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; dt := t1 - t0;
      tfy_check(relative_time  => now, 
                received       => dT,
                expected_min   => (500 ms)*0.998,
                expected_max   => (500 ms)*1.002,
                report_file    => report_file,
                pass           => pass);

      WAIT FOR 10 ms; dt := t2 - t1;
      tfy_check(relative_time  => now, 
                received       => dT,
                expected_min   => (500 ms)*0.998,
                expected_max   => (500 ms)*1.002,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 6
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 6: -------------------------------------------#");
      tfy_wr_step( report_file, now, "6",
         "Test if the UUT is able to transit from OpMode NORMAL to SUPPRESSED (Inactive) when in VCUT_TRN_STOP_NORST");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1",
         "Force the 'Train Standstill' state along with SPD Good (no faults)"); -- Analog Speed -> 90 - 110 km/h

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1.1",
         "Set analog speed to [0 - 3 km/h]");
      Set_Speed_Cases(1); -- Analog Speed -> 0 – 3 km/h

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.1.2",
         "Set logic level '1' on signal zero_spd_chX_i");

      uut_in.zero_spd_ch1_s       <= '1'; 
      uut_in.zero_spd_ch2_s       <= '1';

      WAIT UNTIL x_zero_spd_i = '1' FOR 200 ms;   -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);    -- for TMS output sync

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.2",
         "Check if the VCU is in the VCUT_TRN_STOP_NORST state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_TRN_STOP_NORST,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.3",
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
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4",
         "Set logic level '1' on signal driverless_chX_i");

      uut_in.driverless_ch1_s       <= '1'; 
      uut_in.driverless_ch2_s       <= '1'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.4.1",
         "Wait the input of the TMS module to change and store the current Timer value");

      WAIT UNTIL x_driverless_i = '1' FOR 200 ms; -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);    -- for TMS output sync

      prev_timer <= x_timer_ctr_r;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.5",
         "Check if the VCU is in the VCUT_TRN_STOP_NORST state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_TRN_STOP_NORST,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.6",
         "Check if the VCU is NOT in the OpMode SUPPRESSED (Expected: TRUE)");

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
      tfy_wr_step( report_file, now, "6.7",
         "Wait 500ms and check that the Timer was NOT frozen");

      WAIT FOR 500 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.8",
         "Verify the related output for the current VCU state and current OpMode");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.8.1",
         "Check if the Penalty Brake are applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_penalty1_out_o = '0', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_penalty2_out_o = '0', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "6.8.2",
         "Check if the light_out_o is flashing at freq. equal to 1Hz (50% Duty) (Expected: TRUE)");

      WAIT FOR 10 ms; prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      t0 := now;
      tfy_check( relative_time => now,         received        => x_light_out_o = (NOT prev_light_out_state),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      t1 := now;
      tfy_check( relative_time => now,         received        => x_light_out_o = (NOT prev_light_out_state),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      t2 := now;
      tfy_check( relative_time => now,         received        => x_light_out_o = (NOT prev_light_out_state),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; dt := t1 - t0;
      tfy_check(relative_time  => now, 
                received       => dT,
                expected_min   => (500 ms)*0.998,
                expected_max   => (500 ms)*1.002,
                report_file    => report_file,
                pass           => pass);

      WAIT FOR 10 ms; dt := t2 - t1;
      tfy_check(relative_time  => now, 
                received       => dT,
                expected_min   => (500 ms)*0.998,
                expected_max   => (500 ms)*1.002,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 7
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 7: -------------------------------------------#");
      tfy_wr_step( report_file, now, "7",
         "Test if the UUT is able to transit from OpMode NORMAL to SUPPRESSED (Inactive) when in VCUT_NORMAL");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.1",
         "Wait until 'T4=3 sec' expires");

      WAIT UNTIL unsigned(x_timer_ctr_r) = 0 FOR 3 sec;
      WAIT UNTIL falling_edge(x_init_tmr_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.2",
         "Check if the VCU is in the VCUT_NORMAL state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NORMAL,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.3",
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
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.4",
         "Set logic level '1' on signal driverless_chX_i");

      uut_in.driverless_ch1_s       <= '1'; 
      uut_in.driverless_ch2_s       <= '1'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.4.1",
         "Wait the input of the TMS module to change and store the current Timer value");

      WAIT UNTIL x_driverless_i = '1' FOR 200 ms; -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);    -- for TMS output sync

      prev_timer <= x_timer_ctr_r;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.5",
         "Check if the VCU is in the VCUT_NORMAL state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NORMAL,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.6",
         "Check if the VCU is NOT in the OpMode SUPPRESSED (Expected: TRUE)");

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
      tfy_wr_step( report_file, now, "7.7",
         "Wait 500ms and check that the Timer was NOT frozen");

      WAIT FOR 500 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.8",
         "Verify the related output for the current VCU state and current OpMode");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.8.1",
         "Check if the Penalty Brake are applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_penalty1_out_o = '0', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_penalty2_out_o = '0', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "7.8.2",
         "Check if the light_out_o is solid on '1' (Expected: TRUE)");

      prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      tfy_check( relative_time => now,         received        => x_light_out_o = prev_light_out_state,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      tfy_check( relative_time => now,         received        => x_light_out_o = prev_light_out_state,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_light_out_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);


      --==============
      -- Step 8
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 8: -------------------------------------------#");
      tfy_wr_step( report_file, now, "8",
         "Force the transit from OpMode NORMAL to DEPRESSED");

      -----------------------------------------------------------------------------------------------------------
      Reset_UUT("8.1");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "8.2",
         "Set logic level '1' on signal hcs_mode_chX_i to force the transit from OpMode NORMAL to DEPRESSED");

      uut_in.hcs_mode_ch1_s         <= '1';
      uut_in.hcs_mode_ch2_s         <= '1';

      WAIT UNTIL x_hcs_mode_i = '1' FOR 200 ms;   -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);    -- for TMS output sync


      --==============
      -- Step 9
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 9: -------------------------------------------#");
      tfy_wr_step( report_file, now, "9",
         "Test if the UUT is able to transit from OpMode DEPRESSED to SUPPRESSED (Inactive) and back when in VCUT_NO_WARNING");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.1",
         "Check if the VCU is in the VCUT_NO_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NO_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.2",
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
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.3",
         "Set logic level '1' on signal driverless_chX_i");

      uut_in.driverless_ch1_s       <= '1'; 
      uut_in.driverless_ch2_s       <= '1'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.3.1",
         "Wait the input of the TMS module to change and store the current Timer value");

      WAIT UNTIL x_driverless_i = '1' FOR 200 ms; -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);    -- for TMS output sync

      prev_timer <= x_timer_ctr_r;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.4",
         "Check if the VCU is in the VCUT_NO_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NO_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.5",
         "Check if the VCU is in the OpMode SUPPRESSED (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_opmode_mft_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_tst_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_dep_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_sup_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_nrm_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.6",
         "Wait 500ms and check that the Timer was frozen");

      WAIT FOR 500 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = prev_timer,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.7",
         "Verify the related output for the current VCU state and current OpMode");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.7.1",
         "Check if the Penalty Brake are NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_penalty1_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_penalty2_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.7.2",
         "Check if the light_out_o is solid on '0' (Expected: TRUE)");

      prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      tfy_check( relative_time => now,         received        => x_light_out_o = prev_light_out_state,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      tfy_check( relative_time => now,         received        => x_light_out_o = prev_light_out_state,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_light_out_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.8",
         "Set logic level '0' on signal driverless_chX_i");

      uut_in.driverless_ch1_s       <= '0'; 
      uut_in.driverless_ch2_s       <= '0'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.8.1",
         "Wait the input of the TMS module to change");

      WAIT UNTIL x_driverless_i = '0' FOR 200 ms;  -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);     -- for TMS output sync

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.9",
         "Check if the VCU is in the VCUT_NO_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_NO_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.10",
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
      tfy_wr_step( report_file, now, "9.11",
         "Wait 200ms and check that the Timer was resumed");

      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.12",
         "Verify the related output for the current VCU state and current OpMode");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.12.1",
         "Check if the Penalty Brake are NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_penalty1_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_penalty2_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "9.12.2",
         "Check if the light_out_o is solid on '0' (Expected: TRUE)");

      prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      tfy_check( relative_time => now,         received        => x_light_out_o = prev_light_out_state,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      tfy_check( relative_time => now,         received        => x_light_out_o = prev_light_out_state,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_light_out_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);


      --==============
      -- Step 10
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 10: -------------------------------------------#");
      tfy_wr_step( report_file, now, "10",
         "Test if the UUT is able to transit from OpMode DEPRESSED to SUPPRESSED (Inactive) and back when in VCUT_1ST_WARNING");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.1",
         "Set a pulse on signal vigi_pb_chX_i with a pulse width higher than 1.5 sec, i.e. 1.51 sec");

      p_pulse_dual(uut_in.vigi_pb_ch1_s, uut_in.vigi_pb_ch2_s, 1.51 sec);  -- @see simulation\packages\hcmt_cpld_top_tb_p.vhd
                                                                           -- Takes into consideration the debounce time (157 ms) between changes

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.2",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.3",
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
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.4",
         "Set logic level '1' on signal driverless_chX_i");

      uut_in.driverless_ch1_s       <= '1'; 
      uut_in.driverless_ch2_s       <= '1'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.4.1",
         "Wait the input of the TMS module to change and store the current Timer value");

      WAIT UNTIL x_driverless_i = '1' FOR 200 ms; -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);    -- for TMS output sync

      prev_timer <= x_timer_ctr_r;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.5",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.6",
         "Check if the VCU is in the OpMode SUPPRESSED (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_opmode_mft_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_tst_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_dep_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_sup_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_nrm_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.7",
         "Wait 500ms and check that the Timer was frozen");

      WAIT FOR 500 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = prev_timer,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.8",
         "Verify the related output for the current VCU state and current OpMode");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.8.1",
         "Check if the Penalty Brake are NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_penalty1_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_penalty2_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.8.2",
         "Check if the light_out_o is solid on '0' (Expected: TRUE)");

      prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      tfy_check( relative_time => now,         received        => x_light_out_o = prev_light_out_state,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      tfy_check( relative_time => now,         received        => x_light_out_o = prev_light_out_state,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_light_out_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);


      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.9",
         "Set logic level '0' on signal driverless_chX_i");

      uut_in.driverless_ch1_s       <= '0'; 
      uut_in.driverless_ch2_s       <= '0'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.9.1",
         "Wait the input of the TMS module to change");

      WAIT UNTIL x_driverless_i = '0' FOR 200 ms;  -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);     -- for TMS output sync

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.10",
         "Check if the VCU is in the VCUT_1ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_1ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.11",
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
      tfy_wr_step( report_file, now, "10.12",
         "Wait 200ms and check that the Timer was resumed");

      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.13",
         "Verify the related output for the current VCU state and current OpMode");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.13.1",
         "Check if the Penalty Brake are NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_penalty1_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_penalty2_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "10.13.2",
         "Check if the light_out_o is flashing at freq. equal to 1Hz (50% Duty) (Expected: TRUE)");

      WAIT FOR 10 ms; prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      t0 := now;
      tfy_check( relative_time => now,         received        => x_light_out_o = (NOT prev_light_out_state),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      t1 := now;
      tfy_check( relative_time => now,         received        => x_light_out_o = (NOT prev_light_out_state),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      t2 := now;
      tfy_check( relative_time => now,         received        => x_light_out_o = (NOT prev_light_out_state),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; dt := t1 - t0;
      tfy_check(relative_time  => now, 
                received       => dT,
                expected_min   => (500 ms)*0.998,
                expected_max   => (500 ms)*1.002,
                report_file    => report_file,
                pass           => pass);

      WAIT FOR 10 ms; dt := t2 - t1;
      tfy_check(relative_time  => now, 
                received       => dT,
                expected_min   => (500 ms)*0.998,
                expected_max   => (500 ms)*1.002,
                report_file    => report_file,
                pass           => pass);


      --==============
      -- Step 11
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 11: -------------------------------------------#");
      tfy_wr_step( report_file, now, "11",
         "Test if the UUT is able to transit from OpMode DEPRESSED to SUPPRESSED (Inactive) and back when in VCUT_2ST_WARNING");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.1",
         "Wait until 'T2=5 sec' expires");

      WAIT UNTIL unsigned(x_timer_ctr_r) = 0 FOR 5 sec;
      WAIT UNTIL falling_edge(x_init_tmr_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.2",
         "Check if the VCU is in the VCUT_2ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_2ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.3",
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
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.4",
         "Set logic level '1' on signal driverless_chX_i");

      uut_in.driverless_ch1_s       <= '1'; 
      uut_in.driverless_ch2_s       <= '1'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.4.1",
         "Wait the input of the TMS module to change and store the current Timer value");

      WAIT UNTIL x_driverless_i = '1' FOR 200 ms; -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);    -- for TMS output sync

      prev_timer <= x_timer_ctr_r;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.5",
         "Check if the VCU is in the VCUT_2ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_2ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.6",
         "Check if the VCU is in the OpMode SUPPRESSED (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_opmode_mft_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_tst_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_dep_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_sup_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_opmode_nrm_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.7",
         "Wait 500ms and check that the Timer was frozen");

      WAIT FOR 500 ms;
      tfy_check( relative_time => now,         received        => x_timer_ctr_r = prev_timer,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.8",
         "Verify the related output for the current VCU state and current OpMode");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.8.1",
         "Check if the Penalty Brake are NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_penalty1_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_penalty2_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.8.2",
         "Check if the light_out_o is solid on '0' (Expected: TRUE)");

      prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      tfy_check( relative_time => now,         received        => x_light_out_o = prev_light_out_state,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      tfy_check( relative_time => now,         received        => x_light_out_o = prev_light_out_state,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_light_out_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.8.3",
         "Check if the Audible Warning (buzzer_o) is NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_buzzer_o = '0',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.9",
         "Set logic level '0' on signal driverless_chX_i");

      uut_in.driverless_ch1_s       <= '0'; 
      uut_in.driverless_ch2_s       <= '0'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.9.1",
         "Wait the input of the TMS module to change");

      WAIT UNTIL x_driverless_i = '0' FOR 200 ms;  -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);     -- for TMS output sync

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.10",
         "Check if the VCU is in the VCUT_2ST_WARNING state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_2ST_WARNING,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.11",
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
      tfy_wr_step( report_file, now, "11.12",
         "Wait 200ms and check that the Timer was resumed");

      WAIT FOR 10 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.13",
         "Verify the related output for the current VCU state and current OpMode");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.13.1",
         "Check if the Penalty Brake are NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_penalty1_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_penalty2_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.13.2",
         "Check if the light_out_o is flashing at freq. equal to 1Hz (50% Duty) (Expected: TRUE)");

      WAIT FOR 10 ms; prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      t0 := now;
      tfy_check( relative_time => now,         received        => x_light_out_o = (NOT prev_light_out_state),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      t1 := now;
      tfy_check( relative_time => now,         received        => x_light_out_o = (NOT prev_light_out_state),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      t2 := now;
      tfy_check( relative_time => now,         received        => x_light_out_o = (NOT prev_light_out_state),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      WAIT FOR 10 ms; dt := t1 - t0;
      tfy_check(relative_time  => now, 
                received       => dT,
                expected_min   => (500 ms)*0.998,
                expected_max   => (500 ms)*1.002,
                report_file    => report_file,
                pass           => pass);

      WAIT FOR 10 ms; dt := t2 - t1;
      tfy_check(relative_time  => now, 
                received       => dT,
                expected_min   => (500 ms)*0.998,
                expected_max   => (500 ms)*1.002,
                report_file    => report_file,
                pass           => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "11.13.3",
         "Check if the Audible Warning (buzzer_o) is applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_buzzer_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);


      --==============
      -- Step 12
      --==============

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_console(" [*] Step 12: -------------------------------------------#");
      tfy_wr_step( report_file, now, "12",
         "Check that the UUT is NOT able to transit from DEPRESSED to SUPPRESSED (Inactive) when in VCUT_DEPRESSED");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.1",
         "Wait until 'T3=5 sec' expires"); -- Analog Speed -> 90 - 110 km/h

      WAIT UNTIL unsigned(x_timer_ctr_r) = 0 FOR 5 sec;
      WAIT UNTIL falling_edge(x_init_tmr_s);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.2",
         "Check if the VCU is in the VCUT_DEPRESSED state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_DEPRESSED,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.3",
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
      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.4",
         "Set logic level '1' on signal driverless_chX_i");

      uut_in.driverless_ch1_s       <= '1'; 
      uut_in.driverless_ch2_s       <= '1'; 

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.4.1",
         "Wait the input of the TMS module to change and store the current Timer value");

      WAIT UNTIL x_driverless_i = '1' FOR 200 ms; -- because of 1st and 2nd debouncers
      WAIT UNTIL falling_edge(x_pulse500us_i);    -- for TMS output sync

      prev_timer <= x_timer_ctr_r;

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.5",
         "Check if the VCU is in the VCUT_DEPRESSED state (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_vcut_curst_r = VCUT_DEPRESSED,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.6",
         "Check if the VCU is NOT in the OpMode SUPPRESSED (Expected: TRUE)");

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
      tfy_wr_step( report_file, now, "12.7",
         "Wait 500ms and check that the Timer was NOT frozen");

      WAIT FOR 500 ms;
      tfy_check( relative_time => now,         received        => unsigned(x_timer_ctr_r) < unsigned(prev_timer),
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.8",
         "Verify the related output for the current VCU state and current OpMode");

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.8.1",
         "Check if the Penalty Brake are NOT applied (Expected: TRUE)");

      tfy_check( relative_time => now,         received        => x_penalty1_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_penalty2_out_o = '1', -- De-energise to assert
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      -----------------------------------------------------------------------------------------------------------
      tfy_wr_step( report_file, now, "12.8.2",
         "Check if the light_out_o is solid on '1' (Expected: TRUE)");

      prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      tfy_check( relative_time => now,         received        => x_light_out_o = prev_light_out_state,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      prev_light_out_state <= x_light_out_o;
      WAIT ON x_light_out_o FOR 500 ms;

      tfy_check( relative_time => now,         received        => x_light_out_o = prev_light_out_state,
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);

      tfy_check( relative_time => now,         received        => x_light_out_o = '1',
                 expected      => TRUE,        equality        => TRUE,
                 report_file   => report_file, pass            => pass);


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
         tc_name        => "TC_RS115_052_053_056_054",
         tb_name        => "hcmt_cpld_top_tb",
         dut_name       => "hcmt_cpld_tc_top",
         tester_name    => "CABelchior",
         tc_date        => "16 Dec 2019",
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
END ARCHITECTURE TC_RS115_052_053_056_054;

