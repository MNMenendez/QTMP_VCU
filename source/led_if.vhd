---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : led_if.vhd
-- Module      : led_if
-- Revision    : 1.6
-- Date/Time   : December 11, 2019
-- Author      : Alvaro Lopes, AFernandes, NRibeiro
---------------------------------------------------------------
-- Description : LED Interface HDL
---------------------------------------------------------------
-- History :
-- Revision 1.6 - December 11, 2019
--    - NRibeiro: Code/Comments cleanup.
-- Revision 1.5 - November 29, 2019
--    - NRibeiro: Applied CCN04 code changes
-- Revision 1.4 - March 25, 2019
--    - AFernandes: Applied CCN03 code changes
-- Revision 1.3 - July 27, 2018
--    - AFernandes: Applied CCN02 code changes.
-- Revision 1.2 - May 16, 2018
--    - JMonteiro: Applied code review comments for baseline 02.
-- Revision 1.1 - March 07, 2018
--    - ALopes: Rework according to review
-- Revision 1.0 - January 15, 2018
--    - ALopes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
LIBRARY WORK;
USE WORK.HCMT_CPLD_TOP_P.ALL;

ENTITY led_if IS
   PORT (
      -- Clock and reset
      arst_i         : IN  STD_LOGIC;
      clk_i          : IN  STD_LOGIC;
      -- Pulse tick to generate display clock
      pulse_i        : IN  STD_LOGIC;
      -- Status and fault inputs
      din_stat_i     : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
      din_flt_i      : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
      pwm_stat_i     : IN STD_LOGIC;
      pwm_flt_i      : IN STD_LOGIC;
      anal_stat_i    : IN STD_LOGIC;
      anal_flt_i     : IN STD_LOGIC;
      dout_stat_i    : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      dout_flt_i     : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      buz_stat_i     : IN STD_LOGIC;
      buz_flt_i      : IN STD_LOGIC;
      pb1_stat_i     : IN STD_LOGIC;
      pb1_flt_i      : IN STD_LOGIC;
      pb2_stat_i     : IN STD_LOGIC;
      pb2_flt_i      : IN STD_LOGIC;
      tcr_flt_i      : IN STD_LOGIC;
      rly_stat_i     : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      rly_flt_i      : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      mode_nrm_i     : IN STD_LOGIC;
      mode_sup_i     : IN STD_LOGIC;
      mode_dep_i     : IN STD_LOGIC;

      -- Output signals for LED display
      disp_clk_o     : OUT STD_LOGIC;
      disp_data_o    : OUT STD_LOGIC;
      disp_strobe_o  : OUT STD_LOGIC;
      disp_oe_o      : OUT STD_LOGIC
   );

END ENTITY led_if;

ARCHITECTURE beh OF led_if IS

   --------------------------------------------------------
   -- COMPONENTS
   --------------------------------------------------------

   COMPONENT led_streamer IS
   PORT (
      arst_i:        IN  STD_LOGIC;
      clk_i:         IN  STD_LOGIC;

      pulse_i:       IN  STD_LOGIC; -- Pulse tick

      -- Red inputs
      red_i:         IN  STD_LOGIC_VECTOR(63 DOWNTO 0);
      -- Green inputs
      green_i:       IN  STD_LOGIC_VECTOR(63 DOWNTO 0);

      disp_clk_o:    OUT STD_LOGIC;
      disp_data_o:   OUT STD_LOGIC;
      disp_strobe_o: OUT STD_LOGIC;
      disp_oe_o:     OUT STD_LOGIC
   );

   END COMPONENT led_streamer;

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------

   SIGNAL red_s         : STD_LOGIC_VECTOR(63 DOWNTO 0);
   SIGNAL green_s       : STD_LOGIC_VECTOR(63 DOWNTO 0);
   SIGNAL rly_stat_s    : STD_LOGIC_VECTOR(2 DOWNTO 0);
   SIGNAL rly_flt_s     : STD_LOGIC_VECTOR(2 DOWNTO 0);
   -- Fault inputs
   SIGNAL fault_s       : STD_LOGIC_VECTOR(42 DOWNTO 0);
   -- Status inputs
   SIGNAL status_s      : STD_LOGIC_VECTOR(42 DOWNTO 0);
   -- Display signals
   SIGNAL disp_clk_s    : STD_LOGIC;
   SIGNAL disp_data_s   : STD_LOGIC;
   SIGNAL disp_strobe_s : STD_LOGIC;
   SIGNAL disp_oe_s     : STD_LOGIC;

