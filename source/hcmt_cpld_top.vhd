---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : hcmt_cpld_top.vhd
-- Module      : hcmt_cpld_top
-- Revision    : 1.12
-- Date/Time   : May 31, 2021
-- Author      : JMonteiro, ALopes, AFernandes, NRibeiro
---------------------------------------------------------------
-- Description : Top level structure of the HCMT CPLD.
---------------------------------------------------------------
-- History :
-- Revision 1.12- May 31, 2021
--    - NRibeiro: [CCN05/CCN06] Applied code review comments.
-- Revision 1.11- April 20, 2021
--    - NRibeiro: [CCN05] Fixed an issue related to the connection of the "spd_lim_override_s" signal
-- Revision 1.10- February 04, 2020
--    - NRibeiro: Code coverage improvements
-- Revision 1.9 - January 28, 2020
--    - NRibeiro: Speed Limit out signals which were muxed in Top level, where moved to Speed Limit momdule            
-- Revision 1.8 - January 10, 2020
--    - NRibeiro: Fixing conditions for speed limit exceeded (de)assertion
-- Revision 1.7 - December 11, 2019
--    - NRibeiro: Code/Comments cleanup.
-- Revision 1.6 - November 29, 2019
--    - NRibeiro: Applied CCN04 code changes.
-- Revision 1.5 - June 14, 2019
--    - AFernandes: Applied CCN03 code changes.
-- Revision 1.4 - July 27, 2018
--    - AFernandes: Applied CCN02 code changes.
-- Revision 1.3 - May 16, 2018
--    - JMonteiro: Applied code review comments for baseline 02.
-- Revision 1.2 - March 08, 2018
--    - JMonteiro: Applied code review comments.
-- Revision 1.1 - March 05, 2018
--    - JMonteiro: Connected major and minor faults to diag_IF
-- Revision 1.0 - January 1, 2018
--    - JMonteiro: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE WORK.HCMT_CPLD_TOP_P.ALL;


ENTITY hcmt_cpld_top IS
   PORT (

      ----------------------------------------------------------------------------
      --  Generic ports
      ----------------------------------------------------------------------------
      arst_n_i                : IN STD_LOGIC;
      clk_i                   : IN STD_LOGIC;    -- REQ: 1

      ----------------------------------------------------------------------------
      --  Safety-Related Digital Inputs
      ----------------------------------------------------------------------------
      vigi_pb_ch1_i           : IN STD_LOGIC;    -- Vigilance Push Button Input Channel #1
      vigi_pb_ch2_i           : IN STD_LOGIC;    -- Vigilance Push Button Input Channel #2

      spd_lim_override_ch1_i  : IN STD_LOGIC;    -- Speed Limiter Override Input Channel #1
      spd_lim_override_ch2_i  : IN STD_LOGIC;    -- Speed Limiter Override Input Channel #2

      zero_spd_ch1_i          : IN STD_LOGIC;    -- Zero Speed Input Channel #1
      zero_spd_ch2_i          : IN STD_LOGIC;    -- Zero Speed Input Channel #2

      hcs_mode_ch1_i          : IN STD_LOGIC;    -- High Capacity Signaling Mode Input Channel #1
      hcs_mode_ch2_i          : IN STD_LOGIC;    -- High Capacity Signaling Mode Input Channel #2

      bcp_75_ch1_i            : IN STD_LOGIC;    -- Brake Cylinder Pressure above 75% Input Channel #1
      bcp_75_ch2_i            : IN STD_LOGIC;    -- Brake Cylinder Pressure above 75% Input Channel #2

      not_isol_ch1_i          : IN STD_LOGIC;    -- Not Isolated Input Channel #1
      not_isol_ch2_i          : IN STD_LOGIC;    -- Not Isolated Input Channel #2

      cab_act_ch1_i           : IN STD_LOGIC;    -- Cab Active Input Channel #1
      cab_act_ch2_i           : IN STD_LOGIC;    -- Cab Active Input Channel #2

      driverless_ch1_i        : IN STD_LOGIC;    -- Driverless Input Channel #1
      driverless_ch2_i        : IN STD_LOGIC;    -- Driverless Input Channel #2

      spd_lim_ch1_i           : IN STD_LOGIC;    -- Speed Limiter Input Channel #1
      spd_lim_ch2_i           : IN STD_LOGIC;    -- Speed Limiter Input Channel #2

      ----------------------------------------------------------------------------
      --  Regular Digital Inputs
      ----------------------------------------------------------------------------
      horn_low_i              : IN STD_LOGIC;    -- Horn Low
      horn_high_i             : IN STD_LOGIC;    -- Horn High

      hl_low_i                : IN STD_LOGIC;    -- Headlight Low

      w_wiper_pb_i            : IN STD_LOGIC;    -- Washer Wiper Push Button

      ss_bypass_pb_i          : IN STD_LOGIC;    -- Safety system bypass Push Button

      pwm_ch1_i               : IN STD_LOGIC;    -- Pulse Width Modulated Input Cahnnel #1
      pwm_ch2_i               : IN STD_LOGIC;    -- Pulse Width Modulated Input Cahnnel #2

      ----------------------------------------------------------------------------
      --  Analog Inputs
      ----------------------------------------------------------------------------
      spd_l3kmh_i             : IN STD_LOGIC;     -- 4-20mA Speed Indicating < 3km/h
      spd_h3kmh_i             : IN STD_LOGIC;     -- 4-20mA Speed Indicating > 3km/h
      spd_h23kmh_a_i          : IN STD_LOGIC;     -- 4-20mA Speed Indicating > 23km/h
      spd_h23kmh_b_i          : IN STD_LOGIC;     -- 4-20mA Speed Indicating > 23km/h (dual counterpart)
      spd_h25kmh_a_i          : IN STD_LOGIC;     -- 4-20mA Speed Indicating > 25km/h
      spd_h25kmh_b_i          : IN STD_LOGIC;     -- 4-20mA Speed Indicating > 25km/h (dual counterpart)
      spd_h75kmh_i            : IN STD_LOGIC;     -- 4-20mA Speed Indicating > 75km/h
      spd_h90kmh_i            : IN STD_LOGIC;     -- 4-20mA Speed Indicating > 90km/h
      spd_h110kmh_i           : IN STD_LOGIC;     -- 4-20mA Speed Indicating > 100km/h
      spd_over_spd_i          : IN STD_LOGIC;     -- 4-20mA Speed Indicating Speed Overrange

      ps1_stat_i              : IN STD_LOGIC;     -- Power Supply #1 Status
      ps2_stat_i              : IN STD_LOGIC;     -- Power Supply #2 Status

      force_fault_ch1_i       : IN STD_LOGIC;     -- Signals external CH1 test circuitry fault
      force_fault_ch2_i       : IN STD_LOGIC;     -- Signals external CH1 test circuitry fault

      ----------------------------------------------------------------------------
      --  Feedback inputs for Digital Outputs
      ----------------------------------------------------------------------------
      light_out_fb_i          : IN STD_LOGIC;    -- Warning Light Signal Feedback

      tms_pb_fb_i             : IN STD_LOGIC;    -- TMS Vigilance Push Button Signal Feedback
      tms_spd_lim_overridden_fb_i: IN STD_LOGIC; -- TMS Speed Limit Overridden Signal Feedback
      tms_rst_fb_i            : IN STD_LOGIC;    -- TMS Vigilance Reset Signal Feedback
      tms_penalty_stat_fb_i   : IN STD_LOGIC;    -- TMS Penalty Brake Status Signal Feedback
      tms_major_fault_fb_i    : IN STD_LOGIC;    -- TMS Vigilance Major Fault Signal Feedback
      tms_minor_fault_fb_i    : IN STD_LOGIC;    -- TMS Vigilance Minor Fault Signal Feedback
      tms_depressed_fb_i      : IN STD_LOGIC;    -- TMS Vigilance Depressed Mode Signal Feedback
      tms_suppressed_fb_i     : IN STD_LOGIC;    -- TMS Vigilance Suppressed Mode Signal Feedback
      tms_vis_warn_stat_fb_i  : IN STD_LOGIC;    -- TMS Visible Warning Status Output Feedback
      tms_spd_lim_stat_fb_i   : IN STD_LOGIC;    -- TMS Speed Limit Timer Status Signal Feedback

      buzzer_out_fb_i         : IN STD_LOGIC;    -- Warning Buzzer Signal Feedback

      penalty2_fb_i           : IN STD_LOGIC;     -- Penalty Brake Channel #2 Signal Feedback Input
      penalty1_fb_i           : IN STD_LOGIC;     -- Penalty Brake Channel #1 Signal Feedback Input

      rly_fb3_3V_i            : IN STD_LOGIC;     -- Relay 3 (Speed Limit Exceeded 2) Feedback.
      rly_fb2_3V_i            : IN STD_LOGIC;     -- Relay 2 (Speed Limit Exceeded 1) Feedback.
      rly_fb1_3V_i            : IN STD_LOGIC;     -- Relay 1 (Radio Warning Relay) Feedback

      ----------------------------------------------------------------------------
      --  Digital Outputs
      ----------------------------------------------------------------------------
      light_out_o             : OUT STD_LOGIC;    -- Warning Light

      tms_pb_o                : OUT STD_LOGIC;    -- TMS Vigilance Push Button
      tms_spd_lim_overridden_o: OUT STD_LOGIC;    -- TMS Speed Limit Overridden Signal Feedback
      tms_rst_o               : OUT STD_LOGIC;    -- TMS Vigilance Reset
      tms_penalty_stat_o      : OUT STD_LOGIC;    -- TMS Penalty Brake Status
      tms_major_fault_o       : OUT STD_LOGIC;    -- TMS Vigilance Major Fault
      tms_minor_fault_o       : OUT STD_LOGIC;    -- TMS Vigilance Minor Fault
      tms_depressed_o         : OUT STD_LOGIC;    -- TMS Vigilance Depressed Mode
      tms_suppressed_o        : OUT STD_LOGIC;    -- TMS Vigilance Suppressed Mode
      tms_vis_warn_stat_o     : OUT STD_LOGIC;    -- TMS Visible Warning Status Output
      tms_spd_lim_stat_o      : OUT STD_LOGIC;    -- TMS Speed Limit Timer Status

      buzzer_out_o            : OUT STD_LOGIC;    -- Warning Buzzer

      penalty1_out_o          : OUT STD_LOGIC;    -- Penalty Brake Channel #1 Output
      penalty2_out_o          : OUT STD_LOGIC;    -- Penalty Brake Channel #2 Output

      test_low_ch1_o          : OUT STD_LOGIC;    -- Self Test Low Channel #1 Output
      test_low_ch2_o          : OUT STD_LOGIC;    -- Self Test Low Channel #2 Output

      test_high_ch1_o         : OUT STD_LOGIC;    -- Self Test High Channel #1 Output
      test_high_ch2_o         : OUT STD_LOGIC;    -- Self Test High Channel #1 Output

      penalty1_wd_o           : OUT STD_LOGIC;    -- Watch Dog Signal for Reactive fault module #1 Output
      penalty2_wd_o           : OUT STD_LOGIC;    -- Watch Dog Signal for Reactive fault module #2 Output

      disp_clk_o              : OUT STD_LOGIC;    -- LED Display Module Clock
      disp_data_o             : OUT STD_LOGIC;    -- LED Display Module Data
      disp_strobe_o           : OUT STD_LOGIC;    -- LED Display Module Strobe
      disp_oe_o               : OUT STD_LOGIC;    -- LED Display Module Outpput Enable (Active Low)
      disp_major_fault_o      : OUT STD_LOGIC;    -- LED Display Major Fault LED
      disp_minor_fault_o      : OUT STD_LOGIC;    -- LED Display Minor Fault LED

      diag_clk_o              : OUT STD_LOGIC;    -- Diagnostics Module Clock
      diag_data_o             : OUT STD_LOGIC;    -- Diagnostics Module Data
      diag_strobe_o           : OUT STD_LOGIC;    -- Diagnostics Module Strobe

      status_led_o            : OUT STD_LOGIC;    -- Status LED

      rly_out3_3V_o           : OUT STD_LOGIC;    -- Speed Limit Exceeded 2.
      rly_out2_3V_o           : OUT STD_LOGIC;    -- Speed Limit Exceeded 1.
      rly_out1_3V_o           : OUT STD_LOGIC     -- Radio Warning Relay

   );
