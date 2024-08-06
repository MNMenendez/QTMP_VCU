---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : diag_if.vhd
-- Module      : diag_if
-- Revision    : 1.6
-- Date/Time   : December 11, 2019
-- Author      : Alvaro Lopes, AFernandes, NRibeiro
---------------------------------------------------------------
-- Description : DIAG Interface HDL
---------------------------------------------------------------
-- History :
-- Revision 1.6 - December 11, 2019
--    - NRibeiro: Code/Comments cleanup.
-- Revision 1.5 - November 29, 2019
--    - NRibeiro: Applied CCN04 code changes
-- Revision 1.4 - March 20, 2019
--    - AFernandes: Applied CCN03 code changes
-- Revision 1.3 - July 27, 2018
--    - AFernandes: Applied CCN02 code changes.
-- Revision 1.2 - May 16, 2018
--    - JMonteiro: Applied code review comments for baseline 02.
-- Revision 1.1 - March 07, 2018
--    - ALopes: Rework according to review
-- Revision 1.0 - February 07, 2018
--    - ALopes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE WORK.HCMT_CPLD_TOP_P.ALL;

ENTITY diag_if IS
   PORT (
      -- Clock and reset
      arst_i            : IN  STD_LOGIC;
      clk_i             : IN  STD_LOGIC;
      -- Pulse tick
      pulse_i           : IN  STD_LOGIC; -- Pulse tick
      -- Power supply inputs
      ps1_fail_i        : IN STD_LOGIC;
      ps2_fail_i        : IN STD_LOGIC;
      -- Self-test fault inputs
      ch1_st_fail_i     : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
      ch2_st_fail_i     : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
      -- PWM fault inputs
      pwm0_fail_i       : IN STD_LOGIC;
      pwm1_fail_i       : IN STD_LOGIC;
      -- Analogue faults
      anal_under_fail_i : IN STD_LOGIC;
      anal_over_fail_i  : IN STD_LOGIC;
      anal_fault_i      : IN STD_LOGIC;
      -- Relay feedback faults
      rly1_fault_i      : IN STD_LOGIC;
      rly2_fault_i      : IN STD_LOGIC;
      rly3_fault_i      : IN STD_LOGIC;
      -- Penalty brake faults
      pen1_fault_i      : IN STD_LOGIC;
      pen2_fault_i      : IN STD_LOGIC;
      -- Digital outputs fault
      digout_fault_i    : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      -- Buzzer fault
      buzzer_fault_i    : IN STD_LOGIC;
      -- Operation mode inputs and states
      opmode_nrm_i      : IN STD_LOGIC;      -- VCU in Normal Mode
      opmode_sup_i      : IN STD_LOGIC;      -- VCU in Suppressed Mode
      opmode_dep_i      : IN STD_LOGIC;      -- VCU in Depressed Mode
      opmode_tst_i      : IN STD_LOGIC;      -- VCU in Test Mode
      opmode_mft_i      : IN STD_LOGIC;      -- VCU in Major Fault Mode
      vcu_rst_i         : IN STD_LOGIC;      -- VCU reset occurred
      st_1st_wrn_i      : IN STD_LOGIC;      -- Entered First Stage Warning
      st_2st_wrn_i      : IN STD_LOGIC;      -- Entered Second Stage Warning
      penalty1_out_i    : IN STD_LOGIC;      -- Penalty Brake 1 Applied
      penalty2_out_i    : IN STD_LOGIC;      -- Penalty Brake 2 Applied
      rly_out1_3V_i     : IN STD_LOGIC;      -- Radio Alarm Requested
      zero_spd_i        : IN STD_LOGIC;      -- Train at zero speed (Internal logic, not raw digital input state)
      light_out_i       : IN STD_LOGIC;      -- Visible Warning Light On
      buzzer_out_i      : IN STD_LOGIC;      -- Buzzer On
      -- Diagnostic protocol outputs
      diag_clk_o        : OUT STD_LOGIC;
      diag_data_o       : OUT STD_LOGIC;
      diag_strobe_o     : OUT STD_LOGIC
   );

END ENTITY diag_if;

ARCHITECTURE beh OF diag_if IS

   --------------------------------------------------------
   -- COMPONENTS
   --------------------------------------------------------

   COMPONENT diag_streamer IS
   PORT (
      -- Clock inputs
      arst_i:        IN  STD_LOGIC; -- Async reset in
      clk_i:         IN  STD_LOGIC; -- Clock
      -- Control inputs
      pulse_i:       IN  STD_LOGIC; -- Pulse tick (twice protocol speed)
      -- Data in
      data_i:        IN  STD_LOGIC_VECTOR(127 DOWNTO 0); -- General input data

      diag_clk_o:    OUT STD_LOGIC; -- Output clock for Diagnostics interface
      diag_data_o:   OUT STD_LOGIC; -- Output data for Diagnostics interface
      diag_strobe_o: OUT STD_LOGIC  -- Output strobe for Diagnostics interface
   );

   END COMPONENT diag_streamer;

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------

   SIGNAL data_s        : STD_LOGIC_VECTOR(127 DOWNTO 0);   -- REQ: 70.03
   SIGNAL diag_clk_s    : STD_LOGIC;
   SIGNAL diag_data_s   : STD_LOGIC;
   SIGNAL diag_strobe_s : STD_LOGIC;
   SIGNAL pen_out_s     : STD_LOGIC;

BEGIN

   pen_out_s <= penalty1_out_i OR penalty2_out_i;

   data_s(127 DOWNTO 77) <= (OTHERS => '0');
   data_s(76 DOWNTO 0) <= buzzer_out_i                               &               -- REQ: 71_180
                          light_out_i                                &
                          zero_spd_i                                 &
                          rly_out1_3V_i                              &
                          '0'                                        &               -- NR CCN04 Removed park_out_i
                          NOT pen_out_s                              &
                          st_2st_wrn_i                               &
                          st_1st_wrn_i                               &
                          vcu_rst_i                                  &
                          opmode_mft_i                               &
                          opmode_tst_i                               &
                          opmode_dep_i                               &
                          opmode_sup_i                               &
                          opmode_nrm_i                               &
                          buzzer_fault_i                             &
                          digout_fault_i(11)                         &                -- REQ: 199
                          reverse_bits(digout_fault_i(10 DOWNTO 1))  &
                          '0'                                        &                -- NR CCN04 Removed park_fault_i
                          pen2_fault_i                               &
                          pen1_fault_i                               &
                          rly3_fault_i                               &                -- CCN03 change
                          rly2_fault_i                               &
                          rly1_fault_i                               &
                          anal_fault_i                               &
                          anal_under_fail_i                          &
                          anal_over_fail_i                           &
                          pwm1_fail_i                                &
                          pwm0_fail_i                                &
                          ch2_st_fail_i                              &
                          ch1_st_fail_i                              &
                          '0'                                        &               -- OSC2 Fail
                          '0'                                        &               -- OSC1 Fail
                          ps2_fail_i                                 &
                          ps1_fail_i;

   diag_streamer_i0: diag_streamer
   PORT MAP (
      arst_i         => arst_i,
      clk_i          => clk_i,
      pulse_i        => pulse_i,
      data_i         => data_s,
      diag_clk_o     => diag_clk_s,                         -- REQ: 70
      diag_data_o    => diag_data_s,                        -- REQ: 70.01
      diag_strobe_o  => diag_strobe_s                       -- REQ: 70.02
   );

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------

   diag_clk_o     <= diag_clk_s;
   diag_data_o    <= diag_data_s;
   diag_strobe_o  <= diag_strobe_s;

END beh;
