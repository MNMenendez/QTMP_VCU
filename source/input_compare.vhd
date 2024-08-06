---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : input_compare.vhd
-- Module      : input_compare
-- Revision    : 1.5
-- Date/Time   : January 10, 2020
-- Author      : Alvaro Lopes, NRibeiro
---------------------------------------------------------------
-- Description : Input Compare
---------------------------------------------------------------
-- History :
-- Revision 1.5 - January 10, 2020
--    - NRibeiro: improving code for code coverage
-- Revision 1.4 - April 23, 2019
--    - ALopes: Fix Req 26 implementation
-- Revision 1.3 - March 03, 2019
--    - ALopes: Requirement changes from CCN03
-- Revision 1.2 - March 07, 2018
--    - ALopes: Rework according to review
-- Revision 1.1 - February 27, 2018
--    - ALopes: Added traceability to requirements version 0.29.
-- Revision 1.0 - January 17, 2018
--    - ALopes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY input_compare IS
   PORT (
      -- Clock and reset
      arst_i               : IN  STD_LOGIC;
      clk_i                : IN  STD_LOGIC;
      -- Selftest "tick"
      selftest_done_i      : IN  STD_LOGIC; -- One tick per channel.
      -- Channel inputs
      input_ch1_i          : IN  STD_LOGIC;
      input_ch2_i          : IN  STD_LOGIC;
      -- Input masks from self-test
      st_mask_ch1_i        : IN  STD_LOGIC;
      st_mask_ch2_i        : IN  STD_LOGIC;
      -- Input validity
      input_valid_i        : IN STD_LOGIC;
      -- Output masks
      mask_ch1_o           : OUT STD_LOGIC;
      mask_ch2_o           : OUT STD_LOGIC;
      -- Output data
      data_o               : OUT STD_LOGIC
   );
END ENTITY input_compare;

ARCHITECTURE beh OF input_compare IS

   --------------------------------------------------------
   -- CONSTANTS
   --------------------------------------------------------

   CONSTANT C_DELAY_MAX: INTEGER := 10;  -- Up to 5 seconds in 500ms ticks (5/0.5 = 10)

   --------------------------------------------------------
   -- LOCAL TYPES
   --------------------------------------------------------

   TYPE state_TYP IS (
      NORMAL,
      DELAY_CHECK,
      FAILURE
   );

   --------------------------------------------------------
   -- REGISTERS
   --------------------------------------------------------

   SIGNAL data_r              : STD_LOGIC;
   SIGNAL mask_ch1_r          : STD_LOGIC;
   SIGNAL mask_ch2_r          : STD_LOGIC;
   SIGNAL previous_mismatch_r : STD_LOGIC;
   SIGNAL delay_r             : INTEGER RANGE 0 TO C_DELAY_MAX-1;
   SIGNAL state_r             : state_TYP;

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------

   SIGNAL imask_s             : STD_LOGIC_VECTOR(1 DOWNTO 0);

BEGIN

   imask_s <= st_mask_ch1_i & st_mask_ch2_i;

   p_compare: PROCESS(arst_i, clk_i)
   BEGIN
      IF arst_i='1' THEN

         data_r               <= '0';
         state_r              <= NORMAL;
         delay_r              <= 0;
         mask_ch2_r           <= '0';
         mask_ch1_r           <= '0';
         previous_mismatch_r  <= '0'; -- REQ: 26
      ELSIF RISING_EDGE(clk_i) THEN

         CASE state_r IS
            WHEN NORMAL =>
               IF (input_valid_i = '1') THEN                          -- REQ: 20
                  previous_mismatch_r  <= '0';                        -- REQ: 26_21
                  CASE (imask_s) IS
                     WHEN "00" =>                                     -- REQ: 18
                        IF (input_ch1_i /= input_ch2_i) THEN          -- REQ: 11
                           -- REQ START: 26
                           previous_mismatch_r  <= '1';
                           IF (previous_mismatch_r = '1') THEN
                              state_r  <= DELAY_CHECK;                -- REQ: 22
                              delay_r  <= C_DELAY_MAX-1;              -- REQ: 22
                           END IF;
                           -- REQ END: 26
                        ELSE
                           -- Update output.
                           data_r   <= input_ch1_i;
                        END IF;

                     WHEN "01" =>                                    -- REQ: 19
                        -- CH2 masked
                        mask_ch2_r  <= '1';
                        data_r      <= input_ch1_i;

                     WHEN "10" =>                                   -- REQ: 19
                        -- CH1 masked
                        mask_ch1_r  <= '1';
                        data_r      <= input_ch2_i;
                     WHEN OTHERS =>                                 -- REQ: 19
                        -- Both signal masked by selftest.
                        state_r     <= FAILURE;
                        data_r      <= '0';
                        mask_ch2_r  <= '1';
                        mask_ch1_r  <= '1';
                  END CASE;
               END IF;

            WHEN DELAY_CHECK =>
               IF (input_valid_i = '1') THEN                      -- REQ: 20
                  CASE (imask_s) IS
                     WHEN "00" =>                                 -- REQ: 18
                        IF (selftest_done_i = '1') THEN
                           IF (input_ch1_i /= input_ch2_i) THEN   -- REQ: 22
                              IF (delay_r /= 0) THEN
                                 delay_r <= delay_r - 1;          -- REQ: 22
                              ELSE
                                 -- Delay expited, mask
                                 state_r     <= FAILURE;          -- REQ: 22
                                 data_r      <= '0';
                                 mask_ch2_r  <= '1';
                                 mask_ch1_r  <= '1';
                              END IF;
                           ELSE
                              -- Inputs match now, update outputs
                              state_r        <= NORMAL;
                              data_r         <= input_ch1_i;
                           END IF;
                        END IF;
                     WHEN "01" =>                                 -- REQ: 19
                        -- CH2 masked
                        mask_ch2_r  <= '1';
                        data_r      <= input_ch1_i;
                        state_r     <= NORMAL;

                     WHEN "10" =>                                 -- REQ: 19
                        -- CH1 masked
                        mask_ch1_r  <= '1';
                        data_r      <= input_ch2_i;
                        state_r     <= NORMAL;

                     WHEN OTHERS =>                               -- REQ: 19
                        -- Both signal masked by selftest.
                        state_r     <= FAILURE;
                        data_r      <= '0';
                        mask_ch2_r  <= '1';
                        mask_ch1_r  <= '1';
                   END CASE;
               END IF;

            --Commented for improving code coverage
            --WHEN FAILURE =>                                     -- Failure in both channels
            --   mask_ch2_r <= '1';
            --   mask_ch1_r <= '1';

            WHEN OTHERS =>                                        -- Failure in both channels
               mask_ch2_r <= '1';
               mask_ch1_r <= '1';
               state_r <= FAILURE;

         END CASE;
      END IF;
   END PROCESS p_compare;

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------

   mask_ch1_o  <= mask_ch1_r;
   mask_ch2_o  <= mask_ch2_r;
   data_o      <= data_r;

END beh;
