---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : timing.vhd
-- Module      : timing
-- Revision    : 1.3
-- Date/Time   : November 29, 2019
-- Author      : Alvaro Lopes, AFernandes, NRibeiro
---------------------------------------------------------------
-- Description : Timing Generator
---------------------------------------------------------------
-- History :
-- Revision 1.3 - November 29, 2019
--    - NRibeiro:  Applied CCN04 changes.
-- Revision 1.2 - June 14, 2019
--    - AFernandes: Rework according to CCN03 review
-- Revision 1.1 - March 07, 2018
--    - ALopes: Rework according to review
-- Revision 1.0 - January 10, 2018
--    - ALopes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
LIBRARY WORK;
USE WORK.HCMT_CPLD_TOP_P.ALL;

ENTITY timing IS
   PORT (
      -- Clocks and reset
      aextrst_i       : IN  STD_LOGIC; -- External async reset in
      clk_i           : IN  STD_LOGIC;
      -- Pulse output
      pulse500ms_o    : OUT STD_LOGIC;  -- 500msec pulse
      pulse250ms_o    : OUT STD_LOGIC;  -- 250msec pulse
      pulse500us_o    : OUT STD_LOGIC;  -- 500us pulse
      pulse15_625us_o : OUT STD_LOGIC; -- 31.25us pulse
      pulse78ms_o     : OUT STD_LOGIC; -- 78ms pulse
      pulsedisp_o     : OUT STD_LOGIC; -- ~97.660Khz pulse (twice display clock)
      pulsepwm_o      : OUT STD_LOGIC;
      -- Reset output (async asserted, synchronously de-asserted)
      rst_o           : OUT STD_LOGIC -- Reset for rest of system
   );
END ENTITY timing;

ARCHITECTURE beh OF timing IS

   --------------------------------------------------------
   -- COMPONENTS
   --------------------------------------------------------

   COMPONENT edge_detector IS
      GENERIC (
         G_EDGEPOLARITY:  STD_LOGIC := '1'
      );
      PORT (
         arst_i:           IN  STD_LOGIC;
         clk_i:            IN  STD_LOGIC;
         valid_i:          IN  STD_LOGIC;
         data_i:           IN  STD_LOGIC;
         edge_o:           OUT STD_LOGIC
      );
   END COMPONENT edge_detector;

   --------------------------------------------------------
   -- CONSTANTS
   --------------------------------------------------------

   CONSTANT C_CNT_250MS_B2MS  : NATURAL  := 124;        -- 250ms on a 2ms timebase
   CONSTANT C_CNT_78MS_B2MS   : NATURAL  := 36;         -- 78ms on a 2ms timebase
   CONSTANT C_CNT_97523HZ     : NATURAL  := 167;        -- 97.523KHz, twice LED/diag clock (will generate 48.76KHz)

   CONSTANT C_CNT_HIGH_BIT    : NATURAL  := 14;         -- Maximum counter bits

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------

   SIGNAL rst_r            : STD_LOGIC_VECTOR(1 DOWNTO 0);
   SIGNAL cnt_r            : UNSIGNED( ( C_CNT_HIGH_BIT - C_CLK_DERATE_BITS ) DOWNTO 0);

   SIGNAL cnt250ms_r       : INTEGER RANGE 0 TO C_CNT_250MS_B2MS;
   SIGNAL cnt78ms_r        : INTEGER RANGE 0 TO C_CNT_78MS_B2MS;
   SIGNAL cntdisp_r        : INTEGER RANGE 0 TO C_CNT_97523HZ;

   SIGNAL rst_s            : STD_LOGIC;
   SIGNAL pulse2ms_s       : STD_LOGIC;
   SIGNAL pulse78ms_r      : STD_LOGIC;
   SIGNAL pulse500ms_r     : STD_LOGIC;
   SIGNAL pulse250ms_r     : STD_LOGIC;
   SIGNAL pulsepwm_s       : STD_LOGIC;
   SIGNAL pulse500us_s     : STD_LOGIC;
   SIGNAL pulse15_625us_s  : STD_LOGIC;
   SIGNAL pulsedisp_r      : STD_LOGIC;
   SIGNAL p250ms_dly_r     : STD_LOGIC;

