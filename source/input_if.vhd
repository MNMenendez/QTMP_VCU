---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : input_if.vhd
-- Module      : input_if
-- Revision    : 1.7
-- Date/Time   : May 31, 2021
-- Author      : Alvaro Lopes, Ana Fernandes, NRibeiro
---------------------------------------------------------------
-- Description : Input Interface HDL
---------------------------------------------------------------
-- History :
-- Revision 1.7 - May 31, 2021
--    - NRibeiro: [CCN05/CCN06] Applied code review comments.
-- Revision 1.6 - April 14, 2021
--    - NRibeiro: [CCN05] Added Generic for error_counter_filter module in order to differentiate
--                REQ 202 vs REQ 201 about the maximum error counter value.
-- Revision 1.5 - January 30, 2020
--    - NRibeiro: Fixing traceability requirements
-- Revision 1.4 - December 11, 2019
--    - NRibeiro: Code/Comments cleanup.
-- Revision 1.3 - November 29, 2019
--    - NRibeiro: Applied CCN04 code changes
-- Revision 1.2 - June 14, 2019
--    - AFernandes: Applied CCN03 code changes
-- Revision 1.1 - March 08, 2018
--    - ALopes: Rework according to review
-- Revision 1.0 - January 10, 2018
--    - ALopes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.STD_LOGIC_MISC.ALL;

