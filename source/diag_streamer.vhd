---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : diag_streamer.vhd
-- Module      : diag_streamer
-- Revision    : 1.1
-- Date/Time   : March 07, 2018
-- Author      : Alvaro Lopes
---------------------------------------------------------------
-- Description : LED Streamer
---------------------------------------------------------------
-- History :
-- Revision 1.1 - March 07, 2018
--    - ALopes: Rework according to review
-- Revision 1.0 - February 07, 2018
--    - ALopes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY diag_streamer IS
   PORT (
      -- Clock and reset
      arst_i:        IN  STD_LOGIC;
      clk_i:         IN  STD_LOGIC;
      -- Pulse tick - twice display clock
      pulse_i:       IN  STD_LOGIC; 
      -- Data inputs
      data_i:        IN  STD_LOGIC_VECTOR(127 DOWNTO 0);
      -- Diagnosic outputs
      diag_clk_o:    OUT STD_LOGIC;
      diag_data_o:   OUT STD_LOGIC;
      diag_strobe_o: OUT STD_LOGIC
   );

END ENTITY diag_streamer;

ARCHITECTURE beh OF diag_streamer IS

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------

   SIGNAL diag_data_r   : STD_LOGIC;
   SIGNAL diag_strobe_r : STD_LOGIC;
   SIGNAL cnt_r         : UNSIGNED(7 DOWNTO 0);
   SIGNAL datasel_s     : STD_LOGIC;

BEGIN


   -- Select correct input according to the stream counter.
   p_datasel: PROCESS(cnt_r, data_i)
      VARIABLE cnt_div_v: UNSIGNED(6 DOWNTO 0); -- 0-127.
      VARIABLE sel_v: NATURAL RANGE 0 TO 127;
   BEGIN
      cnt_div_v := cnt_r(7 DOWNTO 1);
      sel_v := TO_INTEGER(cnt_div_v);
      datasel_s <= data_i(sel_v);
   END PROCESS p_datasel;

   -- Generate data and strobe signals
   p_dataout: PROCESS(arst_i, clk_i)
   BEGIN
      IF (arst_i = '1') THEN
         cnt_r <= (OTHERS=>'0');
         diag_strobe_r <= '0';
         diag_data_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         IF (pulse_i = '1') THEN
            cnt_r <= cnt_r + 1;

            -- Output data synchronous to clock (which is bit 0)
            IF (cnt_r(0) = '0') THEN
               diag_data_r <= datasel_s;
            END IF;

            -- Strobe signal is at start of stream
            IF (cnt_r (7 DOWNTO 1) = "0000000") THEN   -- REQ: 72
               diag_strobe_r <= '1';
            ELSE
               diag_strobe_r <= '0';
            END IF;

         END IF;
      END IF;
   END PROCESS p_dataout;

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------

   diag_clk_o     <= cnt_r(0);                      -- REQ: 70
   diag_strobe_o  <= diag_strobe_r;                 -- REQ: 70.02
   diag_data_o    <= diag_data_r;                   -- REQ: 70.01

END beh;
