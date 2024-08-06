---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : major_flt.vhd
-- Module      : Major Fault
-- Revision    : 1.4
-- Date/Time   : December 11, 2019
-- Author      : JMonteiro, NRibeiro
---------------------------------------------------------------
-- Description : Major Fault Generation
---------------------------------------------------------------
-- History :
-- Revision 1.4 - December 11, 2019
--    - NRibeiro: Code/Comments cleanup.
-- Revision 1.3 - November 29, 2019
--    - NRibeiro: Applied CCN04 code changes
-- Revision 1.2 - March 08, 2018
--    - JMonteiro: Applied code review comments.
-- Revision 1.1 - February 26, 2018
--    - JMonteiro: Added traceability to requirements version 0.29.
-- Revision 1.0 - February 15, 2018
--    - JMonteiro: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


ENTITY major_flt IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Generic ports
      ----------------------------------------------------------------------------
      arst_i            : IN STD_LOGIC;   -- Global (asynch) reset
      clk_i             : IN STD_LOGIC;   -- Global clk

      ----------------------------------------------------------------------------
      --  Fault Conditions
      ----------------------------------------------------------------------------
      penalty1_flt_i    : IN STD_LOGIC;   -- Penalty Brake 1 Fault
      penalty2_flt_i    : IN STD_LOGIC;   -- Penalty Brake 2 Fault

      ----------------------------------------------------------------------------
      --  Major Fault Output
      ----------------------------------------------------------------------------
      mjr_flt_o         : OUT STD_LOGIC   -- Major Fault Out

   );
END ENTITY major_flt;


ARCHITECTURE beh OF major_flt IS

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------
   SIGNAL mjr_flt_s  : STD_LOGIC;
   SIGNAL mjr_flt_r  : STD_LOGIC;

BEGIN

   p_mflt: PROCESS(clk_i, arst_i)                                                   -- Persistent fault
   BEGIN
      IF (arst_i = '1') THEN
         mjr_flt_r   <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         IF (mjr_flt_s = '1') THEN
            mjr_flt_r <= '1';
         END IF;
      END IF;
   END PROCESS p_mflt;
   mjr_flt_s   <= penalty1_flt_i OR                                                 -- REQ: 103 (OPL#32)
                  penalty2_flt_i;      

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------
   mjr_flt_o   <= mjr_flt_r;

END ARCHITECTURE beh;