ENTITY input_if IS
   PORT (
      -- Clock and reset
      arst_i                  : IN STD_LOGIC;
      clk_i                   : IN STD_LOGIC;
      -- Tick pulses from timing system
      pulse500us_i            : IN STD_LOGIC;
      pulse15_625us_i         : IN STD_LOGIC;
      pulse500ms_i            : IN STD_LOGIC;
      pulse78ms_i             : IN STD_LOGIC;
      pulsepwm_i              : IN STD_LOGIC;

      -- Safety-Related Digital Inputs
      vigi_pb_ch1_i           : IN STD_LOGIC;   -- Vigilance Push Button Input Channel #1
      vigi_pb_ch2_i           : IN STD_LOGIC;   -- Vigilance Push Button Input Channel #2

      spd_lim_override_ch1_i  : IN STD_LOGIC;    -- Speed Limiter Override Input Channel #1
      spd_lim_override_ch2_i  : IN STD_LOGIC;    -- Speed Limiter Override Input Channel #2

      zero_spd_ch1_i          : IN STD_LOGIC;   -- Zero Speed Input Channel #1
      zero_spd_ch2_i          : IN STD_LOGIC;   -- Zero Speed Input Channel #2

      hcs_mode_ch1_i          : IN STD_LOGIC;   -- High Capacity Signaling  Mode Input Channel #1
      hcs_mode_ch2_i          : IN STD_LOGIC;   -- High Capacity Signaling  Mode Input Channel #2

      bcp_75_ch1_i            : IN STD_LOGIC;   -- Brake Cylinder Pressure above 75% Input Channel #1
      bcp_75_ch2_i            : IN STD_LOGIC;   -- Brake Cylinder Pressure above 75% Input Channel #2

      not_isol_ch1_i          : IN STD_LOGIC;   -- Not Isolated Input Channel #1
      not_isol_ch2_i          : IN STD_LOGIC;   -- Not Isolated Input Channel #2

      cab_act_ch1_i           : IN STD_LOGIC;   -- Cab Active Input Channel #1
      cab_act_ch2_i           : IN STD_LOGIC;   -- Cab Active Input Channel #2

      driverless_ch1_i        : IN STD_LOGIC;   -- Driverless Input Channel #1
      driverless_ch2_i        : IN STD_LOGIC;   -- Driverless Input Channel #2

      spd_lim_ch1_i           : IN STD_LOGIC;   -- Speed Limiter Input Channel #1
      spd_lim_ch2_i           : IN STD_LOGIC;   -- Speed Limiter Input Channel #2

      --  Regular Digital Inputs
      horn_low_i              : IN STD_LOGIC;   -- Horn Low
      horn_high_i             : IN STD_LOGIC;   -- Horn High

      hl_low_i                : IN STD_LOGIC;   -- Headlight Low

      w_wiper_pb_i            : IN STD_LOGIC;   -- Washer Wiper Push Button

      ss_bypass_pb_i          : IN STD_LOGIC;   -- Safety system bypass Push Button

      pwm_ch1_i               : IN STD_LOGIC;   -- Pulse Width Modulated Input Cahnnel #1
      pwm_ch2_i               : IN STD_LOGIC;   -- Pulse Width Modulated Input Cahnnel #2

      --  Analog Inputs
      spd_l3kmh_i             : IN STD_LOGIC;   -- 4-20mA Speed Indicating < 3km/h
      spd_h3kmh_i             : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 3km/h
      spd_h23kmh_a_i          : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 23km/h
      spd_h23kmh_b_i          : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 23km/h (dual counterpart)
      spd_h25kmh_a_i          : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 25km/h
      spd_h25kmh_b_i          : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 25km/h (dual counterpart)
      spd_h75kmh_i            : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 75km/h
      spd_h90kmh_i            : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 90km/h
      spd_h110kmh_i           : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 100km/h
      spd_over_spd_i          : IN STD_LOGIC;   -- 4-20mA Speed Indicating Speed Overrange

      -- Power supply status
      ps1_stat_i              : IN STD_LOGIC;   -- Power Supply #1 Status
      ps2_stat_i              : IN STD_LOGIC;   -- Power Supply #2 Status

      --  Test Inputs
      force_fault_ch1_i       : IN STD_LOGIC;
      force_fault_ch2_i       : IN STD_LOGIC;

      -- Speed output
      spd_l3kmh_o             : OUT STD_LOGIC;  -- 4-20mA Speed Indicating < 3km/h
      spd_h3kmh_o             : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 3km/h
      spd_h23kmh_o            : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 23km/h
      spd_h25kmh_o            : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 25km/h
      spd_h75kmh_o            : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 75km/h
      spd_h90kmh_o            : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 90km/h
      spd_h110kmh_o           : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 100km/h
      spd_over_spd_o          : OUT STD_LOGIC;  -- 4-20mA Speed Indicating Speed Overrange

      -- Speed error
      spd_err_o               : OUT STD_LOGIC;  -- Analog Speed Error / Minor Fault (under/over range/inconsistent 
                                                --                                            6-bit value) (OPL ID#40)

      -- Self-test control
      test_low_ch1_o          : OUT STD_LOGIC;  -- Self Test Low Channel #1 Output
      test_low_ch2_o          : OUT STD_LOGIC;  -- Self Test Low Channel #2 Output
      test_high_ch1_o         : OUT STD_LOGIC;  -- Self Test High Channel #1 Output
      test_high_ch2_o         : OUT STD_LOGIC;  -- Self Test High Channel #1 Output

      -- Event outputs
      vigi_pb_event_o         : OUT STD_LOGIC;
      spd_lim_override_event_o: OUT STD_LOGIC;
      zero_spd_event_o        : OUT STD_LOGIC;
      hcs_mode_event_o        : OUT STD_LOGIC;
      bcp_75_event_o          : OUT STD_LOGIC;
      not_isol_event_o        : OUT STD_LOGIC;
      cab_act_event_o         : OUT STD_LOGIC;
      horn_low_event_o        : OUT STD_LOGIC;
      horn_high_event_o       : OUT STD_LOGIC;
      hl_low_event_o          : OUT STD_LOGIC;
      w_wiper_pb_event_o      : OUT STD_LOGIC;
      ss_bypass_pb_event_o    : OUT STD_LOGIC;
      driverless_event_o      : OUT STD_LOGIC;
      spd_lim_event_o         : OUT STD_LOGIC;
      vigi_pb_hld_o           : OUT STD_LOGIC;
      spd_lim_override_hld_o  : OUT STD_LOGIC;

      -- Pre-event output to TMS
      spd_lim_override_o      : OUT STD_LOGIC;
      vigi_pb_o               : OUT STD_LOGIC;

      -- For LED display and uC
      din_stat_o              : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      din_flt_o               : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      pwm_stat_o              : OUT STD_LOGIC;
      pwm_flt_o               : OUT STD_LOGIC;
      anal_stat_o             : OUT STD_LOGIC;
      anal_flt_o              : OUT STD_LOGIC;
      -- RAW selftest fault
      fault_ch1_o             : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      fault_ch2_o             : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      -- Individual PWM fault
      pwm0_flt_o              : OUT STD_LOGIC;
      pwm1_flt_o              : OUT STD_LOGIC;
      -- Demand outputs
      pwr_brk_dmnd_o          : OUT STD_LOGIC;  -- Movement of MC changing ±5.0% the braking demand 
                                                --           or ±5.0% the power demand (req 38 and req 39)
      mc_no_pwr_o             : OUT STD_LOGIC;  -- MC = No Power
      -- Speed range individual errors
      spd_urng_o              : OUT STD_LOGIC;  -- Analog Speed Under-Range reading
      spd_orng_o              : OUT STD_LOGIC;  -- Analog Speed Over-Range reading
      -- Power Supply Fault
      ps1_fail_o              : OUT STD_LOGIC;
      ps2_fail_o              : OUT STD_LOGIC;
      -- Zero speed fault
      zero_spd_flt_o          : OUT STD_LOGIC;
      -- Minor fault (aggregate)
      fault_o                 : OUT STD_LOGIC
   );

END ENTITY input_if;

ARCHITECTURE beh OF input_if IS

   --------------------------------------------------------
   -- COMPONENTS
   --------------------------------------------------------

   COMPONENT debouncer IS
   GENERIC (
      G_INPUTWIDTH         : NATURAL := 18;
      G_DEBOUNCECOUNTERMAX : NATURAL := 8191
   );
   PORT (
      arst_i               : IN  STD_LOGIC;
      clk_i                : IN  STD_LOGIC;
      clken_i              : IN  STD_LOGIC;
      data_i               : IN  STD_LOGIC_VECTOR(G_INPUTWIDTH-1 DOWNTO 0);
      data_o               : OUT STD_LOGIC_VECTOR(G_INPUTWIDTH-1 DOWNTO 0);
      update_o             : OUT STD_LOGIC
   );
   END COMPONENT debouncer;

   COMPONENT input_selftest IS
   PORT (
      arst_i               : IN  STD_LOGIC;
      clk_i                : IN  STD_LOGIC;
      pulse500us_i         : IN  STD_LOGIC;
      pulse500ms_i         : IN  STD_LOGIC;
      INPUT_CH1_i          : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
      INPUT_CH2_i          : IN  STD_LOGIC_VECTOR(8 DOWNTO 0);
      force_fault_ch1_i    : IN STD_LOGIC;
      force_fault_ch2_i    : IN STD_LOGIC;

      CH1_TEST_HIGH_3V_o   : OUT STD_LOGIC;
      CH1_TEST_LOW_3V_o    : OUT STD_LOGIC;
      CH2_TEST_HIGH_3V_o   : OUT STD_LOGIC;
      CH2_TEST_LOW_3V_o    : OUT STD_LOGIC;
      selftest_in_progress_o : OUT STD_LOGIC;
      chan_selftest_done_o : OUT STD_LOGIC; -- One tick only per channel
      fault_ch1_o          : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
      fault_ch2_o          : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
      fault_o              : OUT STD_LOGIC
   );
   END COMPONENT input_selftest;

   COMPONENT input_compare IS
   PORT (
      arst_i               : IN  STD_LOGIC;
      clk_i                : IN  STD_LOGIC;

      selftest_done_i      : IN  STD_LOGIC; -- One tick per channel.
      input_ch1_i          : IN  STD_LOGIC;
      input_ch2_i          : IN  STD_LOGIC;

      st_mask_ch1_i        : IN  STD_LOGIC;
      st_mask_ch2_i        : IN  STD_LOGIC;

      input_valid_i        : IN STD_LOGIC; -- Tick

      mask_ch1_o           : OUT STD_LOGIC;
      mask_ch2_o           : OUT STD_LOGIC;

      data_o               : OUT STD_LOGIC
   );
   END COMPONENT input_compare;

   COMPONENT input_mode_rising_edge IS
   PORT (
      arst_i      : IN  STD_LOGIC;
      clk_i       : IN  STD_LOGIC;
      valid_i     : IN  STD_LOGIC;
      data_i      : IN  STD_LOGIC;
      mask1_i     : IN  STD_LOGIC;
      mask2_i     : IN  STD_LOGIC;
      data_o      : OUT STD_LOGIC
      );
   END COMPONENT input_mode_rising_edge;

   COMPONENT input_mode_rise_falling_edge IS
   GENERIC (
      MAX_COUNT:  NATURAL := 1
   );
   PORT (
      arst_i      : IN  STD_LOGIC;
      clk_i       : IN  STD_LOGIC;
      tick_i      : IN  STD_LOGIC;
      valid_i     : IN  STD_LOGIC;
      inhibit_i   : IN  STD_LOGIC;
      data_i      : IN  STD_LOGIC;
      mask1_i     : IN  STD_LOGIC;
      mask2_i     : IN  STD_LOGIC;
      expired_clr_i: IN  STD_LOGIC;
      expired_o   : OUT STD_LOGIC;
      data_o      : OUT STD_LOGIC
   );
   END COMPONENT input_mode_rise_falling_edge;

   COMPONENT input_mode_rise_or_falling_edge IS
   PORT (
      arst_i      : IN  STD_LOGIC;
      clk_i       : IN  STD_LOGIC;
      data_i      : IN  STD_LOGIC;
      valid_i     : IN  STD_LOGIC;
      mask1_i     : IN  STD_LOGIC;
      mask2_i     : IN  STD_LOGIC;
      data_o      : OUT STD_LOGIC
   );
   END COMPONENT input_mode_rise_or_falling_edge;

   COMPONENT input_latch IS
   PORT (
      arst_i      : IN  STD_LOGIC;
      clk_i       : IN  STD_LOGIC;
      data_i      : IN  STD_LOGIC;
      hold_i      : IN  STD_LOGIC;
      data_o      : OUT STD_LOGIC
   );
   END COMPONENT input_latch;

   COMPONENT analog_if IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Generic ports
      ----------------------------------------------------------------------------
      arst_i            : IN STD_LOGIC;   -- Global (asynch) reset
      clk_i             : IN STD_LOGIC;   -- Global clk

      ----------------------------------------------------------------------------
      --  Timing
      ----------------------------------------------------------------------------
      pulse500ms_i      : IN STD_LOGIC;

      ----------------------------------------------------------------------------
      -- Analog Inputs (Speed)
      ----------------------------------------------------------------------------
      spd_l3kmh_i       : IN STD_LOGIC;   -- 4-20mA Speed Indicating < 3km/h
      spd_h3kmh_i       : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 3km/h
      spd_h23kmh_a_i    : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 23km/h
      spd_h23kmh_b_i    : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 23km/h (dual counterpart)
      spd_h25kmh_a_i    : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 25km/h
      spd_h25kmh_b_i    : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 25km/h (dual counterpart)
      spd_h75kmh_i      : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 75km/h
      spd_h90kmh_i      : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 90km/h
      spd_h110kmh_i     : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 100km/h
      spd_over_spd_i    : IN STD_LOGIC;   -- 4-20mA Speed Indicating Speed Overrange

      ----------------------------------------------------------------------------
      --  Outputs
      ----------------------------------------------------------------------------
      -- Processed speed reading
      spd_l3kmh_o       : OUT STD_LOGIC;  -- 4-20mA Speed Indicating < 3km/h
      spd_h3kmh_o       : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 3km/h
      spd_h23kmh_o      : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 23km/h
      spd_h25kmh_o      : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 25km/h
      spd_h75kmh_o      : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 75km/h
      spd_h90kmh_o      : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 90km/h
      spd_h110kmh_o     : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 100km/h
      spd_over_spd_o    : OUT STD_LOGIC;  -- 4-20mA Speed Indicating Speed Overrange

      -- Faults
      spd_urng_o        : OUT STD_LOGIC;  -- Analog Speed Under-Range reading
      spd_orng_o        : OUT STD_LOGIC;  -- Analog Speed Over-Range reading
      spd_err_o         : OUT STD_LOGIC   -- Analog Speed Error / Minor Fault (under/over range/inconsistent 
                                          --                                          6-bit value) (OPL ID#40)

   );
   END COMPONENT analog_if;

   COMPONENT pwm_input IS
   PORT (
      arst_i               : IN  STD_LOGIC;
      clk_i                : IN  STD_LOGIC;
      pulse_i              : IN  STD_LOGIC;

      pwm0_i               : IN  STD_LOGIC;
      pwm1_i               : IN  STD_LOGIC;

      pwm0_duty_o          : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
      pwm0_duty_valid_o    : OUT STD_LOGIC;
      pwm1_duty_o          : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
      pwm1_duty_valid_o    : OUT STD_LOGIC;

      pwm0_fault_o         : OUT STD_LOGIC;
      pwm1_fault_o         : OUT STD_LOGIC
   );
   END COMPONENT pwm_input;

   -- Demand Phase Detect
   COMPONENT demand_phase_det IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Generic ports
      ----------------------------------------------------------------------------
      arst_i             : IN STD_LOGIC;                        -- Global (asynch) reset
      clk_i              : IN STD_LOGIC;                        -- Global clk

      ----------------------------------------------------------------------------
      --  Timing
      ----------------------------------------------------------------------------
      pulse500us_i       : IN STD_LOGIC;                        -- Internal 500us synch pulse

      ----------------------------------------------------------------------------
      --  PWM Inputs
      ----------------------------------------------------------------------------
      pwm0_duty_i        : IN STD_LOGIC_VECTOR(9 DOWNTO 0);     -- PWM DC
      pwm0_duty_valid_i  : IN STD_LOGIC;                        -- Signals valid PWM DC reading
      pwm1_duty_i        : IN STD_LOGIC_VECTOR(9 DOWNTO 0);     -- PWM DC
      pwm1_duty_valid_i  : IN STD_LOGIC;                        -- Signals valid PWM DC reading

      pwm0_fault_i       : IN STD_LOGIC;                        -- PWM0 fault
      pwm1_fault_i       : IN STD_LOGIC;                        -- PWM1 fault

      ----------------------------------------------------------------------------
      --     Fault Inhibit Input
      ----------------------------------------------------------------------------
      inhibit_fault_i    : IN STD_LOGIC;                        -- Inhibit generation of PWM faults

      ----------------------------------------------------------------------------
      --  OUTPUTS
      ----------------------------------------------------------------------------
      pwm0_fault_o       : OUT STD_LOGIC;                       -- PWM0 fault
      pwm1_fault_o       : OUT STD_LOGIC;                       -- PWM1 fault

      pwr_brk_dmnd_o     : OUT STD_LOGIC;                       -- Movement of MC changing ±5.0% the braking demand 
                                                                --       or ±5.0% the power demand (req 38 and req 39)
      mc_no_pwr_o        : OUT STD_LOGIC                        -- MC = No Power

   );
   END COMPONENT demand_phase_det;

   COMPONENT event_filt_timeout IS
   GENERIC (
      G_MAX_COUNT:  NATURAL := 20
   );
   PORT (
      arst_i            : IN  STD_LOGIC;
      clk_i             : IN  STD_LOGIC;
      timeout_tick_i    : IN  STD_LOGIC;

      event_i           : IN  STD_LOGIC;
      event_o           : OUT STD_LOGIC
   );
   END COMPONENT event_filt_timeout;

   COMPONENT error_counter_filter IS
   GENERIC(
      -- Maximum number of errors counted before an output and permanent fault is notified
      G_CNT_ERROR_MAX      : Natural := 40
   );
   PORT (
      -- Clock and reset
      arst_i               : IN  STD_LOGIC;
      clk_i                : IN  STD_LOGIC;
      -- valid input
      valid_i              : IN  STD_LOGIC;
      -- error input
      fault_i              : IN  STD_LOGIC;
      -- Permanent fault output
      fault_o              : OUT STD_LOGIC
   );
   END COMPONENT error_counter_filter;

   --------------------------------------------------------
   -- CONSTANTS
   --------------------------------------------------------

   CONSTANT C_EXTRA_DEBOUNCE_INPUTS : NATURAL   := 2;                     -- Number of extra inputs to debounce
   CONSTANT C_NUM_SAFETY_INPUTS     : NATURAL   := 9;                     -- Number of safety (dual-channel) inputs
   CONSTANT C_CHAN1_LENGTH          : NATURAL   := 14;
   CONSTANT C_CHAN2_LENGTH          : NATURAL   := 9;

   -- Total number of "normal" inputs, not counting error injection inputs
   CONSTANT C_NUM_CHECKED_INPUTS    : NATURAL   := C_CHAN1_LENGTH+C_CHAN2_LENGTH;                              -- 23
   -- Total number of inputs (including error injection)
   CONSTANT C_NUM_INPUTS            : NATURAL   := C_NUM_CHECKED_INPUTS+C_EXTRA_DEBOUNCE_INPUTS;               -- 25

   CONSTANT C_NUM_SINGLECHAN_INPUTS : NATURAL   := (C_CHAN1_LENGTH+C_CHAN2_LENGTH) - (2*C_NUM_SAFETY_INPUTS);  --  5

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------

   SIGNAL debounce_in_s             : STD_LOGIC_VECTOR(C_NUM_INPUTS-1 DOWNTO 0);
   SIGNAL debounce_out_s            : STD_LOGIC_VECTOR(C_NUM_INPUTS-1 DOWNTO 0);

   -- Latched single-channel signals
   SIGNAL latched_in_s              : STD_LOGIC_VECTOR(C_NUM_SINGLECHAN_INPUTS-1 DOWNTO 0);
   SIGNAL pre_debounce_latched_in_s : STD_LOGIC_VECTOR(C_NUM_SINGLECHAN_INPUTS-1 DOWNTO 0);     -- REQ: 200. CCN03

   SIGNAL test_ch1_s                : STD_LOGIC_VECTOR(C_CHAN1_LENGTH-1 DOWNTO 0);
   SIGNAL test_ch2_s                : STD_LOGIC_VECTOR(C_CHAN2_LENGTH-1 DOWNTO 0);

   SIGNAL fault_st_ch1_s            : STD_LOGIC_VECTOR(C_CHAN1_LENGTH-1 DOWNTO 0);
   SIGNAL fault_st_ch2_s            : STD_LOGIC_VECTOR(C_CHAN2_LENGTH-1 DOWNTO 0);

   SIGNAL fault_ch1_s               : STD_LOGIC_VECTOR(C_CHAN1_LENGTH-1 DOWNTO 0);
   SIGNAL fault_ch2_s               : STD_LOGIC_VECTOR(C_CHAN2_LENGTH-1 DOWNTO 0);

   SIGNAL input_valid_s             : STD_LOGIC;
   SIGNAL selftest_in_progress_s    : STD_LOGIC;
   SIGNAL chan_selftest_done_s      : STD_LOGIC;
   SIGNAL debounce_tick_s           : STD_LOGIC;

   SIGNAL compare_out_s             : STD_LOGIC_VECTOR(C_NUM_SAFETY_INPUTS-1 DOWNTO 0);
   SIGNAL pre_debounce_compare_out_s: STD_LOGIC_VECTOR(C_NUM_SAFETY_INPUTS-1 DOWNTO 0);        -- REQ: 200. CCN03

   SIGNAL fault_safety_s            : STD_LOGIC_VECTOR(C_NUM_SAFETY_INPUTS-1 DOWNTO 0);
   SIGNAL compare_masked_ch1_s      : STD_LOGIC_VECTOR(C_NUM_SAFETY_INPUTS-1 DOWNTO 0);
   SIGNAL compare_masked_ch2_s      : STD_LOGIC_VECTOR(C_NUM_SAFETY_INPUTS-1 DOWNTO 0);
   SIGNAL compare_fault_s           : STD_LOGIC_VECTOR(C_NUM_SAFETY_INPUTS-1 DOWNTO 0);
   SIGNAL ps1_fail_s0               : STD_LOGIC;
   SIGNAL ps2_fail_s0               : STD_LOGIC;
   SIGNAL ps1_fail_s1               : STD_LOGIC;
   SIGNAL ps2_fail_s1               : STD_LOGIC;

   -- Pre-events
   SIGNAL ss_bypass_pb_pre_event_s  : STD_LOGIC;
   SIGNAL w_wiper_pb_pre_event_s    : STD_LOGIC;
   SIGNAL hl_low_pre_event_s        : STD_LOGIC;
   SIGNAL horn_high_pre_event_s     : STD_LOGIC;
   SIGNAL horn_low_pre_event_s      : STD_LOGIC;

   -- Analog IF
   SIGNAL spd_l3kmh_s               : STD_LOGIC;
   SIGNAL spd_h3kmh_s               : STD_LOGIC;
   SIGNAL spd_h75kmh_s              : STD_LOGIC;
   SIGNAL spd_h23kmh_s              : STD_LOGIC;
   SIGNAL spd_h25kmh_s              : STD_LOGIC;
   SIGNAL spd_h90kmh_s              : STD_LOGIC;
   SIGNAL spd_h110kmh_s             : STD_LOGIC;
   SIGNAL spd_over_spd_s            : STD_LOGIC;

   SIGNAL spd_urng_s                : STD_LOGIC;
   SIGNAL spd_orng_s                : STD_LOGIC;
   SIGNAL spd_err_s                 : STD_LOGIC;
   SIGNAL pwm0_pre_fault_s          : STD_LOGIC;
   SIGNAL pwm1_pre_fault_s          : STD_LOGIC;
   SIGNAL pwm0_duty_s               : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL pwm0_duty_valid_s         : STD_LOGIC;
   SIGNAL pwm1_duty_s               : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL pwm1_duty_valid_s         : STD_LOGIC;
   SIGNAL pwm0_fault_s              : STD_LOGIC;
   SIGNAL pwm1_fault_s              : STD_LOGIC;

   SIGNAL st_fault_s                : STD_LOGIC;
   SIGNAL force_fault_ch1_s         : STD_LOGIC;
   SIGNAL force_fault_ch2_s         : STD_LOGIC;

   SIGNAL pwr_brk_dmnd_s            : STD_LOGIC;
   SIGNAL mc_no_pwr_s               : STD_LOGIC;

