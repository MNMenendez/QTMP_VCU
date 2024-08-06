---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : edge_detector.vhd
-- Module      : edge_detector
-- Revision    : 1.1
-- Date/Time   : March 07, 2018
-- Author      : Alvaro Lopes
---------------------------------------------------------------
-- Description : Edge Detector
---------------------------------------------------------------
-- History :
-- Revision 1.1 - March 07, 2018
--    - ALopes: Rework according to review
-- Revision 1.0 - January 10, 2018
--    - ALopes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY edge_detector IS
   GENERIC (
      G_EDGEPOLARITY:  STD_LOGIC := '1'
   );
   PORT (
      -- Clock inputs
      arst_i   : IN  STD_LOGIC;
      clk_i    : IN  STD_LOGIC;
      -- Data in valid
      valid_i  : IN  STD_LOGIC;
      -- Data input
      data_i   : IN  STD_LOGIC;
      -- Data output
      edge_o   : OUT STD_LOGIC
   );
END ENTITY edge_detector;

ARCHITECTURE beh OF edge_detector IS

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------

   SIGNAL d_r: STD_LOGIC;

BEGIN

   p_capture: PROCESS(arst_i,clk_i)
   BEGIN
      IF (arst_i='1') THEN
         d_r <= G_EDGEPOLARITY;
      ELSIF RISING_EDGE(clk_i) THEN
         IF (valid_i='1') THEN
            d_r <= data_i;
         END IF;
      END IF;
   END PROCESS p_capture;

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------

   edge_o <= '1' WHEN (d_r = NOT G_EDGEPOLARITY) AND (data_i = G_EDGEPOLARITY AND valid_i = '1') ELSE '0';

END beh;