END hcmt_cpld_top;


ARCHITECTURE str OF hcmt_cpld_top IS

   --------------------------------------------------------
   -- COMPONENTS
   --------------------------------------------------------
   -- Timing
   COMPONENT timing IS
      PORT (
         aextrst_i         : IN  STD_LOGIC;  -- External async reset in
         clk_i             : IN  STD_LOGIC;
         pulse500ms_o      : OUT STD_LOGIC;
         pulse250ms_o      : OUT STD_LOGIC;
         pulse500us_o      : OUT STD_LOGIC;
         pulse15_625us_o   : OUT STD_LOGIC;  -- 31.25us pulse
         pulse78ms_o       : OUT STD_LOGIC;  -- 78ms pulse
         pulsedisp_o       : OUT STD_LOGIC;
         pulsepwm_o        : OUT STD_LOGIC;
         rst_o             : OUT STD_LOGIC   -- Reset for rest of system
   );
   END COMPONENT timing;

   -- Input Interface HLB
   COMPONENT input_if IS
   PORT (

      ----------------------------------------------------------------------------
      --  Generic ports
      ----------------------------------------------------------------------------
      arst_i                    : IN  STD_LOGIC;
      clk_i                     : IN  STD_LOGIC;

      pulse500us_i              : IN  STD_LOGIC;
      pulse15_625us_i           : IN  STD_LOGIC;
      pulse500ms_i              : IN  STD_LOGIC;
      pulse78ms_i               : IN  STD_LOGIC;
      pulsepwm_i                : IN  STD_LOGIC;

      ----------------------------------------------------------------------------
      --  Safety-Related Digital Inputs
      ----------------------------------------------------------------------------
      vigi_pb_ch1_i             : IN STD_LOGIC;    -- Vigilance Push Button Input Channel #1
      vigi_pb_ch2_i             : IN STD_LOGIC;    -- Vigilance Push Button Input Channel #2

      spd_lim_override_ch1_i    : IN STD_LOGIC;    -- Speed Limiter Override Input Channel #1
      spd_lim_override_ch2_i    : IN STD_LOGIC;    -- Speed Limiter Override Input Channel #2

      zero_spd_ch1_i            : IN STD_LOGIC;    -- Zero Speed Input Channel #1
      zero_spd_ch2_i            : IN STD_LOGIC;    -- Zero Speed Input Channel #2

      hcs_mode_ch1_i            : IN STD_LOGIC;    -- High Capacity Signaling  Mode Input Channel #1
      hcs_mode_ch2_i            : IN STD_LOGIC;    -- High Capacity Signaling  Mode Input Channel #2

      bcp_75_ch1_i              : IN STD_LOGIC;    -- Brake Cylinder Pressure above 75% Input Channel #1
      bcp_75_ch2_i              : IN STD_LOGIC;    -- Brake Cylinder Pressure above 75% Input Channel #2

      not_isol_ch1_i            : IN STD_LOGIC;    -- Not Isolated Input Channel #1
      not_isol_ch2_i            : IN STD_LOGIC;    -- Not Isolated Input Channel #2

      cab_act_ch1_i             : IN STD_LOGIC;    -- Cab Active Input Channel #1
      cab_act_ch2_i             : IN STD_LOGIC;    -- Cab Active Input Channel #2

      driverless_ch1_i          : IN STD_LOGIC;    -- Driverless Input Channel #1
      driverless_ch2_i          : IN STD_LOGIC;    -- Driverless Input Channel #2

      spd_lim_ch1_i             : IN STD_LOGIC;    -- Speed Limiter Input Channel #1
      spd_lim_ch2_i             : IN STD_LOGIC;    -- Speed Limiter Input Channel #2

      ----------------------------------------------------------------------------
      --  Regular Digital Inputs
      ----------------------------------------------------------------------------
      horn_low_i                : IN STD_LOGIC;    -- Horn Low
      horn_high_i               : IN STD_LOGIC;    -- Horn High

      hl_low_i                  : IN STD_LOGIC;    -- Headlight Low

      w_wiper_pb_i              : IN STD_LOGIC;    -- Washer Wiper Push Button

      ss_bypass_pb_i            : IN STD_LOGIC;    -- Safety system bypass Push Button

      pwm_ch1_i                 : IN STD_LOGIC;    -- Pulse Width Modulated Input Cahnnel #1
      pwm_ch2_i                 : IN STD_LOGIC;    -- Pulse Width Modulated Input Cahnnel #2

      ----------------------------------------------------------------------------
      --  Analog Inputs
      ----------------------------------------------------------------------------
      spd_l3kmh_i                : IN STD_LOGIC;   -- 4-20mA Speed Indicating < 3km/h
      spd_h3kmh_i                : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 3km/h
      spd_h23kmh_a_i             : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 23km/h
      spd_h23kmh_b_i             : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 23km/h (dual counterpart)
      spd_h25kmh_a_i             : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 25km/h
      spd_h25kmh_b_i             : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 25km/h (dual counterpart)
      spd_h75kmh_i               : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 75km/h
      spd_h90kmh_i               : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 90km/h
      spd_h110kmh_i              : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 100km/h
      spd_over_spd_i             : IN STD_LOGIC;   -- 4-20mA Speed Indicating Speed Overrange

      ps1_stat_i                 : IN STD_LOGIC;   -- Power Supply #1 Status
      ps2_stat_i                 : IN STD_LOGIC;   -- Power Supply #2 Status

      ----------------------------------------------------------------------------
      --  Test Inputs
      ----------------------------------------------------------------------------
      force_fault_ch1_i          : IN STD_LOGIC;
      force_fault_ch2_i          : IN STD_LOGIC;

      ----------------------------------------------------------------------------
      --  Outputs
      ----------------------------------------------------------------------------
      spd_l3kmh_o                : OUT STD_LOGIC;  -- 4-20mA Speed Indicating < 3km/h
      spd_h3kmh_o                : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 3km/h
      spd_h23kmh_o               : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 23km/h
      spd_h25kmh_o               : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 25km/h
      spd_h75kmh_o               : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 75km/h
      spd_h90kmh_o               : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 90km/h
      spd_h110kmh_o              : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 100km/h
      spd_over_spd_o             : OUT STD_LOGIC;  -- 4-20mA Speed Indicating Speed Overrange

      spd_err_o                  : OUT STD_LOGIC;  -- Analog Speed Error / Minor Fault (OPL ID#40)

      -- Test mode
      test_low_ch1_o             : OUT STD_LOGIC;  -- Self Test Low Channel #1 Output
      test_low_ch2_o             : OUT STD_LOGIC;  -- Self Test Low Channel #2 Output

      test_high_ch1_o            : OUT STD_LOGIC;  -- Self Test High Channel #1 Output
      test_high_ch2_o            : OUT STD_LOGIC;  -- Self Test High Channel #1 Output

      vigi_pb_event_o            : OUT STD_LOGIC;
      spd_lim_override_event_o   : OUT STD_LOGIC;
      zero_spd_event_o           : OUT STD_LOGIC;
      hcs_mode_event_o           : OUT STD_LOGIC;
      bcp_75_event_o             : OUT STD_LOGIC;
      not_isol_event_o           : OUT STD_LOGIC;
      cab_act_event_o            : OUT STD_LOGIC;
      horn_low_event_o           : OUT STD_LOGIC;
      horn_high_event_o          : OUT STD_LOGIC;
      hl_low_event_o             : OUT STD_LOGIC;
      w_wiper_pb_event_o         : OUT STD_LOGIC;
      ss_bypass_pb_event_o       : OUT STD_LOGIC;
      driverless_event_o         : OUT STD_LOGIC;
      spd_lim_event_o            : OUT STD_LOGIC;

      vigi_pb_hld_o              : OUT STD_LOGIC;
      spd_lim_override_hld_o     : OUT STD_LOGIC;

      -- Pre-event output to TMS
      spd_lim_override_o         : OUT STD_LOGIC;
      vigi_pb_o                  : OUT STD_LOGIC;

      -- For LED display and uC
      din_stat_o                 : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      din_flt_o                  : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      pwm_stat_o                 : OUT STD_LOGIC;
      pwm_flt_o                  : OUT STD_LOGIC;
      anal_stat_o                : OUT STD_LOGIC;
      anal_flt_o                 : OUT STD_LOGIC;
      -- RAW selftest fault
      fault_ch1_o                : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      fault_ch2_o                : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      -- Individual PWM fault
      pwm0_flt_o                 : OUT STD_LOGIC;
      pwm1_flt_o                 : OUT STD_LOGIC;

      pwr_brk_dmnd_o             : OUT STD_LOGIC;        -- Movement of MC changing ±5.0% the braking demand or 
                                                         --          ±5.0% the power demand (req 38 and req 39)
      mc_no_pwr_o                : OUT STD_LOGIC;        -- MC = No Power

      spd_urng_o                 : OUT STD_LOGIC;        -- Analog Speed Under-Range reading
      spd_orng_o                 : OUT STD_LOGIC;        -- Analog Speed Over-Range reading

      -- Power Supply Fault
      ps1_fail_o                 : OUT STD_LOGIC;
      ps2_fail_o                 : OUT STD_LOGIC;

      -- Fault Monitor
      zero_spd_flt_o             : OUT STD_LOGIC;
      fault_o                    : OUT STD_LOGIC
   );
   END COMPONENT input_if;

   -- VCU Timing System HLB
   COMPONENT vcu_timing_system IS
   PORT (

      ----------------------------------------------------------------------------
      --  Generic ports
      ----------------------------------------------------------------------------
      arst_i               : IN STD_LOGIC;      -- Global (asynch) reset
      clk_i                : IN STD_LOGIC;      -- Global clk

      ----------------------------------------------------------------------------
      --  Timing
      ----------------------------------------------------------------------------
      pulse500ms_i         : IN STD_LOGIC;      -- Internal 500ms synch pulse
      pulse500us_i         : IN STD_LOGIC;      -- Internal 500ms synch pulse

      ----------------------------------------------------------------------------
      --  Raw Inputs
      ----------------------------------------------------------------------------
      bcp_75_i             : IN STD_LOGIC;      -- Brake Cylinder Pressure above 75% (external input)
      cab_act_i            : IN STD_LOGIC;      -- Cab Active (external input)
      hcs_mode_i           : IN STD_LOGIC;      -- Communication-based train control (sets VCU in depressed mode)
      zero_spd_i           : IN STD_LOGIC;      -- Zero Speed (external input)
      driverless_i         : IN STD_LOGIC;      -- Driverless (external input)

      vigi_pb_raw_i        : IN STD_LOGIC;      -- Vigilance Push Button raw.
      horn_low_raw_i       : IN STD_LOGIC;      -- Horn Low raw
      horn_high_raw_i      : IN STD_LOGIC;       -- Horn High raw
      ----------------------------------------------------------------------------
      --  TLA Inputs
      ----------------------------------------------------------------------------
      horn_low_i           : IN STD_LOGIC;      -- Horn Low
      horn_high_i          : IN STD_LOGIC;      -- Horn High

      hl_low_i             : IN STD_LOGIC;      -- Headlight Low
      w_wiper_pb_i         : IN STD_LOGIC;      -- Washer Wiper Push Button
      ss_bypass_pb_i       : IN STD_LOGIC;      -- Safety system bypass Push Button

      ----------------------------------------------------------------------------
      --  Acknowledge Inputs
      ----------------------------------------------------------------------------
      vigi_pb_i            : IN STD_LOGIC;      -- Vigilance Push Button
      vigi_pb_hld_i        : IN STD_LOGIC;      -- Vigilance Push Button Held (internal)

      ----------------------------------------------------------------------------
      --  PWM Processed Inputs
      ----------------------------------------------------------------------------
      pwr_brk_dmnd_i       : IN STD_LOGIC;      -- Movement of MC changing ±5.0% the braking demand or 
                                                --                  ±5.0% the power demand (req 38 and req 39)
      mc_no_pwr_i          : IN STD_LOGIC;      -- MC = No Power

      ----------------------------------------------------------------------------
      --  Analog Inputs (Speed)
      ----------------------------------------------------------------------------
      spd_l3kmh_i          : IN STD_LOGIC;      -- 4-20mA Speed Indicating < 3km/h
      spd_h3kmh_i          : IN STD_LOGIC;      -- 4-20mA Speed Indicating > 3km/h
      spd_h23kmh_i         : IN STD_LOGIC;      -- 4-20mA Speed Indicating > 23km/h
      spd_h25kmh_i         : IN STD_LOGIC;      -- 4-20mA Speed Indicating > 25km/h
      spd_h75kmh_i         : IN STD_LOGIC;      -- 4-20mA Speed Indicating > 75km/h
      spd_h90kmh_i         : IN STD_LOGIC;      -- 4-20mA Speed Indicating > 90km/h
      spd_h110kmh_i        : IN STD_LOGIC;      -- 4-20mA Speed Indicating > 100km/h
      spd_over_spd_i       : IN STD_LOGIC;      -- 4-20mA Speed Indicating Speed Overrange

      ----------------------------------------------------------------------------
      --  Processed (Fault) Inputs
      ----------------------------------------------------------------------------
      mjr_flt_i            : IN STD_LOGIC;      -- Major Fault
      spd_err_i            : IN STD_LOGIC;      -- Analog Speed Error (OPL ID#40)
      zero_spd_flt_i       : IN STD_LOGIC;      -- Digital zero speed fault, processed from external input

      ----------------------------------------------------------------------------
      --  Outputs
      ----------------------------------------------------------------------------
      vis_warn_stat_o      : OUT STD_LOGIC;     -- Visible Warning Status
      light_out_o          : OUT STD_LOGIC;     -- Flashing Light (1st Stage Warning)
      buzzer_o             : OUT STD_LOGIC;     -- Buzzer Output (2nd Stage Warning)
      penalty1_out_o       : OUT STD_LOGIC;     -- Penalty Brake 1
      penalty2_out_o       : OUT STD_LOGIC;     -- Penalty Brake 2
      rly_out1_3V_o        : OUT STD_LOGIC;     -- Radio Warning
      vcu_rst_o            : OUT STD_LOGIC;     -- VCU RST (for TMS)

      st_1st_wrn_o         : OUT STD_LOGIC;     -- Notify VCU 1st Warning
      st_2st_wrn_o         : OUT STD_LOGIC;     -- Notify VCU 2st Warning
      zero_spd_o           : OUT STD_LOGIC;     -- Notify Zero Speed Calc
      spd_lim_exceed_tst_o : OUT STD_LOGIC;     -- Notify VCU Speed Limit state (Test)

      opmode_mft_o         : OUT STD_LOGIC;     -- Notify Major Fault opmode
      opmode_tst_o         : OUT STD_LOGIC;     -- Notify Test opmode

      opmode_dep_o         : OUT STD_LOGIC;     -- Notify Depression opmode
      opmode_sup_o         : OUT STD_LOGIC;     -- Notify Suppression opmode
      opmode_nrm_o         : OUT STD_LOGIC      -- Notify Normal opmode
   );
   END COMPONENT vcu_timing_system;

   -- External Status IF
   COMPONENT led_if IS
   PORT (
      arst_i               : IN  STD_LOGIC;
      clk_i                : IN  STD_LOGIC;

      pulse_i              : IN  STD_LOGIC;           -- Pulse tick

      din_stat_i           : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
      din_flt_i            : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
      pwm_stat_i           : IN STD_LOGIC;
      pwm_flt_i            : IN STD_LOGIC;
      anal_stat_i          : IN STD_LOGIC;
      anal_flt_i           : IN STD_LOGIC;
      dout_stat_i          : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      dout_flt_i           : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      buz_stat_i           : IN STD_LOGIC;
      buz_flt_i            : IN STD_LOGIC;
      pb1_stat_i           : IN STD_LOGIC;
      pb1_flt_i            : IN STD_LOGIC;
      pb2_stat_i           : IN STD_LOGIC;
      pb2_flt_i            : IN STD_LOGIC;
      tcr_flt_i            : IN STD_LOGIC;
      rly_stat_i           : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      rly_flt_i            : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      mode_nrm_i           : IN STD_LOGIC;
      mode_sup_i           : IN STD_LOGIC;
      mode_dep_i           : IN STD_LOGIC;


      disp_clk_o           : OUT STD_LOGIC;
      disp_data_o          : OUT STD_LOGIC;
      disp_strobe_o        : OUT STD_LOGIC;
      disp_oe_o            : OUT STD_LOGIC
   );

   END COMPONENT led_if;

   -- Input Clock Monitor
   COMPONENT clk_monitor IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Generic ports
      ----------------------------------------------------------------------------
      arst_i               : IN STD_LOGIC;      -- Global (asynch) reset
      clk_i                : IN STD_LOGIC;      -- Global clk

      ----------------------------------------------------------------------------
      --  Timing
      ----------------------------------------------------------------------------
      pulse500us_i         : IN STD_LOGIC;   -- Internal 500ms synch pulse

      ----------------------------------------------------------------------------
      --  Outputs
      ----------------------------------------------------------------------------
      penalty1_wd_o        : OUT STD_LOGIC;
      penalty2_wd_o        : OUT STD_LOGIC

   );
   END COMPONENT clk_monitor;

   -- Output IF
   COMPONENT output_if IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Generic ports
      ----------------------------------------------------------------------------
      arst_i                  : IN STD_LOGIC;   -- Global (asynch) reset
      clk_i                   : IN STD_LOGIC;   -- Global clk

      ----------------------------------------------------------------------------
      --  Timing
      ----------------------------------------------------------------------------
      pulse500us_i            : IN STD_LOGIC;   -- Internal 500us synch pulse
      pulse250ms_i            : IN STD_LOGIC;   -- Internal 250ms synch pulse
      ----------------------------------------------------------------------------
      --  Digital (Wet) Outputs
      ----------------------------------------------------------------------------
      light_out_i             : IN STD_LOGIC;   -- Warning Light

      tms_pb_i                : IN STD_LOGIC;   -- TMS Vigilance Push Button
      tms_spd_lim_overridden_i: IN STD_LOGIC;   -- TMS Speed Limit Override
      tms_rst_i               : IN STD_LOGIC;   -- TMS Vigilance Reset
      tms_penalty_stat_i      : IN STD_LOGIC;   -- TMS Penalty Brake Status
      tms_major_fault_i       : IN STD_LOGIC;   -- TMS Vigilance Major Fault
      tms_minor_fault_i       : IN STD_LOGIC;   -- TMS Vigilance Minor Fault
      tms_depressed_i         : IN STD_LOGIC;   -- TMS Vigilance Depressed Mode
      tms_suppressed_i        : IN STD_LOGIC;   -- TMS Vigilance Suppressed Mode
      tms_vis_warn_stat_i     : IN STD_LOGIC;   -- TMS Visible Warning Status
      tms_spd_lim_stat_i      : IN STD_LOGIC;   -- TMS Speed Limit Status

      buzzer_out_i            : IN STD_LOGIC;   -- Warning Buzzer

      ----------------------------------------------------------------------------
      --  Digital (Wet) Output Feedback In
      ----------------------------------------------------------------------------
      light_out_fb_i          : IN STD_LOGIC;   -- Warning Light Signal Feedback

      tms_pb_fb_i             : IN STD_LOGIC;   -- TMS Vigilance Push Button Signal Feedback
      tms_spd_lim_overridden_fb_i: IN STD_LOGIC;-- TMS Speed Limit Overridden Signal Feedback
      tms_rst_fb_i            : IN STD_LOGIC;   -- TMS Vigilance Reset Signal Feedback
      tms_penalty_stat_fb_i   : IN STD_LOGIC;   -- TMS Penalty Brake Status Signal Feedback
      tms_major_fault_fb_i    : IN STD_LOGIC;   -- TMS Vigilance Major Fault Signal Feedback
      tms_minor_fault_fb_i    : IN STD_LOGIC;   -- TMS Vigilance Minor Fault Signal Feedback
      tms_depressed_fb_i      : IN STD_LOGIC;   -- TMS Vigilance Depressed Mode Signal Feedback
      tms_suppressed_fb_i     : IN STD_LOGIC;   -- TMS Vigilance Suppressed Mode Signal Feedback
      tms_vis_warn_stat_fb_i  : IN STD_LOGIC;   -- TMS Visible Warning Status Output Feedback
      tms_spd_lim_stat_fb_i   : IN STD_LOGIC;   -- TMS Speed Limit Status Signal Feedback

      buzzer_out_fb_i         : IN STD_LOGIC;   -- Warning Buzzer Signal Feedback

      ----------------------------------------------------------------------------
      --  Relay (Dry) Outputs
      ----------------------------------------------------------------------------

      penalty1_out_i          : IN STD_LOGIC;   -- Penalty Brake Channel #1 Output
      penalty2_out_i          : IN STD_LOGIC;   -- Penalty Brake Channel #2 Output

      rly_out3_3V_i           : IN STD_LOGIC;   -- Speed Limit Exceeded 2
      rly_out2_3V_i           : IN STD_LOGIC;   -- Speed Limit Exceeded 1
      rly_out1_3V_i           : IN STD_LOGIC;   -- Radio Warning Relay

      ----------------------------------------------------------------------------
      --  Relay (Dry) Output Feedback In
      ----------------------------------------------------------------------------
      penalty2_fb_i           : IN STD_LOGIC;   -- Penalty Brake Channel #2 Signal Feedback Input
      penalty1_fb_i           : IN STD_LOGIC;   -- Penalty Brake Channel #1 Signal Feedback Input

      rly_fb3_3V_i            : IN STD_LOGIC;   -- Relay 3 Feedback
      rly_fb2_3V_i            : IN STD_LOGIC;   -- Relay 2 Feedback
      rly_fb1_3V_i            : IN STD_LOGIC;   -- Relay 1 Feedback

      ----------------------------------------------------------------------------
      --  Digital (Wet) Outputs
      ----------------------------------------------------------------------------
      wet_o                   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      wet_flt_o               : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);

      ----------------------------------------------------------------------------
      --  Relay (Dry) Outputs
      ----------------------------------------------------------------------------
      dry_o                   : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
      dry_flt_o               : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);

      ----------------------------------------------------------------------------
      --  Status LED output
      ----------------------------------------------------------------------------
      status_led_o            : OUT STD_LOGIC

   );
   END COMPONENT output_if;

   -- Diagnostics IF
   COMPONENT diag_if IS
   PORT (
      arst_i                  : IN  STD_LOGIC;
      clk_i                   : IN  STD_LOGIC;

      pulse_i                 : IN  STD_LOGIC;  -- Pulse tick

      ps1_fail_i              : IN STD_LOGIC;
      ps2_fail_i              : IN STD_LOGIC;
      ch1_st_fail_i           : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
      ch2_st_fail_i           : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
      pwm0_fail_i             : IN STD_LOGIC;
      pwm1_fail_i             : IN STD_LOGIC;
      anal_under_fail_i       : IN STD_LOGIC;
      anal_over_fail_i        : IN STD_LOGIC;
      anal_fault_i            : IN STD_LOGIC;
      rly1_fault_i            : IN STD_LOGIC;
      rly2_fault_i            : IN STD_LOGIC;
      rly3_fault_i            : IN STD_LOGIC;
      pen1_fault_i            : IN STD_LOGIC;
      pen2_fault_i            : IN STD_LOGIC;
      digout_fault_i          : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      buzzer_fault_i          : IN STD_LOGIC;

      opmode_nrm_i            : IN STD_LOGIC;   -- VCU in Normal Mode

      opmode_sup_i            : IN STD_LOGIC;   -- VCU in Suppressed Mode
      opmode_dep_i            : IN STD_LOGIC;   -- VCU in Depressed Mode
      opmode_tst_i            : IN STD_LOGIC;   -- VCU in Test Mode
      opmode_mft_i            : IN STD_LOGIC;   -- VCU in Major Fault Mode
      vcu_rst_i               : IN STD_LOGIC;   -- VCU reset occurred
      st_1st_wrn_i            : IN STD_LOGIC;   -- Entered First Stage Warning
      st_2st_wrn_i            : IN STD_LOGIC;   -- Entered Second Stage Warning
      penalty1_out_i          : IN STD_LOGIC;   -- Penalty Brake 1 Applied
      penalty2_out_i          : IN STD_LOGIC;   -- Penalty Brake 2 Applied
      rly_out1_3V_i           : IN STD_LOGIC;   -- Radio Alarm Requested
      zero_spd_i              : IN STD_LOGIC;   -- Train at zero speed (Internal logic, not raw digital input state)
      light_out_i             : IN STD_LOGIC;   -- Visible Warning Light On
      buzzer_out_i            : IN STD_LOGIC;   -- Buzzer On

      diag_clk_o              : OUT STD_LOGIC;
      diag_data_o             : OUT STD_LOGIC;
      diag_strobe_o           : OUT STD_LOGIC
   );

   END COMPONENT diag_if;

   -- Major Fault
   COMPONENT major_flt IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Generic ports
      ----------------------------------------------------------------------------
      arst_i                  : IN STD_LOGIC;   -- Global (asynch) reset
      clk_i                   : IN STD_LOGIC;   -- Global clk

      ----------------------------------------------------------------------------
      --  Fault Conditions
      ----------------------------------------------------------------------------
      penalty1_flt_i          : IN STD_LOGIC;   -- Penalty Brake 1 Fault
      penalty2_flt_i          : IN STD_LOGIC;   -- Penalty Brake 2 Fault

      ----------------------------------------------------------------------------
      --  Major Fault Output
      ----------------------------------------------------------------------------
      mjr_flt_o               : OUT STD_LOGIC   -- Major Fault Out

   );
   END COMPONENT major_flt;

   -- Minor Fault
   COMPONENT minor_flt IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Generic ports
      ----------------------------------------------------------------------------
      arst_i                  : IN STD_LOGIC;                           -- Global (asynch) reset
      clk_i                   : IN STD_LOGIC;                           -- Global clk

      ----------------------------------------------------------------------------
      --  Fault Inputs
      ----------------------------------------------------------------------------
      input_flt_i             : IN STD_LOGIC;                        -- Input IF Fault
      spd_urng_i              : IN STD_LOGIC;                        -- Analog Speed Under-Range Fault
      spd_orng_i              : IN STD_LOGIC;                        -- Analog Speed Over-Range Fault
      spd_err_i               : IN STD_LOGIC;                        -- Analog Speed value error
      dry_flt_i               : IN STD_LOGIC_VECTOR( 4 DOWNTO 0);    -- Fault on dry outputs
      wet_flt_i               : IN STD_LOGIC_VECTOR(11 DOWNTO 0);    -- Fault on dry outputs

      ----------------------------------------------------------------------------
      --  Minor Fault Output
      ----------------------------------------------------------------------------
      mnr_flt_o               : OUT STD_LOGIC                        -- Minor Fault Out

   );
   END COMPONENT minor_flt;

   -- TMS IF
   COMPONENT tms_if IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Clock/Reset Inputs
      ----------------------------------------------------------------------------
      arst_i                  : IN STD_LOGIC;                        -- Global (asynch) reset
      clk_i                   : IN STD_LOGIC;                        -- Global clk

      ----------------------------------------------------------------------------
      --  Push Button Inputs
      ----------------------------------------------------------------------------
      vigi_pb_i               : IN STD_LOGIC;                        -- VPB post-filtering
      spd_lim_overridden_i    : IN STD_LOGIC;                        -- Speed Limit Override post-filtering

      ----------------------------------------------------------------------------
      --  Penalty Brake Actuation Inputs
      ----------------------------------------------------------------------------
      penalty1_out_i          : IN STD_LOGIC;                        -- Penalty Brake 1 Actuation dry 4
      penalty2_out_i          : IN STD_LOGIC;                        -- Penalty Brake 2 Actuation dry 4

      ----------------------------------------------------------------------------
      --  Fault Inputs
      ----------------------------------------------------------------------------
      mjr_flt_i               : IN STD_LOGIC;                        -- Major Fault
      mnr_flt_i               : IN STD_LOGIC;                        -- Minor Fault

      ----------------------------------------------------------------------------
      --  Operation Modes
      ----------------------------------------------------------------------------
      opmode_dep_i            : IN STD_LOGIC;                        -- Indicates VCU in Depressed Operation Mode
      opmode_sup_i            : IN STD_LOGIC;                        -- Indicates VCU in Suppressed Operation Mode
      opmode_nrm_i            : IN STD_LOGIC;                        -- Indicates VCU in Normal Operation Mode

      ----------------------------------------------------------------------------
      --  VCU FSM Inputs
      ----------------------------------------------------------------------------
      vcu_rst_i               : IN STD_LOGIC;                       -- VCU Timing FSM Rst

      -----------------------------------------------------------------------------
      --  Speed Limit Status & Visble Light Warning Status Inputs
      ----------------------------------------------------------------------------
      spd_lim_st_i            : IN STD_LOGIC;                       -- Indicates Speed Limit Timer running
      vis_warn_stat_i         : IN STD_LOGIC;                       -- Indicates Visble Light Warning Status on
      ----------------------------------------------------------------------------
      --  TMS Outputs
      ----------------------------------------------------------------------------
      tms_pb_o                : OUT STD_LOGIC;                      -- Mirror VPB input post filtering
      tms_spd_lim_overridden_o: OUT STD_LOGIC;                      -- Mirror Speed Limit Override input post filtering
      tms_rst_o               : OUT STD_LOGIC;                      -- VCU reset, single 500mS pulse
      tms_penalty_stat_o      : OUT STD_LOGIC;                      -- Mirror penalty brake outputs.
      tms_major_fault_o       : OUT STD_LOGIC;                      -- Mirror Major Fault
      tms_minor_fault_o       : OUT STD_LOGIC;                      -- Asserted when ANY minor fault occurs.
      tms_depressed_o         : OUT STD_LOGIC;                      -- Asserted when the VCU is in depressed mode
      tms_suppressed_o        : OUT STD_LOGIC;                      -- Asserted when the VCU is in suppressed mode
      tms_normal_o            : OUT STD_LOGIC;                      -- Asserted when the VCU is in normal mode
      tms_spd_lim_stat_o      : OUT STD_LOGIC;                      -- Asserted when speed limit timer running
      tms_vis_warn_stat_o     : OUT STD_LOGIC                       -- Asserted when the Visible Warning Status is on
   );
   END COMPONENT tms_if;

   -- Speed Limiter
   COMPONENT speed_limiter IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Generic ports
      ----------------------------------------------------------------------------
      arst_i                  : IN STD_LOGIC;   -- Global (asynch) reset
      clk_i                   : IN STD_LOGIC;   -- Global clk

      ----------------------------------------------------------------------------
      --  Timing
      ----------------------------------------------------------------------------
      pulse500ms_i            : IN STD_LOGIC;   -- Internal 500ms synch pulse

      ----------------------------------------------------------------------------
      --  Speed Limit Function Request
      ----------------------------------------------------------------------------
      spd_lim_i               : IN STD_LOGIC;   -- Init Speed Limit function

      ----------------------------------------------------------------------------
      --  Speed Limit Override Function Request
      ----------------------------------------------------------------------------
      spd_lim_override_i      : IN STD_LOGIC;   -- Speed Limit Override Request Input

      ----------------------------------------------------------------------------
      --  Speed Limit Exceeded Test Request
      ----------------------------------------------------------------------------
      spd_lim_exceed_tst_i    : IN STD_LOGIC;   -- Speed Limit Exceeded Test Request

      ----------------------------------------------------------------------------
      -- VCU operation mode
      ----------------------------------------------------------------------------
      test_mode_i             : IN STD_LOGIC;   -- Test operation mode
      suppressed_mode_i       : IN STD_LOGIC;   -- Suppressed (Inactive) operation mode
      depressed_mode_i        : IN STD_LOGIC;   -- Depressed (Inhnibited) operation mode

      ----------------------------------------------------------------------------
      --  Processed (Fault) Inputs
      ----------------------------------------------------------------------------
      mjr_flt_i               : IN STD_LOGIC;   -- Major Fault

      ----------------------------------------------------------------------------
      --  Analog Inputs (Speed)
      ----------------------------------------------------------------------------
      spd_h23kmh_i            : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 25km/h
      spd_h25kmh_i            : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 25km/h
      spd_h75kmh_i            : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 75km/h
      spd_h90kmh_i            : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 90km/h
      spd_h110kmh_i           : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 100km/h
      spd_over_spd_i          : IN STD_LOGIC;   -- 4-20mA Speed Indicating Speed Overrange

      ----------------------------------------------------------------------------
      --  Zero Speed Input
      ----------------------------------------------------------------------------
      zero_spd_i              : IN STD_LOGIC;   -- Zero Speed Input

      ----------------------------------------------------------------------------
      --  Outputs
      ----------------------------------------------------------------------------
      spd_lim_overridden_o    : OUT STD_LOGIC; -- Speed Limit Overridden
      rly_out3_3V_o           : OUT STD_LOGIC;  -- Speed Limit Exceeded 2
      rly_out2_3V_o           : OUT STD_LOGIC;  -- Speed Limit Exceeded 1
      spd_lim_st_o            : OUT STD_LOGIC   -- Speed Limit Status Output

   );
   END COMPONENT speed_limiter;

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------
   -- Reset signal: synchronous de-assert
   SIGNAL arst_s                 : STD_LOGIC;

   -- Timing
   SIGNAL pulse500ms_s           : STD_LOGIC;
   SIGNAL pulse250ms_s           : STD_LOGIC;
   SIGNAL pulse500us_s           : STD_LOGIC;
   SIGNAL pulsedisp_s            : STD_LOGIC;
   SIGNAL pulsepwm_s             : STD_LOGIC;
   SIGNAL pulse15_625us_s        : STD_LOGIC;
   SIGNAL pulse78ms_s            : STD_LOGIC;

   -- Debounced Inputs
   SIGNAL vigi_pb_event_s        : STD_LOGIC;
   SIGNAL zero_spd_event_s       : STD_LOGIC;
   SIGNAL hcs_mode_event_s       : STD_LOGIC;
   SIGNAL bcp_75_event_s         : STD_LOGIC;
   SIGNAL cab_act_event_s        : STD_LOGIC;
   SIGNAL horn_low_event_s       : STD_LOGIC;
   SIGNAL horn_high_event_s      : STD_LOGIC;
   SIGNAL hl_low_event_s         : STD_LOGIC;
   SIGNAL w_wiper_pb_event_s     : STD_LOGIC;
   SIGNAL ss_bypass_pb_event_s   : STD_LOGIC;
   SIGNAL driverless_event_s     : STD_LOGIC;
   SIGNAL spd_lim_event_s        : STD_LOGIC;

   -- Input IF
   SIGNAL spd_l3kmh_s            : STD_LOGIC;
   SIGNAL spd_h3kmh_s            : STD_LOGIC;
   SIGNAL spd_h23kmh_s           : STD_LOGIC;
   SIGNAL spd_h25kmh_s           : STD_LOGIC;
   SIGNAL spd_h75kmh_s           : STD_LOGIC;
   SIGNAL spd_h90kmh_s           : STD_LOGIC;
   SIGNAL spd_h110kmh_s          : STD_LOGIC;
   SIGNAL spd_over_spd_s         : STD_LOGIC;
   SIGNAL test_low_ch1_s         : STD_LOGIC;
   SIGNAL test_low_ch2_s         : STD_LOGIC;
   SIGNAL test_high_ch1_s        : STD_LOGIC;
   SIGNAL test_high_ch2_s        : STD_LOGIC;
   SIGNAL spd_urng_s             : STD_LOGIC;
   SIGNAL spd_orng_s             : STD_LOGIC;
   SIGNAL mc_no_pwr_s            : STD_LOGIC;
   SIGNAL pwr_brk_dmnd_s         : STD_LOGIC;
   SIGNAL pwm_stat_s             : STD_LOGIC;
   SIGNAL pwm_flt_s              : STD_LOGIC;
   SIGNAL anal_stat_s            : STD_LOGIC;
   SIGNAL anal_flt_s             : STD_LOGIC;
   SIGNAL ps1_fail_s             : STD_LOGIC;
   SIGNAL ps2_fail_s             : STD_LOGIC;
   SIGNAL fault_ch1_s            : STD_LOGIC_VECTOR(17 DOWNTO 0);
   SIGNAL fault_ch2_s            : STD_LOGIC_VECTOR(17 DOWNTO 0);
   SIGNAL pwm0_flt_s             : STD_LOGIC;
   SIGNAL pwm1_flt_s             : STD_LOGIC;
   SIGNAL din_stat_s             : STD_LOGIC_VECTOR(17 DOWNTO 0);
   SIGNAL din_flt_s              : STD_LOGIC_VECTOR(17 DOWNTO 0);

   SIGNAL vigi_pb_s              : STD_LOGIC;
   SIGNAL input_flt_s            : STD_LOGIC;
   SIGNAL spd_h23kmh_b_s         : STD_LOGIC;
   SIGNAL spd_h25kmh_b_s         : STD_LOGIC;
   SIGNAL spd_lim_override_s     : STD_LOGIC;

   -- LED IF
   SIGNAL disp_clk_s             : STD_LOGIC;
   SIGNAL disp_data_s            : STD_LOGIC;
   SIGNAL disp_strobe_s          : STD_LOGIC;
   SIGNAL disp_oe_s              : STD_LOGIC;

   -- Diag IF
   SIGNAL diag_clk_s             : STD_LOGIC;
   SIGNAL diag_data_s            : STD_LOGIC;
   SIGNAL diag_strobe_s          : STD_LOGIC;

   -- Status LED
   SIGNAL status_led_s           : STD_LOGIC;

   -- VCU Timing System
   SIGNAL light_out_s            : STD_LOGIC;
   SIGNAL buzzer_out_s           : STD_LOGIC;
   SIGNAL penalty1_out_s         : STD_LOGIC;
   SIGNAL penalty2_out_s         : STD_LOGIC;
   SIGNAL rly_out3_3V_s          : STD_LOGIC;
   SIGNAL rly_out2_3V_s          : STD_LOGIC;
   SIGNAL rly_out1_3V_s          : STD_LOGIC;
   SIGNAL spd_err_s              : STD_LOGIC;
   SIGNAl zero_spd_flt_s         : STD_LOGIC;
   SIGNAL vigi_pb_hld_s          : STD_LOGIC;
   SIGNAL st_1st_wrn_s           : STD_LOGIC;
   SIGNAL st_2st_wrn_s           : STD_LOGIC;
   SIGNAL zero_spd_s             : STD_LOGIC;
   SIGNAL opmode_mft_s           : STD_LOGIC;
   SIGNAL opmode_tst_s           : STD_LOGIC;
   SIGNAL opmode_dep_s           : STD_LOGIC;
   SIGNAL opmode_sup_s           : STD_LOGIC;
   SIGNAL opmode_nrm_s           : STD_LOGIC;
   SIGNAL vis_warn_stat_s        : STD_LOGIC;
   SIGNAL vcu_rst_s              : STD_LOGIC;
   SIGNAL spd_lim_overridden_s   : STD_LOGIC;

   -- Clock Monitor
   SIGNAL penalty1_wd_s          : STD_LOGIC;
   SIGNAL penalty2_wd_s          : STD_LOGIC;

   -- Output IF
   SIGNAL wet_s                  : STD_LOGIC_VECTOR(11 DOWNTO 0);
   SIGNAL wet_flt_s              : STD_LOGIC_VECTOR(11 DOWNTO 0);
   SIGNAL dry_s                  : STD_LOGIC_VECTOR( 4 DOWNTO 0);
   SIGNAL dry_flt_s              : STD_LOGIC_VECTOR( 4 DOWNTO 0);

   -- Major Fault
   SIGNAL mjr_flt_s              : STD_LOGIC;

   -- Minor FAULT
   SIGNAL mnr_flt_s              : STD_LOGIC;

   -- TMS IF
   SIGNAL tms_pb_s               : STD_LOGIC;
   SIGNAL tms_spd_lim_overridden_s : STD_LOGIC;
   SIGNAL tms_rst_s              : STD_LOGIC;
   SIGNAL tms_penalty_stat_s     : STD_LOGIC;
   SIGNAL tms_major_fault_s      : STD_LOGIC;
   SIGNAL tms_minor_fault_s      : STD_LOGIC;
   SIGNAL tms_depressed_s        : STD_LOGIC;
   SIGNAL tms_suppressed_s       : STD_LOGIC;
   SIGNAL tms_normal_s           : STD_LOGIC;
   SIGNAL tms_spd_lim_stat_s     : STD_LOGIC;
   SIGNAL tms_vis_warn_stat_s    : STD_LOGIC;

   -- 25km/h Speed Limit
   SIGNAL spd_lim_st_s           : STD_LOGIC;
   SIGNAL spd_lim_exceed_tst_s   : STD_LOGIC;

