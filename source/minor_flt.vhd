---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : minor_flt.vhd
-- Module      : Minor Fault
-- Revision    : 1.3
-- Date/Time   : January 30, 2020
-- Author      : JMonteiro, AFernandes, NRibeiro
---------------------------------------------------------------
-- Description : Minor Fault Generation
---------------------------------------------------------------
-- History :
-- Revision 1.3 - January 30, 2020
--    - NRibeiro: Fixing traceability requirements
-- Revision 1.2 - November 29, 2019
--    - NRibeiro: Applied CCN04 code changes
-- Revision 1.1 - July 27, 2018
--    - AFernandes: Applied CCN02 code changes.
-- Revision 1.0 - March 05, 2018
--    - JMonteiro: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.STD_LOGIC_MISC.ALL;


ENTITY minor_flt IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Generic ports
      ----------------------------------------------------------------------------
      arst_i               : IN STD_LOGIC;                        -- Global (asynch) reset
      clk_i                : IN STD_LOGIC;                        -- Global clk

      ----------------------------------------------------------------------------
      --  Fault Inputs
      ----------------------------------------------------------------------------
      input_flt_i          : IN STD_LOGIC;                        -- Input IF Fault
      spd_urng_i           : IN STD_LOGIC;                        -- Analog Speed Under-Range Fault
      spd_orng_i           : IN STD_LOGIC;                        -- Analog Speed Over-Range Fault
      spd_err_i            : IN STD_LOGIC;                        -- Analog Speed value error
      dry_flt_i            : IN STD_LOGIC_VECTOR( 4 DOWNTO 0);    -- Fault on dry outputs
      wet_flt_i            : IN STD_LOGIC_VECTOR(11 DOWNTO 0);    -- Fault on dry outputs

      ----------------------------------------------------------------------------
      --  Minor Fault Output
      ----------------------------------------------------------------------------
      mnr_flt_o            : OUT STD_LOGIC                        -- Minor Fault Out

   );
END ENTITY minor_flt;


ARCHITECTURE beh OF minor_flt IS

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------
   SIGNAL mnr_flt_s  : STD_LOGIC;
   SIGNAL mnr_flt_r  : STD_LOGIC;

BEGIN

   p_mflt: PROCESS(clk_i, arst_i)                                                   -- Persistent fault
   BEGIN
      IF (arst_i = '1') THEN
         mnr_flt_r   <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         IF (mnr_flt_s = '1') THEN
            mnr_flt_r <= '1';
         END IF;
      END IF;
   END PROCESS p_mflt;
   mnr_flt_s   <= input_flt_i             OR                                        -- REQ: 188_36_23_201
                  spd_urng_i              OR                                        -- REQ: 42
                  spd_orng_i              OR                                        -- REQ: 42
                  spd_err_i               OR                                        -- REQ: 43
                  OR_REDUCE(dry_flt_i)    OR                                        -- REQ: 67
                  OR_REDUCE(wet_flt_i);                                             -- REQ: 66

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------
   mnr_flt_o   <= mnr_flt_r;

END ARCHITECTURE beh;