---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : sig_comp.vhd
-- Module      : Output IF
-- Revision    : 1.3
-- Date/Time   : May 16, 2018
-- Author      : JMonteiro
---------------------------------------------------------------
-- Description : Compare two signals after a given time period
---------------------------------------------------------------
-- History :
-- Revision 1.3 - May 16, 2018
--    - JMonteiro: Applied code review comments for baseline 02.
-- Revision 1.2 - March 05, 2018
--    - JMonteiro: Applied code review comments.
-- Revision 1.1 - February 27, 2018
--    - JMonteiro: Removed implicit 500us counter.
--                 Code adjustmnents
-- Revision 1.0 - February 02, 2018
--    - JMonteiro: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY sig_comp IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Clock/Reset Inputs
      ----------------------------------------------------------------------------
      arst_i         : IN STD_LOGIC;      -- Global (asynch) reset
      clk_i          : IN STD_LOGIC;      -- Global clk

      ----------------------------------------------------------------------------
      --  Timing
      ----------------------------------------------------------------------------
      pulse500us_i   : IN STD_LOGIC;   -- Internal 500us synch pulse

      ----------------------------------------------------------------------------
      --  Control
      ----------------------------------------------------------------------------
      cmp_init_i     : IN STD_LOGIC;

      ----------------------------------------------------------------------------
      --  Input (signals to be compared)
      ----------------------------------------------------------------------------
      cmp_sig1_i     : IN STD_LOGIC;
      cmp_sig2_i     : IN STD_LOGIC;

      ----------------------------------------------------------------------------
      --  Output (compare result)
      ----------------------------------------------------------------------------
      cmp_res_o      : OUT STD_LOGIC

   );
END ENTITY sig_comp;


ARCHITECTURE beh OF sig_comp IS

   --------------------------------------------------------
   -- COMPONENTS
   --------------------------------------------------------
   COMPONENT edge_detector IS
      GENERIC (
         G_EDGEPOLARITY   : STD_LOGIC := '1'
      );
      PORT (
         arst_i         : IN  STD_LOGIC;
         clk_i          : IN  STD_LOGIC;
         valid_i        : IN  STD_LOGIC;
         data_i         : IN  STD_LOGIC;
         edge_o         : OUT STD_LOGIC
      );
   END COMPONENT edge_detector;

   --------------------------------------------------------
   -- CONSTANTS
   --------------------------------------------------------
   CONSTANT C_TMR             : NATURAL  := 8;

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------
   SIGNAL ctr_s      : UNSIGNED(15 DOWNTO 0);
   SIGNAL ctr_r      : UNSIGNED(15 DOWNTO 0);
   SIGNAL ctr_rst_s  : STD_LOGIC;

   SIGNAL cmp_s      : STD_LOGIC;
   SIGNAL cmp_r      : STD_LOGIC;

   SIGNAL eval_s     : STD_LOGIC;

BEGIN

   p_cmp: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         cmp_r <= '1';                                                              -- Assume compare OK before
      ELSIF RISING_EDGE(clk_i) THEN                                                 -- first eval (do not filter).
         IF (eval_s = '1') AND (cmp_init_i = '0') THEN                              -- After compare counter
            cmp_r <= cmp_s;                                                         -- period we need an extra clock to
         END IF;                                                                    -- update the output.
      END IF;
	END PROCESS p_cmp;
   cmp_s <= '1' WHEN (cmp_sig1_i = cmp_sig2_i) ELSE
            '0';

   --------------------------------------------------------
   -- EVAL COUNTER
   --------------------------------------------------------
   p_ctr: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         ctr_r <= (OTHERS => '1');
		ELSIF RISING_EDGE(clk_i) THEN
         IF (ctr_rst_s = '1') THEN
            ctr_r <= (OTHERS => '0');
         ELSIF (pulse500us_i = '1') THEN
            ctr_r <= ctr_s;
         END IF;
      END IF;
	END PROCESS p_ctr;
   ctr_s <= ctr_r + 1       WHEN ctr_r(C_TMR) /= '1' ELSE                               -- 2^C_TMR*500E-6
            ctr_r;
   ctr_rst_s <= cmp_init_i OR ctr_r(C_TMR);

   edge_detector_i0 : edge_detector GENERIC MAP(G_EDGEPOLARITY => '1')
	PORT MAP(arst_i => arst_i, clk_i => clk_i, data_i => ctr_r(C_TMR), edge_o => eval_s, valid_i => '1');

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------
   cmp_res_o <= cmp_r;

END ARCHITECTURE beh;