BEGIN

   --------------------------------------------------------
   -- TIMING
   --------------------------------------------------------
   timing_i0: timing
   PORT MAP(
      aextrst_i               => arst_n_i,
      clk_i                   => clk_i,
      pulse500ms_o            => pulse500ms_s,
      pulse250ms_o            => pulse250ms_s,
      pulse500us_o            => pulse500us_s,
      pulsedisp_o             => pulsedisp_s,
      pulse15_625us_o         => pulse15_625us_s,
      pulse78ms_o             => pulse78ms_s,
      pulsepwm_o              => pulsepwm_s,
      rst_o                   => arst_s
   );

   --------------------------------------------------------
   -- HLB: INPUT INTERFACE
   --------------------------------------------------------
   input_if_i0: input_if
   PORT MAP(
      arst_i                  => arst_s,
      clk_i                   => clk_i,
      pulse500us_i            => pulse500us_s,
      pulse500ms_i            => pulse500ms_s,
      pulse15_625us_i         => pulse15_625us_s,
      pulse78ms_i             => pulse78ms_s,
      pulsepwm_i              => pulsepwm_s,

      driverless_ch1_i        => driverless_ch1_i,
      driverless_ch2_i        => driverless_ch2_i,
      spd_lim_ch1_i           => spd_lim_ch1_i,
      spd_lim_ch2_i           => spd_lim_ch2_i,
      vigi_pb_ch1_i           => vigi_pb_ch1_i,
      vigi_pb_ch2_i           => vigi_pb_ch2_i,
      spd_lim_override_ch1_i  => spd_lim_override_ch1_i,
      spd_lim_override_ch2_i  => spd_lim_override_ch2_i,
      zero_spd_ch1_i          => zero_spd_ch1_i,
      zero_spd_ch2_i          => zero_spd_ch2_i,
      hcs_mode_ch1_i          => hcs_mode_ch1_i,
      hcs_mode_ch2_i          => hcs_mode_ch2_i,
      bcp_75_ch1_i            => bcp_75_ch1_i,
      bcp_75_ch2_i            => bcp_75_ch2_i,
      not_isol_ch1_i          => not_isol_ch1_i,
      not_isol_ch2_i          => not_isol_ch2_i,
      cab_act_ch1_i           => cab_act_ch1_i,
      cab_act_ch2_i           => cab_act_ch2_i,

      horn_low_i              => horn_low_i,
      horn_high_i             => horn_high_i,

      hl_low_i                => hl_low_i,

      w_wiper_pb_i            => w_wiper_pb_i,

      ss_bypass_pb_i          => ss_bypass_pb_i,

      ps2_stat_i              => ps2_stat_i,
      ps1_stat_i              => ps1_stat_i,

      pwm_ch1_i               => pwm_ch1_i,
      pwm_ch2_i               => pwm_ch2_i,

      force_fault_ch1_i       => force_fault_ch1_i,
      force_fault_ch2_i       => force_fault_ch2_i,

      spd_l3kmh_i             => spd_l3kmh_i,
      spd_h3kmh_i             => spd_h3kmh_i,
      spd_h23kmh_a_i          => spd_h23kmh_a_i,
      spd_h23kmh_b_i          => spd_h23kmh_b_s,
      spd_h25kmh_a_i          => spd_h25kmh_a_i,
      spd_h25kmh_b_i          => spd_h25kmh_b_s,
      spd_h75kmh_i            => spd_h75kmh_i,
      spd_h90kmh_i            => spd_h90kmh_i,
      spd_h110kmh_i           => spd_h110kmh_i,
      spd_over_spd_i          => spd_over_spd_i,

      spd_l3kmh_o             => spd_l3kmh_s,
      spd_h3kmh_o             => spd_h3kmh_s,
      spd_h23kmh_o            => spd_h23kmh_s,
      spd_h25kmh_o            => spd_h25kmh_s,
      spd_h75kmh_o            => spd_h75kmh_s,
      spd_h90kmh_o            => spd_h90kmh_s,
      spd_h110kmh_o           => spd_h110kmh_s,
      spd_over_spd_o          => spd_over_spd_s,

      spd_err_o               => spd_err_s,

      test_low_ch1_o          => test_low_ch1_s,
      test_low_ch2_o          => test_low_ch2_s,

      test_high_ch1_o         => test_high_ch1_s,
      test_high_ch2_o         => test_high_ch2_s,

      vigi_pb_event_o         => vigi_pb_event_s,
      spd_lim_override_event_o=> spd_lim_override_s,

      zero_spd_event_o        => zero_spd_event_s,
      hcs_mode_event_o        => hcs_mode_event_s,
      bcp_75_event_o          => bcp_75_event_s,
      not_isol_event_o        => open,
      cab_act_event_o         => cab_act_event_s,
      horn_low_event_o        => horn_low_event_s,
      horn_high_event_o       => horn_high_event_s,
      hl_low_event_o          => hl_low_event_s,
      w_wiper_pb_event_o      => w_wiper_pb_event_s,
      ss_bypass_pb_event_o    => ss_bypass_pb_event_s,
      spd_lim_event_o         => spd_lim_event_s,
      driverless_event_o      => driverless_event_s,
      vigi_pb_hld_o           => vigi_pb_hld_s,
      spd_lim_override_hld_o  => open,

      spd_lim_override_o      => open,
      vigi_pb_o               => vigi_pb_s,

      din_stat_o              => din_stat_s,
      din_flt_o               => din_flt_s,
      pwm_stat_o              => pwm_stat_s,
      pwm_flt_o               => pwm_flt_s,
      anal_stat_o             => anal_stat_s,
      anal_flt_o              => anal_flt_s,

      fault_ch1_o             => fault_ch1_s,
      fault_ch2_o             => fault_ch2_s,
      pwm0_flt_o              => pwm0_flt_s,
      pwm1_flt_o              => pwm1_flt_s,
      pwr_brk_dmnd_o          => pwr_brk_dmnd_s,
      mc_no_pwr_o             => mc_no_pwr_s,
      spd_urng_o              => spd_urng_s,
      spd_orng_o              => spd_orng_s,
      zero_spd_flt_o          => zero_spd_flt_s,
      ps1_fail_o              => ps1_fail_s,
      ps2_fail_o              => ps2_fail_s,
      fault_o                 => input_flt_s
   );
   
   LGEN_01: IF (C_ART_TEST = FALSE) GENERATE
      spd_h23kmh_b_s             <= spd_h23kmh_b_i;                  -- Normal version: spd_h23kmh_b input used
      spd_h25kmh_b_s             <= spd_h25kmh_b_i;                  -- Normal version: spd_h25kmh_b input used 
   END GENERATE;
   
   LGEN_02: IF (C_ART_TEST = TRUE) GENERATE
      spd_h23kmh_b_s             <= spd_h23kmh_a_i;                  -- Reduced version: spd_h23kmh_b input not used
      spd_h25kmh_b_s             <= spd_h23kmh_a_i;                  -- Reduced version: spd_h25kmh_b input not used   
   END GENERATE;

   --------------------------------------------------------
   -- HLB: VCU TIMING SYSTEM
   --------------------------------------------------------
   vcu_timing_system_i0: vcu_timing_system
   PORT MAP(
      arst_i                  => arst_s,
      clk_i                   => clk_i,

      pulse500ms_i            => pulse500ms_s,
      pulse500us_i            => pulse500us_s,

      bcp_75_i                => bcp_75_event_s,
      cab_act_i               => cab_act_event_s,
      hcs_mode_i              => hcs_mode_event_s,
      zero_spd_i              => zero_spd_event_s,
      driverless_i            => driverless_event_s,

      horn_low_i              => horn_low_event_s,
      horn_high_i             => horn_high_event_s,
      hl_low_i                => hl_low_event_s,
      w_wiper_pb_i            => w_wiper_pb_event_s,
      ss_bypass_pb_i          => ss_bypass_pb_event_s,

      horn_low_raw_i          => din_stat_s(10),                                   -- tla on_off
      horn_high_raw_i         => din_stat_s(11),                                   -- tla on_off
      vigi_pb_i               => vigi_pb_event_s,
      vigi_pb_raw_i           => vigi_pb_s,                                        -- Input to test mode/tla on_off
      vigi_pb_hld_i           => vigi_pb_hld_s,

      pwr_brk_dmnd_i          => pwr_brk_dmnd_s,
      mc_no_pwr_i             => mc_no_pwr_s,

      spd_l3kmh_i             => spd_l3kmh_s,
      spd_h3kmh_i             => spd_h3kmh_s,
      spd_h23kmh_i            => spd_h23kmh_s,
      spd_h25kmh_i            => spd_h25kmh_s,
      spd_h75kmh_i            => spd_h75kmh_s,
      spd_h90kmh_i            => spd_h90kmh_s,
      spd_h110kmh_i           => spd_h110kmh_s,
      spd_over_spd_i          => spd_over_spd_s,

      mjr_flt_i               => mjr_flt_s,
      spd_err_i               => spd_err_s,                                        -- Anlg Speed Minor Fault REQ 42/43
      zero_spd_flt_i          => zero_spd_flt_s,

      light_out_o             => light_out_s,
      buzzer_o                => buzzer_out_s,
      penalty1_out_o          => penalty1_out_s,
      penalty2_out_o          => penalty2_out_s,
      rly_out1_3V_o           => rly_out1_3V_s,
      vcu_rst_o               => vcu_rst_s,

      st_1st_wrn_o            => st_1st_wrn_s,
      st_2st_wrn_o            => st_2st_wrn_s,
      zero_spd_o              => zero_spd_s,
      spd_lim_exceed_tst_o    => spd_lim_exceed_tst_s,

      opmode_mft_o            => opmode_mft_s,
      opmode_tst_o            => opmode_tst_s,
      opmode_dep_o            => opmode_dep_s,
      opmode_sup_o            => opmode_sup_s,
      opmode_nrm_o            => opmode_nrm_s,
      vis_warn_stat_o         => vis_warn_stat_s                                  -- REQ 197
   );

   --------------------------------------------------------
   -- HLB: EXTERNAL STATUS INTERFACE
   --------------------------------------------------------
   led_if_i0: led_if    -- REQ: 74
   PORT MAP(
      arst_i                  => arst_s,
      clk_i                   => clk_i,
      pulse_i                 => pulsedisp_s,

      din_stat_i              => din_stat_s,
      din_flt_i               => din_flt_s,
      pwm_stat_i              => pwm_stat_s,
      pwm_flt_i               => pwm_flt_s,
      anal_stat_i             => anal_stat_s,
      anal_flt_i              => anal_flt_s,
      dout_stat_i             => wet_s,
      dout_flt_i              => wet_flt_s,

      buz_stat_i              => buzzer_out_s,
      buz_flt_i               => wet_flt_s(0),
      pb1_stat_i              => dry_s(4),
      pb1_flt_i               => dry_flt_s(4),
      pb2_stat_i              => dry_s(3),
      pb2_flt_i               => dry_flt_s(3),
      tcr_flt_i               => '0', --                     -- No fault for TCR
      rly_stat_i              => dry_s(2 DOWNTO 0),
      rly_flt_i               => dry_flt_s(2 DOWNTO 0),
      mode_nrm_i              => tms_normal_s,
      mode_sup_i              => tms_suppressed_s,
      mode_dep_i              => tms_depressed_s,

      disp_clk_o              => disp_clk_s,
      disp_data_o             => disp_data_s,
      disp_strobe_o           => disp_strobe_s,
      disp_oe_o               => disp_oe_s

   );

   diag_if_i0: diag_if
   PORT MAP (
      arst_i                  => arst_s,
      clk_i                   => clk_i,

      pulse_i                 => pulsedisp_s,

      ps1_fail_i              => ps1_fail_s,
      ps2_fail_i              => ps2_fail_s,
      ch1_st_fail_i           => fault_ch1_s,
      ch2_st_fail_i           => fault_ch2_s,
      pwm0_fail_i             => pwm0_flt_s,
      pwm1_fail_i             => pwm1_flt_s,
      anal_under_fail_i       => spd_urng_s,
      anal_over_fail_i        => spd_orng_s,
      anal_fault_i            => spd_err_s,
      rly1_fault_i            => dry_flt_s(0),
      rly2_fault_i            => dry_flt_s(1),
      rly3_fault_i            => dry_flt_s(2),
      pen1_fault_i            => dry_flt_s(4),
      pen2_fault_i            => dry_flt_s(3),
      digout_fault_i          => wet_flt_s,
      buzzer_fault_i          => wet_flt_s(0),

      opmode_nrm_i            => opmode_nrm_s,

      opmode_sup_i            => opmode_sup_s,
      opmode_dep_i            => opmode_dep_s,
      opmode_tst_i            => opmode_tst_s,
      opmode_mft_i            => opmode_mft_s,
      vcu_rst_i               => vcu_rst_s,
      st_1st_wrn_i            => st_1st_wrn_s,
      st_2st_wrn_i            => st_2st_wrn_s,
      penalty1_out_i          => penalty1_out_s,
      penalty2_out_i          => penalty2_out_s,
      rly_out1_3V_i           => rly_out1_3V_s,
      zero_spd_i              => zero_spd_s,
      light_out_i             => light_out_s,
      buzzer_out_i            => buzzer_out_s,

      diag_clk_o              => diag_clk_s,
      diag_data_o             => diag_data_s,
      diag_strobe_o           => diag_strobe_s

   );

   -- TMS IF
   tms_if_i0: tms_if
   PORT MAP(
      arst_i                  => arst_s,
      clk_i                   => clk_i,

      vigi_pb_i               => vigi_pb_s,
      spd_lim_overridden_i    => spd_lim_overridden_s,

      penalty1_out_i          => penalty1_out_s,
      penalty2_out_i          => penalty2_out_s,

      mjr_flt_i               => mjr_flt_s,
      mnr_flt_i               => mnr_flt_s,

      opmode_dep_i            => opmode_dep_s,
      opmode_sup_i            => opmode_sup_s,
      opmode_nrm_i            => opmode_nrm_s,

      vcu_rst_i               => vcu_rst_s,

      spd_lim_st_i            => spd_lim_st_s,
      vis_warn_stat_i         => vis_warn_stat_s,

      tms_pb_o                => tms_pb_s,
      tms_spd_lim_overridden_o=> tms_spd_lim_overridden_s,
      tms_rst_o               => tms_rst_s,
      tms_penalty_stat_o      => tms_penalty_stat_s,
      tms_major_fault_o       => tms_major_fault_s,
      tms_minor_fault_o       => tms_minor_fault_s,
      tms_depressed_o         => tms_depressed_s,
      tms_suppressed_o        => tms_suppressed_s,
      tms_normal_o            => tms_normal_s,
      tms_spd_lim_stat_o      => tms_spd_lim_stat_s,                  --REQ: 199
      tms_vis_warn_stat_o     => tms_vis_warn_stat_s                  --REQ: 197
   );

   --------------------------------------------------------
   -- HLB: 25KM/H SPEED LIMIT
   --------------------------------------------------------
   speed_limiter_i0: speed_limiter
   PORT MAP(
      arst_i                  => arst_s,
      clk_i                   => clk_i,

      pulse500ms_i            => pulse500ms_s,

      spd_lim_i               => spd_lim_event_s,

      mjr_flt_i               => mjr_flt_s,

      spd_lim_override_i      => spd_lim_override_s,

      spd_lim_exceed_tst_i    => spd_lim_exceed_tst_s,

      test_mode_i             => opmode_tst_s,                        -- Test operation mode
      suppressed_mode_i       => opmode_sup_s,                        -- Suppressed (Inactive) operation mode
      depressed_mode_i        => opmode_dep_s,                        -- Inhibited and depressed mode are equivalent

      spd_h23kmh_i            => spd_h23kmh_s,
      spd_h25kmh_i            => spd_h25kmh_s,
      spd_h75kmh_i            => spd_h75kmh_s,
      spd_h90kmh_i            => spd_h90kmh_s,
      spd_h110kmh_i           => spd_h110kmh_s,
      spd_over_spd_i          => spd_over_spd_s,

      zero_spd_i              => zero_spd_event_s,                    --REQ: 91

      spd_lim_overridden_o    => spd_lim_overridden_s,
      rly_out3_3V_o           => rly_out3_3V_s,
      rly_out2_3V_o           => rly_out2_3V_s,
      spd_lim_st_o            => spd_lim_st_s                         --REQ: 199
   );

   --------------------------------------------------------
   -- HLB: CLOCK MONITOR
   --------------------------------------------------------
   clk_monitor_i0: clk_monitor
   PORT MAP
   (
      arst_i                  => arst_s,
      clk_i                   => clk_i,

      pulse500us_i            => pulse500us_s,

      penalty1_wd_o           => penalty1_wd_s,
      penalty2_wd_o           => penalty2_wd_s
   );

   --------------------------------------------------------
   -- HLB: OUTPUT INTERFACE
   --------------------------------------------------------
   output_if_i0: output_if
   PORT MAP
   (
      arst_i                  => arst_s,
      clk_i                   => clk_i,

      pulse500us_i            => pulse500us_s,
      pulse250ms_i            => pulse250ms_s,

      light_out_i             => light_out_s,

      tms_pb_i                => tms_pb_s,
      tms_spd_lim_overridden_i=> tms_spd_lim_overridden_s,
      tms_rst_i               => tms_rst_s,
      tms_penalty_stat_i      => tms_penalty_stat_s,
      tms_major_fault_i       => tms_major_fault_s,
      tms_minor_fault_i       => tms_minor_fault_s,
      tms_depressed_i         => tms_depressed_s,
      tms_suppressed_i        => tms_suppressed_s,
      tms_vis_warn_stat_i     => tms_vis_warn_stat_s,             -- REQ: 197
      tms_spd_lim_stat_i      => tms_spd_lim_stat_s,              -- REQ: 199

      buzzer_out_i            => buzzer_out_s,

      light_out_fb_i          => light_out_fb_i,

      tms_pb_fb_i             => tms_pb_fb_i,
      tms_spd_lim_overridden_fb_i => tms_spd_lim_overridden_fb_i,
      tms_rst_fb_i            => tms_rst_fb_i,
      tms_penalty_stat_fb_i   => tms_penalty_stat_fb_i,
      tms_major_fault_fb_i    => tms_major_fault_fb_i,
      tms_minor_fault_fb_i    => tms_minor_fault_fb_i,
      tms_depressed_fb_i      => tms_depressed_fb_i,
      tms_suppressed_fb_i     => tms_suppressed_fb_i,
      tms_vis_warn_stat_fb_i  => tms_vis_warn_stat_fb_i,           -- REQ: 197
      tms_spd_lim_stat_fb_i   => tms_spd_lim_stat_fb_i,            -- REQ: 199

      buzzer_out_fb_i         => buzzer_out_fb_i,

      penalty1_out_i          => penalty1_out_s,
      penalty2_out_i          => penalty2_out_s,

      rly_out3_3V_i           => rly_out3_3V_s,
      rly_out2_3V_i           => rly_out2_3V_s,
      rly_out1_3V_i           => rly_out1_3V_s,

      penalty2_fb_i           => penalty2_fb_i,
      penalty1_fb_i           => penalty1_fb_i,

      rly_fb3_3V_i            => rly_fb3_3V_i,
      rly_fb2_3V_i            => rly_fb2_3V_i,
      rly_fb1_3V_i            => rly_fb1_3V_i,

      wet_o                   => wet_s,
      wet_flt_o               => wet_flt_s,

      dry_o                   => dry_s,
      dry_flt_o               => dry_flt_s,

      status_led_o            => status_led_s

   );

   --------------------------------------------------------
   -- HLB: FAULT CALC
   --------------------------------------------------------
   -- Major Fault
   major_flt_i0: major_flt
   PORT MAP
   (
      arst_i                  => arst_s,
      clk_i                   => clk_i,

      penalty1_flt_i          => dry_flt_s(4),
      penalty2_flt_i          => dry_flt_s(3),

      mjr_flt_o               => mjr_flt_s

   );

   -- Minor Fault
   minor_flt_i0: minor_flt
   PORT MAP
   (

      arst_i                  => arst_s,
      clk_i                   => clk_i,

      input_flt_i             => input_flt_s,
      spd_urng_i              => spd_urng_s,
      spd_orng_i              => spd_orng_s,
      spd_err_i               => spd_err_s,
      dry_flt_i               => dry_flt_s,
      wet_flt_i               => wet_flt_s,

      mnr_flt_o               => mnr_flt_s

   );

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------
   -- Digital (Wet) Outputs

   tms_spd_lim_stat_o         <= wet_s(11);      -- REQ: 199
   light_out_o                <= wet_s(10);

   tms_pb_o                   <= wet_s(9);
   tms_spd_lim_overridden_o   <= wet_s(8);
   tms_rst_o                  <= wet_s(7);
   tms_penalty_stat_o         <= wet_s(6);
   tms_major_fault_o          <= wet_s(5);
   tms_minor_fault_o          <= wet_s(4);
   tms_depressed_o            <= wet_s(3);
   tms_suppressed_o           <= wet_s(2);
   tms_vis_warn_stat_o        <= wet_s(1);       -- REQ: 197

   buzzer_out_o               <= wet_s(0);

   -- Relay (Dry) Outputs
   penalty1_out_o             <= dry_s(4);
   penalty2_out_o             <= dry_s(3);

   rly_out3_3V_o              <= dry_s(2);
   rly_out2_3V_o              <= dry_s(1);
   rly_out1_3V_o              <= dry_s(0);

   -- Penalty Watchdogs
   penalty1_wd_o              <= penalty1_wd_s;
   penalty2_wd_o              <= penalty2_wd_s;

   -- Diag Interface
   diag_clk_o                 <= diag_clk_s;
   diag_data_o                <= diag_data_s;
   diag_strobe_o              <= diag_strobe_s;

   -- LED Display
   disp_clk_o                 <= disp_clk_s;
   disp_data_o                <= disp_data_s;
   disp_strobe_o              <= disp_strobe_s;
   disp_oe_o                  <= disp_oe_s;
   disp_major_fault_o         <= mjr_flt_s;
   disp_minor_fault_o         <= mnr_flt_s;

   -- Status Led
   status_led_o               <= '0' WHEN status_led_s = '1' ELSE
                                 'Z';                                                             -- Open-drain

   -- Test Mode
   test_low_ch1_o             <= test_low_ch1_s;
   test_low_ch2_o             <= test_low_ch2_s;

   test_high_ch1_o            <= test_high_ch1_s;
   test_high_ch2_o            <= test_high_ch2_s;

END ARCHITECTURE str;
