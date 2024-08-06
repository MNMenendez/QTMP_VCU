---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : debouncer.vhd
-- Module      : debouncer
-- Revision    : 1.1
-- Date/Time   : February 06, 2018
-- Author      : Alvaro Lopes
---------------------------------------------------------------
-- Description : Digital Input debouncer (multiple inputs)
---------------------------------------------------------------
-- History :
-- Revision 1.1 - February 06, 2018
--    - ALopes: Rework after review comments
-- Revision 1.0 - January 10, 2018
--    - ALopes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY debouncer IS
   GENERIC (
      G_INPUTWIDTH:          NATURAL := 18;
      G_DEBOUNCECOUNTERMAX:  NATURAL := 8191
   );
   PORT (
      -- Clock and reset inputs
      arst_i    : IN  STD_LOGIC;
      clk_i     : IN  STD_LOGIC;
      -- Clock enable
      clken_i   : IN  STD_LOGIC;
      -- Data inputs
      data_i    : IN  STD_LOGIC_VECTOR(G_INPUTWIDTH-1 DOWNTO 0);
      -- Data outputs
      data_o    : OUT STD_LOGIC_VECTOR(G_INPUTWIDTH-1 DOWNTO 0);
      -- Update tick - set to one when outputs are updated
      update_o  : OUT STD_LOGIC
   );
END ENTITY debouncer;

ARCHITECTURE beh OF debouncer IS

   --------------------------------------------------------
   -- COMPONENTS
   --------------------------------------------------------

   COMPONENT debouncer_single IS
      GENERIC (
         G_DEBOUNCECOUNTERMAX: NATURAL := 8191
      );
      PORT (
         -- Clock and reset inputs
         arst_i   : IN  STD_LOGIC;
         clk_i    : IN  STD_LOGIC;
         -- Clock enable signal
         clken_i  : IN  STD_LOGIC;
         -- Input data
         data_i   : IN  STD_LOGIC;
         -- Output (debounced) data
         data_o   : OUT  STD_LOGIC
      );
   END COMPONENT debouncer_single;

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------

   SIGNAL update_r   : STD_LOGIC;
   SIGNAL data_s     : STD_LOGIC_VECTOR(G_INPUTWIDTH-1 DOWNTO 0);

BEGIN

   -- REQ BEGIN: 24
   debouncer_single_i0: FOR n IN 0 TO G_INPUTWIDTH-1 GENERATE

      debouncer_single_i: debouncer_single
      GENERIC MAP (
         G_DEBOUNCECOUNTERMAX => G_DEBOUNCECOUNTERMAX
      )
      PORT MAP (
         arst_i      => arst_i,
         clk_i       => clk_i,
         clken_i     => clken_i,
         data_i      => data_i(n),
         data_o      => data_s(n)
      );

   END GENERATE;

   -- REQ END: 24

   -- update tick - delayed one clock.

   p_delaytick: PROCESS(arst_i,clk_i)
   BEGIN
      IF arst_i='1' THEN
         update_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         update_r <= clken_i;
      END IF;
   END PROCESS p_delaytick;

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------

   data_o   <= data_s;
   update_o <= update_r;

END beh;
