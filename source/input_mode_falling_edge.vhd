---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : input_mode_falling_edge.vhd
-- Module      : input_mode_falling_edge
-- Revision    : 1.2
-- Date/Time   : November 29, 2019
-- Author      : Alvaro Lopes, NRibeiro
---------------------------------------------------------------
-- Description : Input Mode for Falling Edge
---------------------------------------------------------------
-- History :
-- Revision 1.2 - November 29, 2019
--    - NRibeiro: Valid input port was missing from edge_detector
-- Revision 1.1 - March 07, 2018
--    - ALopes: Rework according to review
-- Revision 1.0 - January 22, 2018
--    - ALopes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY input_mode_falling_edge IS
   PORT (
      -- Clock and reset
      arst_i      : IN  STD_LOGIC;
      clk_i       : IN  STD_LOGIC;
      -- Data input
      data_i      : IN  STD_LOGIC;
      -- Data mask inputs
      mask1_i     : IN  STD_LOGIC;
      mask2_i     : IN  STD_LOGIC;
      -- Data output
      data_o      : OUT STD_LOGIC
      );
END ENTITY input_mode_falling_edge;

ARCHITECTURE beh OF input_mode_falling_edge IS

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
   -- SIGNALS
   --------------------------------------------------------

   SIGNAL masked_s   : STD_LOGIC;
   SIGNAL data_s     : STD_LOGIC;

BEGIN

   masked_s <= mask1_i AND mask2_i;

   edge_detector_u0: edge_detector
   GENERIC MAP (
      G_EDGEPOLARITY   => '0'
   )
   PORT MAP (
      arst_i   => arst_i,
      clk_i    => clk_i,
      valid_i  => '1',
      data_i   => data_i,
      edge_o   => data_s
   );

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------

   data_o <= data_s WHEN masked_s='0' ELSE '0';

END beh;

