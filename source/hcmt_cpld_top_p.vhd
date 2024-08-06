---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : hcmt_cpld_top_p.vhd
-- Module      : hcmt_cpld_top
-- Revision    : 1.1
-- Date/Time   : March 09, 2018
-- Author      : JMonteiro, ALopes
---------------------------------------------------------------
-- Description : Top level package of the HCMT CPLD.
---------------------------------------------------------------
-- History :
-- Revision 1.1 - March 09, 2018
--    - JMonteiro: Applied code review comments.
-- Revision 1.0 - January 17, 2018
--    - JMonteiro: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


PACKAGE hcmt_cpld_top_p IS

      -- For correct implementation, use 0. For simulation, use 5.
 
      CONSTANT C_ART_TEST : BOOLEAN := FALSE;
      
      CONSTANT C_CLK_DERATE_BITS: NATURAL := 0;

      CONSTANT C_CLK_FREQ : REAL := 16384.0/(2.0**C_CLK_DERATE_BITS); -- KHz

      FUNCTION reverse_bits(I: IN STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;


END hcmt_cpld_top_p;


PACKAGE BODY hcmt_cpld_top_p IS

   -- Invert order of bits for a given input vector
   FUNCTION reverse_bits(I: IN STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
      VARIABLE r_v: STD_LOGIC_VECTOR(I'RANGE);

   BEGIN
      l_u0: FOR N IN I'LOW TO I'HIGH LOOP
         r_v(N) := I(I'HIGH+I'LOW-N);
      END LOOP l_u0;
      RETURN r_v;
   END FUNCTION reverse_bits;


END hcmt_cpld_top_p;