BEGIN

   --------------------------------------------------------
   -- INPUT AGGREGATE
   --------------------------------------------------------

   -- First 9 entries are channel 2 inputs. They are followed by channel 1 and then the fault inputs. Changed in CCN03
   debounce_in_s <=
      force_fault_ch1_i      &  --24
      force_fault_ch2_i      &  --23
      -- Ch1 (17)
      -- REQ START: 29
      driverless_ch1_i       &  --22
      spd_lim_ch1_i          &  --21
      vigi_pb_ch1_i          &  --20
      spd_lim_override_ch1_i &  --19
      zero_spd_ch1_i         &  --18
      hcs_mode_ch1_i         &  --17
      bcp_75_ch1_i           &  --16
      not_isol_ch1_i         &  --15
      cab_act_ch1_i          &  --14
      -- REQ END: 29
      -- Single channel Ch1
      horn_low_i             &  --13
      horn_high_i            &  --12
      hl_low_i               &  --11
      w_wiper_pb_i           &  --10

      ss_bypass_pb_i         &  -- 9

      -- Ch2
      driverless_ch2_i       &  -- 8
      spd_lim_ch2_i          &  -- 7
      vigi_pb_ch2_i          &  -- 6
      spd_lim_override_ch2_i &  -- 5
      zero_spd_ch2_i         &  -- 4
      hcs_mode_ch2_i         &  -- 3
      bcp_75_ch2_i           &  -- 2
      not_isol_ch2_i         &  -- 1
      cab_act_ch2_i             -- 0
   ;

   -- Inputs for self-test
   test_ch1_s              <= debounce_out_s(C_NUM_CHECKED_INPUTS-1 DOWNTO C_CHAN2_LENGTH);
   test_ch2_s              <= debounce_out_s(C_CHAN2_LENGTH-1 DOWNTO 0);

   -- Aggregate faults for safety inputs
   faultgen_g: FOR n IN 0 TO C_NUM_SAFETY_INPUTS-1 GENERATE
      fault_safety_s(n)    <= compare_masked_ch1_s(n) AND compare_masked_ch2_s(n);
      fault_ch2_s(n)       <= fault_st_ch2_s(n);
      compare_fault_s(n)   <= compare_masked_ch1_s(n) AND compare_masked_ch2_s(n);
   END GENERATE;

   -- Aggregate faults for non-safety inputs
   fault2_merge_g0: FOR n IN 0 TO C_CHAN1_LENGTH-1 GENERATE
      fault_ch1_s(n)       <= fault_st_ch1_s(n);
   END GENERATE;

   -- REQ: 20
   input_valid_s <= '0' WHEN selftest_in_progress_s='1' ELSE debounce_tick_s;

   --------------------------------------------------------
   -- DEBOUNCING
   --------------------------------------------------------

   -- REQ START: 24
   debouncer_inst_i0: debouncer
   GENERIC MAP (
      G_INPUTWIDTH          => debounce_in_s'LENGTH,
      G_DEBOUNCECOUNTERMAX  => 2  -- 15.625us pulse. 3 samples => 46.875us, one sample implicit
   )
   PORT MAP (
      clk_i       => clk_i,
      arst_i      => arst_i,
      clken_i     => pulse15_625us_i,
      data_i      => debounce_in_s,
      data_o      => debounce_out_s,
      update_o    => debounce_tick_s
   );
   -- REQ END: 24

   --------------------------------------------------------
   -- SELF-TEST
   --------------------------------------------------------

   input_selftest_i0: input_selftest                                 -- REQ: 13
   PORT MAP (
      arst_i                  => arst_i,
      clk_i                   => clk_i,
      pulse500us_i            => pulse500us_i,
      pulse500ms_i            => pulse500ms_i,
      input_ch1_i             => test_ch1_s,
      input_ch2_i             => test_ch2_s,
      ch1_test_high_3v_o      => test_high_ch1_o,
      ch1_test_low_3v_o       => test_low_ch1_o,
      ch2_test_high_3v_o      => test_high_ch2_o,
      ch2_test_low_3v_o       => test_low_ch2_o,
      selftest_in_progress_o  => selftest_in_progress_s,
      chan_selftest_done_o    => chan_selftest_done_s,
      fault_ch1_o             => fault_st_ch1_s,
      fault_ch2_o             => fault_st_ch2_s,
      force_fault_ch1_i       => force_fault_ch1_s,                  -- REQ: 176
      force_fault_ch2_i       => force_fault_ch2_s,                  -- REQ: 176
      fault_o                 => st_fault_s
   );

   input_compare_i0: FOR n IN 0 TO C_NUM_SAFETY_INPUTS-1 GENERATE
      input_compare_i: input_compare                                 -- REQ: 18_19_20_21_22
      PORT MAP (
         arst_i               => arst_i,
         clk_i                => clk_i,
         selftest_done_i      => chan_selftest_done_s,
         input_ch1_i          => debounce_out_s(n + C_CHAN1_LENGTH),  -- Chan1 starts at "index C_CHAN1_LENGTH"
         input_ch2_i          => debounce_out_s(n),                   -- Chan2 starts at "index 0"
         -- Inputs from self-test
         -- JM 16/03/2018: Fixed indexes, ch1/ch2 were not matching. NCR_RS_012
         st_mask_ch1_i        => fault_ch1_s(n + (C_CHAN1_LENGTH - C_NUM_SAFETY_INPUTS)), 
         st_mask_ch2_i        => fault_ch2_s(n),                                             
         input_valid_i        => input_valid_s,
         mask_ch1_o           => compare_masked_ch1_s(n),
         mask_ch2_o           => compare_masked_ch2_s(n),
         data_o               => pre_debounce_compare_out_s(n)       -- REQ: 200. Feed second debouncing
      );
   END GENERATE;

   --------------------------------------------------------
   -- INPUT LATCHING
   --------------------------------------------------------

   -- REQ BEGIN: 17
   input_latch_i0: FOR n IN 0 TO C_NUM_SINGLECHAN_INPUTS-1 GENERATE
      input_latch_i: input_latch
      PORT MAP (
         arst_i      => arst_i,
         clk_i       => clk_i,
         data_i      => debounce_out_s(n + C_NUM_SAFETY_INPUTS),     -- Non-safety inputs after safety ones
         hold_i      => selftest_in_progress_s,
         data_o      => pre_debounce_latched_in_s(n)                 -- REQ: 200. Feed second debouncing
      );
   END GENERATE;
   -- REQ END: 17

   --------------------------------------------------------
   -- SECOND DEBOUNCING
   --------------------------------------------------------

   -- REQ START: 200
   debouncer_inst_i1: debouncer
   GENERIC MAP (
      G_INPUTWIDTH          => pre_debounce_latched_in_s'LENGTH,
      G_DEBOUNCECOUNTERMAX  => 9999  -- 15.625us pulse. 10000 samples => 156.25ms, one sample implicit
   )
   PORT MAP (
      clk_i       => clk_i,
      arst_i      => arst_i,
      clken_i     => pulse15_625us_i,
      data_i      => pre_debounce_latched_in_s,
      data_o      => latched_in_s,
      update_o    => open
   );

   debouncer_inst_i2: debouncer
   GENERIC MAP (
      G_INPUTWIDTH          => pre_debounce_compare_out_s'LENGTH,
      G_DEBOUNCECOUNTERMAX  => 9999  -- 15.625us pulse. 10000 samples => 156.25ms, one sample implicit
   )
   PORT MAP (
      clk_i       => clk_i,
      arst_i      => arst_i,
      clken_i     => pulse15_625us_i,
      data_i      => pre_debounce_compare_out_s,
      data_o      => compare_out_s,
      update_o    => open
   );
   -- REQ END: 200

    -- REQ START: 176
    debouncer_inst_i3: debouncer
    GENERIC MAP (
        G_INPUTWIDTH => debounce_out_s(C_NUM_CHECKED_INPUTS + 1 DOWNTO C_NUM_CHECKED_INPUTS)'LENGTH,
        G_DEBOUNCECOUNTERMAX => 9999 -- 15.625us pulse. 10000 samples => 156.25ms, one sample implicit
    )
    PORT MAP (
        clk_i => clk_i,
        arst_i => arst_i,
        clken_i => pulse15_625us_i,
        data_i => debounce_out_s(C_NUM_CHECKED_INPUTS + 1 DOWNTO C_NUM_CHECKED_INPUTS),
        data_o(0) => force_fault_ch2_s,
        data_o(1) => force_fault_ch1_s,
        update_o => open
    );
    -- REQ END: 176


   --------------------------------------------------------
   -- EVENT DETECTION
   --------------------------------------------------------

   -- BEGIN REQ: 12.01

   input_mode_rise_falling_edge_i0: input_mode_rise_falling_edge
   GENERIC MAP (
         MAX_COUNT => 2999
   )
   PORT MAP (
      arst_i => arst_i, clk_i => clk_i, data_i => compare_out_s(5),
      tick_i => pulse500us_i,
      expired_clr_i => pulse500us_i,
      expired_o => spd_lim_override_hld_o,
      mask1_i => compare_masked_ch1_s(5), mask2_i => compare_masked_ch2_s(5), valid_i => '1',
      inhibit_i => '0',
      data_o => spd_lim_override_event_o
   );

   input_mode_rise_falling_edge_i1: input_mode_rise_falling_edge
   GENERIC MAP (
         MAX_COUNT => 2999 -- REQ: 5
   )
   PORT MAP (
      arst_i => arst_i, clk_i => clk_i, data_i => compare_out_s(6),
      tick_i => pulse500us_i,
      expired_clr_i => pulse500us_i,
      expired_o => vigi_pb_hld_o, -- REQ: 5
      mask1_i => compare_masked_ch1_s(6), mask2_i => compare_masked_ch2_s(6), valid_i => '1',
      inhibit_i => '0',
      data_o => vigi_pb_event_o
   );

   -- Non-safety inputs.

   input_mode_rise_falling_edge_i2: input_mode_rise_falling_edge
   GENERIC MAP (
         MAX_COUNT => 5999 -- REQ: 5. CCN03 change
   )
   PORT MAP (
      arst_i => arst_i, clk_i => clk_i, data_i => latched_in_s(0),
      tick_i => pulse500us_i,
      valid_i => '1',
      expired_clr_i => '0',
      inhibit_i => '0',
      mask1_i => fault_ch1_s(0), mask2_i => fault_ch1_s(0),
      data_o => ss_bypass_pb_pre_event_s
   );

   input_mode_rise_or_falling_edge_i0: input_mode_rise_or_falling_edge
   PORT MAP (
      arst_i => arst_i, clk_i => clk_i, data_i => latched_in_s(1),
      mask1_i => fault_ch1_s(1), mask2_i => fault_ch1_s(1), valid_i => '1',
      data_o => w_wiper_pb_pre_event_s
   );

   input_mode_rise_or_falling_edge_i1: input_mode_rise_or_falling_edge
   PORT MAP (
      arst_i => arst_i, clk_i => clk_i, data_i => latched_in_s(2),
      mask1_i => fault_ch1_s(2), mask2_i => fault_ch1_s(2), valid_i => '1',
      data_o => hl_low_pre_event_s
   );

   input_mode_rise_falling_edge_i3: input_mode_rise_falling_edge
   GENERIC MAP (
         MAX_COUNT => 5999 -- REQ: 5
   )
   PORT MAP (
      arst_i => arst_i, clk_i => clk_i, data_i => latched_in_s(3),
      tick_i => pulse500us_i,
      expired_clr_i => '0',
      valid_i => '1',
      inhibit_i => '0',
      mask1_i => fault_ch1_s(3), mask2_i => fault_ch1_s(3),
      data_o => horn_high_pre_event_s
   );

   input_mode_rise_falling_edge_i4: input_mode_rise_falling_edge
   GENERIC MAP (
         MAX_COUNT => 5999 -- REQ: 5
   )
   PORT MAP (
      arst_i => arst_i, clk_i => clk_i, data_i => latched_in_s(4),
      tick_i => pulse500us_i,
      expired_clr_i => '0',
      valid_i => '1',
      inhibit_i => '0',
      mask1_i => fault_ch1_s(4), mask2_i => fault_ch1_s(4),
      data_o => horn_low_pre_event_s
   );

    -- END REQ: 12.01

   --------------------------------------------------------
   -- TIMEOUT FILTERS
   --------------------------------------------------------

   -- REQ START: 124_125
   event_filt_timeout_i0: event_filt_timeout
   GENERIC MAP (
      G_MAX_COUNT   => 20  -- 10 seconds
   )
   PORT MAP (
      arst_i            => arst_i,
      clk_i             => clk_i,
      timeout_tick_i    => pulse500ms_i,
      event_i           => horn_low_pre_event_s,
      event_o           => horn_low_event_o
   );

   event_filt_timeout_i1: event_filt_timeout
   GENERIC MAP (
      G_MAX_COUNT   => 20  -- 10 seconds
   )
   PORT MAP (
      arst_i            => arst_i,
      clk_i             => clk_i,
      timeout_tick_i    => pulse500ms_i,
      event_i           => horn_high_pre_event_s,
      event_o           => horn_high_event_o
   );

   event_filt_timeout_i2: event_filt_timeout
   GENERIC MAP (
      G_MAX_COUNT   => 10  -- 5 seconds
   )
   PORT MAP (
      arst_i            => arst_i,
      clk_i             => clk_i,
      timeout_tick_i    => pulse500ms_i,
      event_i           => hl_low_pre_event_s,
      event_o           => hl_low_event_o
   );


   event_filt_timeout_i3: event_filt_timeout
   GENERIC MAP (
      G_MAX_COUNT   => 20  -- 10 seconds
   )
   PORT MAP (
      arst_i            => arst_i,
      clk_i             => clk_i,
      timeout_tick_i    => pulse500ms_i,
      event_i           => w_wiper_pb_pre_event_s,
      event_o           => w_wiper_pb_event_o
   );

   event_filt_timeout_i5: event_filt_timeout
   GENERIC MAP (
      G_MAX_COUNT   => 20  -- 10 seconds
   )
   PORT MAP (
      arst_i            => arst_i,
      clk_i             => clk_i,
      timeout_tick_i    => pulse500ms_i,
      event_i           => ss_bypass_pb_pre_event_s,
      event_o           => ss_bypass_pb_event_o
   );
   -- REQ END: 124_125

   --------------------------------------------------------
   -- POWER SUPPLY STATUS
   --------------------------------------------------------

   --REQ START: 201
   ps1_fail_s0  <= NOT ps1_stat_i;
   ps2_fail_s0  <= NOT ps2_stat_i;

   error_counter_filter_i0: error_counter_filter
   GENERIC MAP(
      -- Maximum number of errors counted before an output and permanent fault is notified
      G_CNT_ERROR_MAX => 40
   )   
   PORT MAP (
         arst_i      => arst_i,
         clk_i       => clk_i,
         valid_i     => pulse500ms_i,
         fault_i     => ps1_fail_s0,
         fault_o     => ps1_fail_s1
   );

   error_counter_filter_i1: error_counter_filter
   GENERIC MAP(
      -- Maximum number of errors counted before an output and permanent fault is notified
      G_CNT_ERROR_MAX => 40
   )    
   PORT MAP (
         arst_i      => arst_i,
         clk_i       => clk_i,
         valid_i     => pulse500ms_i,
         fault_i     => ps2_fail_s0,
         fault_o     => ps2_fail_s1
   );
   -- REQ END: 201

   --------------------------------------------------------
   -- ANALOGUE IF
   --------------------------------------------------------

   analog_if_i0 : analog_if
   PORT MAP (
      arst_i            => arst_i,
      clk_i             => clk_i,
      pulse500ms_i      => pulse500ms_i,
      spd_l3kmh_i       => spd_l3kmh_i,
      spd_h3kmh_i       => spd_h3kmh_i,
      spd_h23kmh_a_i    => spd_h23kmh_a_i,
      spd_h23kmh_b_i    => spd_h23kmh_b_i,
      spd_h25kmh_a_i    => spd_h25kmh_a_i,
      spd_h25kmh_b_i    => spd_h25kmh_b_i,
      spd_h75kmh_i      => spd_h75kmh_i,
      spd_h90kmh_i      => spd_h90kmh_i,
      spd_h110kmh_i     => spd_h110kmh_i,
      spd_over_spd_i    => spd_over_spd_i,

      spd_l3kmh_o       => spd_l3kmh_s,
      spd_h3kmh_o       => spd_h3kmh_s,
      spd_h23kmh_o      => spd_h23kmh_s,
      spd_h25kmh_o      => spd_h25kmh_s,
      spd_h75kmh_o      => spd_h75kmh_s,
      spd_h90kmh_o      => spd_h90kmh_s,
      spd_h110kmh_o     => spd_h110kmh_s,
      spd_over_spd_o    => spd_over_spd_s,

      spd_urng_o        => spd_urng_s,
      spd_orng_o        => spd_orng_s,
      spd_err_o         => spd_err_s
    );

   --------------------------------------------------------
   -- PWM IF
   --------------------------------------------------------

   pwm_input_i0: pwm_input
   PORT MAP (
      arst_i               => arst_i,
      clk_i                => clk_i,
      pulse_i              => pulsepwm_i,

      pwm0_i               => pwm_ch1_i,
      pwm1_i               => pwm_ch2_i,

      pwm0_duty_o          => pwm0_duty_s,
      pwm0_duty_valid_o    => pwm0_duty_valid_s,

      pwm1_duty_o          => pwm1_duty_s,
      pwm1_duty_valid_o    => pwm1_duty_valid_s,

      pwm0_fault_o         => pwm0_pre_fault_s,
      pwm1_fault_o         => pwm1_pre_fault_s
   );

   --------------------------------------------------------
   -- DEMAND PHASE DETECTION
   --------------------------------------------------------

   demand_phase_det_i0: demand_phase_det
   PORT MAP (
      arst_i               => arst_i,
      clk_i                => clk_i,
                           
      pulse500us_i         => pulse500us_i,
                           
      pwm0_duty_i          => pwm0_duty_s,
      pwm0_duty_valid_i    => pwm0_duty_valid_s,
      pwm1_duty_i          => pwm1_duty_s,
      pwm1_duty_valid_i    => pwm1_duty_valid_s,
                           
      pwm0_fault_i         => pwm0_pre_fault_s,
      pwm1_fault_i         => pwm1_pre_fault_s,
                           
      inhibit_fault_i      => compare_out_s(0),                            -- Inhibit PWM faults if the cab is inactive
                           
      pwm0_fault_o         => pwm0_fault_s,
      pwm1_fault_o         => pwm1_fault_s,
                           
      pwr_brk_dmnd_o       => pwr_brk_dmnd_s,
      mc_no_pwr_o          => mc_no_pwr_s
   );

   -- Analog IF Outputs
   spd_l3kmh_o             <= spd_l3kmh_s;
   spd_h3kmh_o             <= spd_h3kmh_s;
   spd_h23kmh_o            <= spd_h23kmh_s;
   spd_h25kmh_o            <= spd_h25kmh_s;
   spd_h75kmh_o            <= spd_h75kmh_s;
   spd_h90kmh_o            <= spd_h90kmh_s;
   spd_h110kmh_o           <= spd_h110kmh_s;
   spd_over_spd_o          <= spd_over_spd_s;

   spd_urng_o              <= spd_urng_s;
   spd_orng_o              <= spd_orng_s;
   spd_err_o               <= spd_err_s;

   fault_ch1_o(17 DOWNTO 17)<=  (OTHERS => '0');                            -- NR 22/10/2018 Fixed fault order
   fault_ch1_o(16 DOWNTO 0) <=  fault_ch1_s(0)                           &  -- ss_bypass_pb_i
                                '0'                                      &  -- NR CCN04 Removed radio_ptt_i
                                fault_ch1_s(1)                           &  -- w_wiper_pb_i
                                '0'                                      &  -- AF 04/04/2019 Removed hl_high_i
                                fault_ch1_s(2)                           &  -- hl_low_i
                                fault_ch1_s(3)                           &  -- horn_high_i
                                fault_ch1_s(4)                           &  -- horn_low_i
                                fault_ch1_s(12)                          &  -- spd_lim_ch1_i
                                fault_ch1_s(13)                          &  -- driverless_ch1_i
                                fault_ch1_s(10)                          &  -- spd_lim_override_ch1_i  |->
                                                                            -- AF 04/04/2019 Removed vcu_pre_test_ch1_i
                                fault_ch1_s(5)                           &  -- cab_act_ch1_i
                                fault_ch1_s(6)                           &  -- not_isol_ch1_i
                                fault_ch1_s(7)                           &  -- bcp_75_ch1_i
                                fault_ch1_s(8)                           &  -- hcs_mode_ch1_i
                                fault_ch1_s(9)                           &  -- zero_spd_ch1_i
                                '0'                                      &  -- NR CCN04 Removed oep_ack_ch1_i
                                fault_ch1_s(11);                            -- vigi_pb_ch1_i

   fault_ch2_o(17 DOWNTO 10)<=  (OTHERS => '0');                            -- JM 11/04/2018 Fixed fault order
   fault_ch2_o(9 DOWNTO 0)  <=  fault_ch2_s(7)                           &  -- spd_lim_ch2_i
                                fault_ch2_s(8)                           &  -- driverless_ch2_i
                                fault_ch2_s(5)                           &  -- spd_lim_override_ch2_i   |->         
                                                                            -- AF 04/04/2019 Removed vcu_pre_test_ch2_i
                                fault_ch2_s(0)                           &  -- cab_act_ch2_i
                                fault_ch2_s(1)                           &  -- not_isol_ch2_i
                                fault_ch2_s(2)                           &  -- bcp_75_ch2_i
                                fault_ch2_s(3)                           &  -- hcs_mode_ch2_i
                                fault_ch2_s(4)                           &  -- zero_spd_ch2_i
                                '0'                                      &  -- NR CCN04 Removed oep_ack_ch2_i
                                fault_ch2_s(6);                             -- vigi_pb_ch2_i

   -- JM 15/03/2018: Fixed order
   din_stat_o               <= '0'                                       &  -- JM 22/10/2018 Fixed fault order
                               (latched_in_s(0) AND NOT fault_ch1_s(0))  &  -- ss_bypass_pb_pre_event_s
                               '0'                                       &  -- NR CCN04 Removed radio_ptt_pre_event_s
                               (latched_in_s(1) AND NOT fault_ch1_s(1))  &  -- w_wiper_pb_pre_event_s
                               '0'                                       &  -- AF 04/04/2019 del hl_high_pre_event_s
                               (latched_in_s(2) AND NOT fault_ch1_s(2))  &  -- hl_low_pre_event_s
                               (latched_in_s(3) AND NOT fault_ch1_s(3))  &  -- horn_high_pre_event_s
                               (latched_in_s(4) AND NOT fault_ch1_s(4))  &  -- horn_low_pre_event_s
                               compare_out_s(7)                          &  -- spd_lim_event_o
                               compare_out_s(8)                          &  -- driverless_event_o
                               compare_out_s(5)                          &  -- spd_lim_override_o   
                                                                            -- AF 19/03/2019 Del vcu_pre_test_event_o
                               compare_out_s(0)                          &  -- cab_act_event_o      
                                                                            -- JM 22/03/2018 Removed Note: The cab 
                                                                            --   active LED should be lit when the 
                                                                            --   input is logic 1 
                                                                            --  (Tom Thu 22/03/2018 07:23)
                               compare_out_s(1)                          &  -- not_isol_event_o     
                                                                            --   Same for not_isol. DIN LED report 
                                                                            --   should directly map input state
                               compare_out_s(2)                          &  -- bcp_75_event_o
                               compare_out_s(3)                          &  -- hcs_mode_event_o
                               compare_out_s(4)                          &  -- zero_spd_event_o
                               '0'                                       &  -- NR CCN04 Removed oep_ack_o
                               compare_out_s(6);                            -- vigi_pb_o

   din_flt_o               <=  '0' &                                        -- JM 11/04/2018 Fixed fault order
                               fault_ch1_s(0)                            &  -- ss_bypass_pb_i
                               '0'                                       &  -- NR CCN04 Removed radio_ptt_i
                               fault_ch1_s(1)                            &  -- w_wiper_pb_i
                               '0'                                       &  -- CCN03. Removed hl_high_i
                               fault_ch1_s(2)                            &  -- hl_low_i
                               fault_ch1_s(3)                            &  -- horn_high_i
                               fault_ch1_s(4)                            &  -- horn_low_i
                               fault_safety_s(7)                         &  -- spd_lim_ch2_i
                               fault_safety_s(8)                         &  -- driverless_ch2_i
                               fault_safety_s(5)                         &  -- spd_lim_override_ch2_i    
                                                                            -- CCN03. Removed vcu_pre_test_ch2_i
                               fault_safety_s(0)                         &  -- cab_act_ch2_i
                               fault_safety_s(1)                         &  -- not_isol_ch2_i
                               fault_safety_s(2)                         &  -- bcp_75_ch2_i
                               fault_safety_s(3)                         &  -- hcs_mode_ch2_i
                               fault_safety_s(4)                         &  -- zero_spd_ch2_i
                               '0'                                       &  -- NR CCN04 Removed oep_ack_ch2_i
                               fault_safety_s(6);                           -- vigi_pb_ch2_i


   pwr_brk_dmnd_o          <= pwr_brk_dmnd_s;
   mc_no_pwr_o             <= mc_no_pwr_s;
   pwm0_flt_o              <= pwm0_fault_s;
   pwm1_flt_o              <= pwm1_fault_s;

   pwm_stat_o              <= NOT(pwm0_fault_s AND pwm1_fault_s);
   pwm_flt_o               <= pwm0_fault_s OR pwm1_fault_s;
   anal_stat_o             <= NOT spd_err_s;                               -- JM 22/03/2018 Should stay green when no
                                                                           --        analog fault (was tied to '0')
   anal_flt_o              <= spd_err_s;                                   
   -- Merge faults from selftest and transition counters
   fault_o                 <= st_fault_s                                   -- REQ: 188
                              OR (pwm0_fault_s OR pwm1_fault_s)            -- REQ: 36
                              OR OR_REDUCE(compare_fault_s)                -- REQ: 23 (OPL ID #5)
                              OR ps1_fail_s1                               -- REQ: 201
                              OR ps2_fail_s1;                              -- REQ: 201
   
   -- REQ START: 27
   cab_act_event_o         <= compare_out_s(0) AND NOT compare_fault_s(0); -- REQ: 12.01
   not_isol_event_o        <= compare_out_s(1) AND NOT compare_fault_s(1); -- REQ: 12.01
   bcp_75_event_o          <= compare_out_s(2) AND NOT compare_fault_s(2); -- REQ: 12.01
   hcs_mode_event_o        <= compare_out_s(3) AND NOT compare_fault_s(3); -- REQ: 12.01
   zero_spd_event_o        <= compare_out_s(4) AND NOT compare_fault_s(4); -- REQ: 12.01
   spd_lim_override_o      <= compare_out_s(5) AND NOT compare_fault_s(5);
   vigi_pb_o               <= compare_out_s(6) AND NOT compare_fault_s(6); -- REQ: 12.01
   spd_lim_event_o         <= compare_out_s(7) AND NOT compare_fault_s(7); -- REQ: 12.01
   driverless_event_o      <= compare_out_s(8) AND NOT compare_fault_s(8); -- REQ: 12.01
   -- REQ END: 27
   
   ps1_fail_o              <= ps1_fail_s1;                                 -- JM 03/04/2018 Added PS fail outputs
   ps2_fail_o              <= ps2_fail_s1;
   zero_spd_flt_o          <= compare_fault_s(4);

END beh;
