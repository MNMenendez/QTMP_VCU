---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : input_latch.vhd
-- Module      : input_latch
-- Revision    : 1.1
-- Date/Time   : March 07, 2018
-- Author      : Alvaro Lopes
---------------------------------------------------------------
-- Description : Input Latching module
---------------------------------------------------------------
-- History :
-- Revision 1.1 - March 07, 2018
--    - ALopes: Rework according to review
-- Revision 1.0 - January 24, 2018
--    - ALopes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY input_latch IS
   PORT (
      -- Clock and reset
      arst_i      : IN  STD_LOGIC;
      clk_i       : IN  STD_LOGIC;
      -- Input data
      data_i      : IN  STD_LOGIC;
      -- Data hold request
      hold_i      : IN  STD_LOGIC;
      -- Output data
      data_o      : OUT STD_LOGIC
   );
END ENTITY input_latch;

ARCHITECTURE beh OF input_latch IS

  --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------

   SIGNAL data_r: STD_LOGIC;

BEGIN

   -- Latch input data according to hold request
   p_latch: PROCESS(arst_i,clk_i)
   BEGIN
      IF (arst_i = '1') THEN
         data_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         IF (hold_i = '0') THEN
            data_r <= data_i;
         END IF;
      END IF;
   END PROCESS p_latch;

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------

   data_o <= data_i WHEN (hold_i = '0') ELSE data_r;

END beh;
