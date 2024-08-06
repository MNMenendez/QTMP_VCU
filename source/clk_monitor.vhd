---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : clk_monitor.vhd
-- Module      : Clock Monitor
-- Revision    : 1.2
-- Date/Time   : May 21, 2020
-- Author      : NRibeiro
---------------------------------------------------------------
-- Description : Input Clock Monitor (generates watchdog signal)
---------------------------------------------------------------
-- History :
-- Revision 1.2 - May 21, 2020
--    - NRibeiro: Added source code requirement traceability
-- Revision 1.1 - March 02, 2018
--    - JMonteiro: Applied code review comments.
-- Revision 1.0 - January 29, 2018
--    - JMonteiro: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


ENTITY clk_monitor IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Clock/Reset Inputs
      ----------------------------------------------------------------------------
      arst_i            : IN STD_LOGIC;      -- Global (asynch) reset
      clk_i             : IN STD_LOGIC;      -- Global clk

      ----------------------------------------------------------------------------
      --  Timing
      ----------------------------------------------------------------------------
      pulse500us_i      : IN STD_LOGIC;      -- Internal 500ms synch pulse

      ----------------------------------------------------------------------------
      --  Outputs
      ----------------------------------------------------------------------------
      penalty1_wd_o     : OUT STD_LOGIC;
      penalty2_wd_o     : OUT STD_LOGIC

   );
END ENTITY clk_monitor;


ARCHITECTURE beh OF clk_monitor IS

   --------------------------------------------------------
   -- CONSTANTS
   --------------------------------------------------------
   CONSTANT C_MCTR_INIT    : UNSIGNED(5 DOWNTO 0) := TO_UNSIGNED(INTEGER(40-1),6);

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------
   -- Monitor counter
   SIGNAL mon_ctr_s     : UNSIGNED(5 DOWNTO 0);
   SIGNAL mon_ctr_r     : UNSIGNED(5 DOWNTO 0);                                     -- Max value = 20

   -- Monitor Pulse
   SIGNAL mon_pls_s     : STD_LOGIC;
   SIGNAL mon_pls_r     : STD_LOGIC;

   -- Watchdog pulse
   SIGNAL wd_pls_s      : STD_LOGIC;
   SIGNAL wd_pls_r      : STD_LOGIC;

BEGIN

   -- Monitor Counter                                                               -- REQ START: 218
   p_mon_ctr: PROCESS(clk_i, arst_i)                                                -- 50Hz ctr
   BEGIN
      IF (arst_i = '1') THEN
         mon_ctr_r   <= (OTHERS => '0');
      ELSIF RISING_EDGE(clk_i) THEN
         IF (pulse500us_i = '1') THEN
            mon_ctr_r <= mon_ctr_s;
         END IF;
      END IF;
   END PROCESS p_mon_ctr;
   mon_ctr_s   <= mon_ctr_r - 1 WHEN mon_ctr_r /= 0 ELSE
                  C_MCTR_INIT;

   -- Pulse Gen
   p_mon_pls: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         mon_pls_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         mon_pls_r <= mon_pls_s;
      END IF;
   END PROCESS p_mon_pls;
   mon_pls_s   <= '1' WHEN mon_ctr_r = 0 ELSE
                  '0';

   -- Pulse Gen (Min width 50us: One system clock period = 1/16.384E6 ~= 61ns)
   wd_pls_s <= mon_pls_s AND (NOT mon_pls_r);

   -- Output reg
   p_reg: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         wd_pls_r   <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         wd_pls_r   <= wd_pls_s;
      END IF;
   END PROCESS p_reg;

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------
   penalty1_wd_o <= wd_pls_r;
   penalty2_wd_o <= wd_pls_r;                                                       -- REQ END: 218

END ARCHITECTURE beh;