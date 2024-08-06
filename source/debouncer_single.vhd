---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : debouncer_single.vhd
-- Module      : debouncer_single
-- Revision    : 1.1
-- Date/Time   : March 07, 2018
-- Author      : Alvaro Lopes
---------------------------------------------------------------
-- Description : Digital Input debouncer
---------------------------------------------------------------
-- History :
-- Revision 1.1 - March 07, 2018
--    - ALopes: Rework according to review
-- Revision 1.0 - January 9, 2018
--    - ALopes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY debouncer_single IS
   GENERIC (
      G_DEBOUNCECOUNTERMAX: NATURAL := 8191
   );
   PORT (
      -- Clock and reset
      arst_i   : IN  STD_LOGIC;
      clk_i    : IN  STD_LOGIC;
      -- Clock enable
      clken_i  : IN  STD_LOGIC;
      -- Data input
      data_i   : IN  STD_LOGIC;
      -- Debounced data output
      data_o   : OUT  STD_LOGIC
   );
END ENTITY debouncer_single;

ARCHITECTURE beh OF debouncer_single IS

   --------------------------------------------------------
   -- SIGNALS 
   --------------------------------------------------------

  SIGNAL data_r                  : STD_LOGIC_VECTOR(1 DOWNTO 0);
  SIGNAL data_latch_r            : STD_LOGIC;
  SIGNAL debounce_counter_r      : NATURAL RANGE 0 TO G_DEBOUNCECOUNTERMAX;
  SIGNAL data_input_mismatch_s   : STD_LOGIC;
  SIGNAL counter_is_max_s        : STD_LOGIC;

BEGIN

   -- Synchronize input data into our clock domain
   p_sync_inputs: PROCESS(clk_i,arst_i)
   BEGIN
      IF arst_i='1' THEN
         data_r<=(OTHERS => '0');
      ELSIF RISING_EDGE(clk_i) THEN
         IF (clken_i = '1') THEN
            data_r(0) <= data_i;
            data_r(1) <= data_r(0);
         END IF;
      END IF;
   END PROCESS p_sync_inputs;

   data_input_mismatch_s <= data_r(0) XOR data_r(1);
   counter_is_max_s <= '1' WHEN (debounce_counter_r = G_DEBOUNCECOUNTERMAX) ELSE '0';

   -- Debounce the input using the counter
   p_count: PROCESS(clk_i,arst_i)
   BEGIN
      IF arst_i='1' THEN
         debounce_counter_r   <= 0;
         data_latch_r         <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         IF (clken_i = '1') then
            IF (data_input_mismatch_s = '1') THEN
               -- Reset counter on mismatch
               debounce_counter_r <= 0;
            ELSIF (counter_is_max_s = '0') THEN
               debounce_counter_r <= debounce_counter_r + 1;
            ELSE
               -- Latch data if we reached max count
               data_latch_r <= data_r(1);
            END IF;
         END IF;
      END IF;
   END PROCESS p_count;

   --------------------------------------------------------
   -- OUTPUTS 
   --------------------------------------------------------

   data_o <= data_latch_r;

END beh;

