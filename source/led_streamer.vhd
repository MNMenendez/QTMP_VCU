---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : led_streamer.vhd
-- Module      : led_streamer
-- Revision    : 1.1
-- Date/Time   : March 07, 2018
-- Author      : Alvaro Lopes
---------------------------------------------------------------
-- Description : LED Streamer
---------------------------------------------------------------
-- History :
-- Revision 1.1 - March 07, 2018
--    - ALopes: Rework according to review
-- Revision 1.0 - January 15, 2018
--    - ALopes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY led_streamer IS
   PORT (
      -- Clock and reset
      arst_i         : IN  STD_LOGIC;
      clk_i          : IN  STD_LOGIC;
      -- Display tick - twice output frequency
      pulse_i        : IN  STD_LOGIC;
      -- Red inputs
      red_i          : IN  STD_LOGIC_VECTOR(63 DOWNTO 0);
      -- Green inputs
      green_i        : IN  STD_LOGIC_VECTOR(63 DOWNTO 0);
      -- Display outputs
      disp_clk_o     : OUT STD_LOGIC;
      disp_data_o    : OUT STD_LOGIC;
      disp_strobe_o  : OUT STD_LOGIC;
      disp_oe_o      : OUT STD_LOGIC
   );

END ENTITY led_streamer;

ARCHITECTURE beh OF led_streamer IS

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------

   SIGNAL disp_data_r      : STD_LOGIC;
   SIGNAL disp_strobe_r    : STD_LOGIC;
   SIGNAL disp_oe_r        : STD_LOGIC;
   SIGNAL cnt_r            : UNSIGNED(7 DOWNTO 0);     -- REQ: 76
   SIGNAL datasel_s        : STD_LOGIC;

BEGIN

   -- Select correct color based on index
   p_selcolor: PROCESS(cnt_r, red_i, green_i)
      VARIABLE cnt_div_v: UNSIGNED(5 DOWNTO 0);        -- 0-63.
      VARIABLE sel_v: NATURAL RANGE 0 TO 63;
   BEGIN
      cnt_div_v   := cnt_r(7 DOWNTO 2);
      sel_v       := TO_INTEGER(cnt_div_v);

      IF (cnt_r(1) = '0') THEN                         -- Bit 1 used for color selection
         datasel_s <= red_i(sel_v);
      ELSE
         datasel_s <= green_i(sel_v);
      END IF;

   END PROCESS p_selcolor;

   -- Generate clock, data and strobe signals
   p_output: PROCESS(arst_i, clk_i)
   BEGIN
      IF (arst_i = '1') THEN
         cnt_r          <= (OTHERS=>'0');
         disp_strobe_r  <= '0';
         disp_oe_r      <= '1';                        -- REQ: 183
         disp_data_r    <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         IF (pulse_i = '1') THEN
            disp_oe_r   <='0';                         -- REQ: 183
            cnt_r       <= cnt_r + 1;

            IF (cnt_r(0) = '0') THEN                   -- Output synchronous to rising clock
               disp_data_r    <= datasel_s;            -- Either red or green
            END IF;

            IF (cnt_r(7 DOWNTO 1) = "1111111") THEN    -- REQ: 77
               disp_strobe_r  <= '1';
            ELSE
               disp_strobe_r  <= '0';
            END IF;
         END IF;
      END IF;
   END PROCESS p_output;

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------

   disp_clk_o     <= cnt_r(0);                         -- Clock comes from counter LSB
   disp_strobe_o  <= disp_strobe_r;
   disp_data_o    <= disp_data_r;
   disp_oe_o      <= disp_oe_r;

END beh;
