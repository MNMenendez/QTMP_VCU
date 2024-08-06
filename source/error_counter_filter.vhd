---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : error_counter_filter.vhd
-- Module      : error_counter_filter
-- Revision    : 1.3
-- Date/Time   : May 31, 2021
-- Author      : Ana Fernandes, NRibeiro
---------------------------------------------------------------
-- Description : Error Counter Filter
---------------------------------------------------------------
-- History :
-- Revision 1.3 - May 31, 2021
--    - NRibeiro: [CCN05/CCN06] Applied code review comments.
-- Revision 1.2 - April 14, 2021
--    - NRibeiro: [CCN05] Added generic G_CNT_ERROR_MAX
-- Revision 1.1 - November 29, 2019
--    - NRibeiro: counter_max_s was changed from 16 to 40.
-- Revision 1.0 - 27 March, 2019
--    - Ana Fernandes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE WORK.HCMT_CPLD_TOP_P.ALL;

ENTITY error_counter_filter IS
   GENERIC(
      -- Maximum number of errors counted before an output and permanent fault is notified
      G_CNT_ERROR_MAX      : NATURAL := 40
   );
   PORT (
      -- Clock and reset
      arst_i               : IN  STD_LOGIC;
      clk_i                : IN  STD_LOGIC;
      -- valid input tick
      valid_i              : IN  STD_LOGIC;
      -- error input
      fault_i              : IN  STD_LOGIC;
      -- fault output
      fault_o              : OUT STD_LOGIC
   );
END ENTITY error_counter_filter;


ARCHITECTURE beh OF error_counter_filter IS

   --------------------------------------------------------
   -- COMPONENTS
   --------------------------------------------------------

   COMPONENT edge_detector IS
   GENERIC (
      G_EDGEPOLARITY:  STD_LOGIC := '1'
   );
   PORT (
      arst_i   : IN  STD_LOGIC;
      clk_i    : IN  STD_LOGIC;
      valid_i  : IN  STD_LOGIC;
      data_i   : IN  STD_LOGIC;
      edge_o   : OUT STD_LOGIC
   );
   END COMPONENT edge_detector;

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------

   SIGNAL counter_r              : UNSIGNED(5 DOWNTO 0);
   SIGNAL fault_r                : STD_LOGIC;

   SIGNAL counter_zero_s         : STD_LOGIC;
   SIGNAL counter_max_s          : STD_LOGIC;
   SIGNAL rise_valid_event_s     : STD_LOGIC;

BEGIN
   -- REQ: 202 and REQ: 201;
   -- [CCN04] : counter_max_s changed from 16 to 40.
   -- [CCN05] : counter_max_s changed from 40 to 60 for "analog input" errors
   --       but counter_max_s stayed 40 Power Supply Monitoring, hence the
   --       introduction for the generic G_CNT_ERROR_MAX value
   -- NOTE: Value 60 represents 30 seconds. Value 40 represents 20 seconds.

   counter_zero_s <= '1' WHEN counter_r="000000" ELSE '0';                     -- Minimum counter value
   counter_max_s  <= '1' WHEN counter_r=TO_UNSIGNED(G_CNT_ERROR_MAX,6) ELSE    -- Maximum counter value
                     '0';


   edge_detector_i1: edge_detector                                -- Check new valid input
   GENERIC MAP (
      G_EDGEPOLARITY => '1'
   ) PORT MAP (
      arst_i   => arst_i,
      clk_i    => clk_i,
      valid_i  => '1',
      data_i   => valid_i,
      edge_o   => rise_valid_event_s
   );

   p_fault: PROCESS(arst_i,clk_i)                                 -- Process a fault if we have too many error counts
   BEGIN
      IF (arst_i = '1') THEN
         counter_r <= (OTHERS =>'0');
         fault_r   <= '0';
      ELSIF RISING_EDGE(clk_i) THEN

         IF (counter_max_s = '1') THEN
            fault_r <= '1';                                       -- If we reached max counter, flag a permanent fault
         ELSIF (rise_valid_event_s = '1') THEN                    -- tick event
            IF (fault_i = '1') THEN
                  counter_r <= counter_r + 1;
            ELSIF (counter_zero_s = '0') THEN
               counter_r <= counter_r - 1;
            END IF;
         END IF;
      END IF;
   END PROCESS p_fault;


   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------

   fault_o <= fault_r;

END beh;
