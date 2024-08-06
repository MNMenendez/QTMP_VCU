---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : event_filt_timeout.vhd
-- Module      : event_filt_timeout
-- Revision    : 1.2
-- Date/Time   : May 16, 2018
-- Author      : Alvaro Lopes
---------------------------------------------------------------
-- Description : Event filter with timeout
---------------------------------------------------------------
-- History :
-- Revision 1.2 - May 16, 2018
--    - JMonteiro: Applied code review comments for baseline 02.
-- Revision 1.1 - March 07, 2018
--    - ALopes: Rework according to review
-- Revision 1.0 - February 20, 2018
--    - ALopes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY event_filt_timeout IS
   GENERIC (
      G_MAX_COUNT:  NATURAL := 20
   );
   PORT (
      -- Clock and reset
      arst_i            : IN  STD_LOGIC;
      clk_i             : IN  STD_LOGIC;
      -- Input tick
      timeout_tick_i    : IN  STD_LOGIC;
      -- Event to filter
      event_i           : IN  STD_LOGIC;
      -- Event filtered out
      event_o           : OUT STD_LOGIC
   );
END ENTITY event_filt_timeout;


ARCHITECTURE beh OF event_filt_timeout IS

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------

   SIGNAL cnt_r         : NATURAL RANGE 0 TO G_MAX_COUNT;
   SIGNAL cnt_zero_s    : STD_LOGIC;
   SIGNAL event_r       : STD_LOGIC;

BEGIN

   cnt_zero_s <= '1' WHEN cnt_r=0 ELSE '0';

   -- Count time since last event
   p_cnt: PROCESS(clk_i,arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         cnt_r <= 0;
      ELSIF RISING_EDGE(clk_i) THEN
         IF (event_i = '1') THEN
            cnt_r <= G_MAX_COUNT;
         ELSIF (timeout_tick_i = '1' AND cnt_zero_s = '0') THEN
            cnt_r <= cnt_r - 1;
         END IF;
      END IF;
   END PROCESS p_cnt;

   -- Generate a synchronous output
   p_eventgen: PROCESS(clk_i,arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         event_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         event_r <= event_i AND cnt_zero_s;
      END IF;
   END PROCESS p_eventgen;

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------

   event_o <= event_r;

END beh;
