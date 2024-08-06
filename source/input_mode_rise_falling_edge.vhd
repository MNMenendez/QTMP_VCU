---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : input_mode_rise_falling_edge.vhd
-- Module      : input_mode_rise_falling_edge
-- Revision    : 1.2
-- Date/Time   : May 16, 2018
-- Author      : Alvaro Lopes
---------------------------------------------------------------
-- Description : Input Mode for Rising+Falling Edge
---------------------------------------------------------------
-- History :
-- Revision 1.2 - May 16, 2018
--    - JMonteiro: Applied code review comments for baseline 02.
-- Revision 1.1 - March 07, 2018
--    - ALopes: Rework according to review
-- Revision 1.0 - January 23, 2018
--    - ALopes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY input_mode_rise_falling_edge IS
   GENERIC (
      -- Number of ticks to wait for falling event
      MAX_COUNT:  NATURAL := 1
   );
   PORT (
      -- Clock and reset
      arst_i         : IN  STD_LOGIC;
      clk_i          : IN  STD_LOGIC;
      -- Timer tick
      tick_i         : IN  STD_LOGIC;
      -- Data input
      data_i         : IN  STD_LOGIC;
      -- Data validity
      valid_i        : IN  STD_LOGIC;
      -- Data inhibit
      inhibit_i      : IN  STD_LOGIC;
      -- Data masks
      mask1_i        : IN  STD_LOGIC;
      mask2_i        : IN  STD_LOGIC;
      -- Clear expired input tick
      expired_clr_i  : IN  STD_LOGIC;
      -- Expired flag output
      expired_o      : OUT STD_LOGIC;
      -- Data output
      data_o         : OUT STD_LOGIC
   );
END ENTITY input_mode_rise_falling_edge;

ARCHITECTURE beh OF input_mode_rise_falling_edge IS

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

   SIGNAL timeout_counter_r         : NATURAL RANGE 0 TO MAX_COUNT;
   SIGNAL hold_event_detected_dly_r : STD_LOGIC;

   SIGNAL expired_r                 : STD_LOGIC;
   SIGNAL masked_s                  : STD_LOGIC;
   SIGNAL data_s                    : STD_LOGIC;
   SIGNAL rise_detected_s           : STD_LOGIC;
   SIGNAL fall_detected_s           : STD_LOGIC;
   SIGNAL timeout_zero_s            : STD_LOGIC;
   SIGNAL hold_event_detected_s     : STD_LOGIC;

BEGIN

   masked_s <= mask1_i AND mask2_i;

   timeout_zero_s <= '1' WHEN (timeout_counter_r = 0) ELSE '0';

   -- Detect hold
   p_hold: PROCESS(arst_i,clk_i)
   BEGIN
      IF arst_i='1' THEN
         hold_event_detected_dly_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         hold_event_detected_dly_r <= hold_event_detected_s;
      END IF;
   END PROCESS p_hold;

   -- Detect if timer expired so we can pass hold along
   p_expire: PROCESS(arst_i,clk_i)
   BEGIN
      IF (arst_i = '1') THEN
         expired_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         IF (expired_clr_i = '1') THEN
            expired_r <= '0';
         ELSE
            IF (hold_event_detected_s = '1' AND hold_event_detected_dly_r = '0') THEN
               expired_r <= '1';
            END IF;
         END IF;
      END IF;
   END PROCESS p_expire;

   hold_event_detected_s <= data_i AND timeout_zero_s AND (NOT rise_detected_s);

   -- Main counter process
   p_cnt: PROCESS(arst_i,clk_i)
   BEGIN
      IF (arst_i = '1') THEN
         timeout_counter_r <= 0;
      ELSIF RISING_EDGE(clk_i) THEN
         IF (rise_detected_s = '1') THEN
            timeout_counter_r <= MAX_COUNT;
         ELSE
            IF (tick_i = '1') THEN
               IF (timeout_zero_s = '0') THEN
                  timeout_counter_r <= timeout_counter_r - 1;
               END IF;
            END IF;
         END IF;
      END IF;
   END PROCESS p_cnt;

   -- Rising edge detector
   edge_detector_i0: edge_detector
   GENERIC MAP (
      G_EDGEPOLARITY   => '1'
   )
   PORT MAP (
      arst_i   => arst_i,
      clk_i    => clk_i,
      valid_i  => valid_i,
      data_i   => data_i,
      edge_o   => rise_detected_s
   );

   -- Falling edge detector
   edge_detector_i1: edge_detector
   GENERIC MAP (
      G_EDGEPOLARITY   => '0'
   )
   PORT MAP (
      arst_i   => arst_i,
      clk_i    => clk_i,
      valid_i  => valid_i,
      data_i   => data_i,
      edge_o   => fall_detected_s
   );

   data_s <= fall_detected_s AND NOT timeout_zero_s;

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------

   data_o      <= data_s WHEN ( masked_s='0' AND inhibit_i='0') ELSE '0';
   expired_o   <= expired_r WHEN ( masked_s='0' AND inhibit_i='0') ELSE '0';

END beh;