BEGIN

   -- REQ START: 75_181
   status_s <=
      reverse_bits(din_stat_i)   &  -- LED 1:18
      mode_nrm_i                 &  -- LED 19
      mode_sup_i                 &  -- LED 20
      dout_stat_i(10 DOWNTO 1)   &  -- LED 21:30
      dout_stat_i(11)            &  -- LED 31
      buz_stat_i                 &  -- LED 32
      NOT pb1_stat_i             &  -- LED 33
      NOT pb2_stat_i             &  -- LED 34
      '0'                        &  -- NR CCN04 Removed park_stat_i -- LED 35
      reverse_bits(rly_stat_s)   &  -- LED 36:38
      '0'                        &  -- LED 39
      '0'                        &  -- LED 40
      -- LED 41
      pwm_stat_i                 &  -- REQ: 84
      anal_stat_i                &  -- LED 42
      mode_dep_i;                   -- LED 43

   fault_s <=
      reverse_bits(din_flt_i)    &  -- LED 1:18
      '0'                        &  -- LED 19 (normal mode red)
      '0'                        &  -- LED 20 (suppressed mode red)
      dout_flt_i(10 DOWNTO 1)    &  -- LED 21:30
      dout_flt_i(11)             &  -- LED 31
      buz_flt_i                  &  -- LED 32
      pb1_flt_i                  &  -- LED 33
      pb2_flt_i                  &  -- LED 34
      '0'                        &  -- NR CCN04 Removed park_stat_i -- LED 35
      reverse_bits(rly_flt_s)    &  -- LED 36:38
      '0'                        &  -- LED 39
      tcr_flt_i                  &  -- LED 40
      -- LED 41
      pwm_flt_i                  &  -- REQ: 84
      anal_flt_i                 &  -- LED 42
      '0';                          -- LED 43 (depressed mode red)

   -- REQ END: 75_181

   -- REQ START: 77
   red_s(20 DOWNTO 0)      <= (OTHERS => '0');
   green_s(19 DOWNTO 0)    <= (OTHERS => '0');

   red_s(63 DOWNTO 21)     <= fault_s;
   green_s(63 DOWNTO 20)   <= '0' & status_s;
   -- REQ END: 77

   led_streamer_i0: led_streamer
   PORT MAP (
      arst_i         => arst_i,
      clk_i          => clk_i,
      pulse_i        => pulse_i,
      red_i          => red_s,
      green_i        => green_s,
      disp_clk_o     => disp_clk_s,
      disp_data_o    => disp_data_s,
      disp_strobe_o  => disp_strobe_s,
      disp_oe_o      => disp_oe_s
   );

   --------------------------------------------------------
   -- INPUTS
   --------------------------------------------------------
   rly_stat_s  <= ( NOT (rly_stat_i(2)))  & ( NOT (rly_stat_i(1))) & rly_stat_i(0);
   rly_flt_s   <= rly_flt_i(2 DOWNTO 0);

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------

   disp_clk_o     <= disp_clk_s;          -- REQ: 75.01
   disp_data_o    <= disp_data_s;         -- REQ: 75.02
   disp_strobe_o  <= disp_strobe_s;       -- REQ: 75.03
   disp_oe_o      <= disp_oe_s;           -- REQ: 183

END beh;