BEGIN

   -- Reset generator
   p_rstgen: PROCESS(aextrst_i, clk_i)
   BEGIN
      IF (aextrst_i = '0') THEN
         rst_r      <= (OTHERS => '1');
      ELSIF RISING_EDGE(clk_i) THEN
         rst_r(rst_r'HIGH DOWNTO 1) <= rst_r(rst_r'HIGH-1 DOWNTO 0);
         rst_r(0) <= '0';

      END IF;
   END PROCESS p_rstgen;

   rst_s      <= rst_r(rst_r'HIGH);

   -- Tick counter
   p_tickcnt: PROCESS(rst_s,clk_i)
   BEGIN
      IF (rst_s = '1') THEN
         cnt_r <= (OTHERS => '0');
      ELSIF RISING_EDGE(clk_i) THEN
         cnt_r <= cnt_r + 1;
      END IF;
   END PROCESS p_tickcnt;

   --------------------------------------------------------
   -- TICK GENERATORS
   --------------------------------------------------------

   edge_detector_i0: edge_detector
   PORT MAP (
      arst_i   => rst_s,
      clk_i    => clk_i,
      valid_i  => '1',
      data_i   => cnt_r(12 - C_CLK_DERATE_BITS),  -- 12th bit, ticks every 500us
      edge_o   => pulse500us_s
   );

   edge_detector_i1: edge_detector
   GENERIC MAP (
      G_EDGEPOLARITY   => '0'                     -- Ensure both 15.625 and 500us ticks are aligned.
   )
   PORT MAP (
      arst_i   => rst_s,
      clk_i    => clk_i,
      valid_i  => '1',
      data_i   => cnt_r(7 - C_CLK_DERATE_BITS),   -- 7th bit, ticks every 15.625us
      edge_o   => pulse15_625us_s
   );

   edge_detector_i2: edge_detector
   GENERIC MAP (
      G_EDGEPOLARITY   => '0'
   )
   PORT MAP (
      arst_i   => rst_s,
      clk_i    => clk_i,
      valid_i  => '1',
      data_i   => cnt_r(5 - C_CLK_DERATE_BITS),   -- 5th bit, ticks every ~3.91us
      edge_o   => pulsepwm_s
   );

   edge_detector_i3: edge_detector
   PORT MAP (
      arst_i   => rst_s,
      clk_i    => clk_i,
      valid_i  => '1',
      data_i   => cnt_r(14 - C_CLK_DERATE_BITS),  -- 14th bit, ticks every 2ms
      edge_o   => pulse2ms_s
   );

   -- Generate 250ms and 500ms ticks
   p_250ms_500ms: PROCESS(rst_s,clk_i)
   BEGIN
      IF (rst_s = '1') THEN
         cnt250ms_r     <= 0;
         pulse250ms_r   <= '0';
         pulse500ms_r   <= '0';
         p250ms_dly_r   <= '0';

      ELSIF RISING_EDGE(clk_i) THEN

         pulse250ms_r   <= '0';
         pulse500ms_r   <= '0';

         IF (pulse2ms_s = '1') THEN
           IF (cnt250ms_r /= C_CNT_250MS_B2MS) THEN
              cnt250ms_r <= cnt250ms_r + 1;
           ELSE
              cnt250ms_r      <= 0;
              pulse250ms_r    <= '1';
              p250ms_dly_r    <= not p250ms_dly_r; -- This will flip every 250ms
              IF (p250ms_dly_r = '1') THEN
                pulse500ms_r  <= '1';
              END IF;
           END IF;
         END IF;
      END IF;
   END PROCESS;

   -- Generate a 78ms tick
   p_78ms: PROCESS(rst_s,clk_i)
   BEGIN
      IF (rst_s = '1') THEN
         cnt78ms_r   <= 0;
         pulse78ms_r <= '0';

      ELSIF RISING_EDGE(clk_i) THEN

         pulse78ms_r    <= '0';
         IF (pulse2ms_s = '1') THEN
            IF (cnt78ms_r /= C_CNT_78MS_B2MS) THEN
                 cnt78ms_r <= cnt78ms_r + 1;
            ELSE
                 cnt78ms_r    <= 0;
                 pulse78ms_r  <= '1';
            END IF;
         END IF;
      END IF;
   END PROCESS p_78ms;

   -- Generate tick for diag and LED interface
   p_dispclk: PROCESS(rst_s,clk_i)
   BEGIN
      IF (rst_s = '1') THEN
         cntdisp_r   <= 0;
         pulsedisp_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         pulsedisp_r    <= '0';
         IF (cntdisp_r /= C_CNT_97523HZ) THEN
            cntdisp_r   <= cntdisp_r + 1;
         ELSE
            cntdisp_r   <= 0;
            pulsedisp_r <= '1';
         END IF;
      END IF;
   END PROCESS p_dispclk;

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------

   pulse250ms_o      <= pulse250ms_r;
   pulse500ms_o      <= pulse500ms_r;
   pulsedisp_o       <= pulsedisp_r;
   pulse78ms_o       <= pulse78ms_r;
   pulsepwm_o        <= pulsepwm_s;
   pulse500us_o      <= pulse500us_s;
   pulse15_625us_o   <= pulse15_625us_s;
   rst_o             <= rst_s;

END beh;
