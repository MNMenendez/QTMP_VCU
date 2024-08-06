---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : input_selftest.vhd
-- Module      : input_selftest
-- Revision    : 1.5
-- Date/Time   : February 04, 2020
-- Author      : Alvaro Lopes, AFernades, NRibeiro
---------------------------------------------------------------
-- Description : Input Self Test
---------------------------------------------------------------
-- History :
-- Revision 1.5 - February 04, 2020
--    - NRibeiro: Code coverage improvements.
-- Revision 1.4 - November 29, 2019
--    - NRibeiro: Applied CCN04 code changes.
-- Revision 1.3 - March 29, 2019
--    - AFernandes: Applied CCN03 code changes.
-- Revision 1.2 - March 07, 2018
--    - ALopes: Rework according to review.
-- Revision 1.1 - February 27, 2018
--    - ALopes: Added traceability to requirements version 0.29.
-- Revision 1.0 - January 12, 2018
--    - ALopes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY input_selftest IS
   PORT (
      -- Clock and reset
      arst_i                  : IN  STD_LOGIC;
      clk_i                   : IN  STD_LOGIC;
      -- Pulse ticks
      pulse500us_i            : IN  STD_LOGIC;
      pulse500ms_i            : IN  STD_LOGIC;
      -- Input channel data
      input_ch1_i             : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
      input_ch2_i             : IN  STD_LOGIC_VECTOR(8 DOWNTO 0);
      -- Force fail inputs
      force_fault_ch1_i       : IN  STD_LOGIC;
      force_fault_ch2_i       : IN  STD_LOGIC;
      -- Test mode outputs
      ch1_test_high_3v_o      : OUT STD_LOGIC;
      ch1_test_low_3v_o       : OUT STD_LOGIC;
      ch2_test_high_3v_o      : OUT STD_LOGIC;
      ch2_test_low_3v_o       : OUT STD_LOGIC;
      -- Status outputs
      selftest_in_progress_o  : OUT STD_LOGIC;
      chan_selftest_done_o    : OUT STD_LOGIC; -- One tick only per channel
      -- Fault outputs
      fault_ch1_o             : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
      fault_ch2_o             : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
      fault_o                 : OUT STD_LOGIC
   );
END ENTITY input_selftest;


ARCHITECTURE beh OF input_selftest IS

   --------------------------------------------------------
   -- LOCAL TYPES
   --------------------------------------------------------

   TYPE state_TYP is (
      STATE_IDLE,
      STATE_WAITSYNC,
      STATE_DRIVE_HIGH,
      STATE_DELAY_HIGH,
      STATE_CHECK_HIGH,
      STATE_DRIVE_LOW,
      STATE_DELAY_LOW,
      STATE_CHECK_LOW,
      STATE_DELAY_SETTLE1,
      STATE_DELAY_SETTLE2
   );

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------

   SIGNAL testchan_r             : STD_LOGIC;
   SIGNAL state_r                : state_TYP;
   SIGNAL fault_r                : STD_LOGIC;
   SIGNAL fault_ch1_r            : STD_LOGIC_VECTOR(13 DOWNTO 0);
   SIGNAL fault_ch2_r            : STD_LOGIC_VECTOR(8 DOWNTO 0);
   SIGNAL ch1_test_high_3v_r     : STD_LOGIC;
   SIGNAL ch2_test_high_3v_r     : STD_LOGIC;
   SIGNAL ch1_test_low_3v_r      : STD_LOGIC;
   SIGNAL ch2_test_low_3v_r      : STD_LOGIC;
   SIGNAL selftest_in_progress_r : STD_LOGIC;
   SIGNAL chan_selftest_done_r   : STD_LOGIC;

   attribute syn_encoding : string;
   attribute syn_encoding of state_TYP : type is "johnson, safe";

BEGIN

   -- REQ START: 13

   p_selftest: PROCESS(clk_i, arst_i)
   BEGIN
      IF arst_i='1' THEN

         state_r                 <= STATE_IDLE;
         testchan_r              <= '1'; -- Inverted at first IDLE transition.
         ch1_test_high_3v_r      <= '0';
         ch2_test_high_3v_r      <= '0';
         ch1_test_low_3v_r       <= '0';  -- REQ: 14
         ch2_test_low_3v_r       <= '0';  -- REQ: 14
         selftest_in_progress_r  <= '0';
         chan_selftest_done_r    <= '0';
         fault_ch1_r             <= (OTHERS=>'0');
         fault_ch2_r             <= (OTHERS=>'0');

      ELSIF RISING_EDGE(clk_i) THEN

         chan_selftest_done_r <= '0';

         CASE state_r IS
         
            -- WHEN STATE_IDLE =>            -- STATE_IDLE state is now included in the "WHEN OTHERS =>" clause

            WHEN STATE_WAITSYNC =>
               IF (pulse500us_i = '1') THEN
                  -- Start selftest
                  selftest_in_progress_r <= '1';
                  state_r     <= STATE_DRIVE_HIGH;
               END IF;

            WHEN STATE_DRIVE_HIGH =>  -- REQ: 48
               -- Drive HIGH according to channel.
               IF (testchan_r = '1') THEN
                  ch2_test_high_3v_r <= '1'; -- REQ: 14
               ELSE
                  ch1_test_high_3v_r <= '1'; -- REQ: 14
               END IF;

               IF (pulse500us_i = '1') THEN
                  state_r     <= STATE_DELAY_HIGH;
               END IF;

            WHEN STATE_DELAY_HIGH =>
               -- Wait for extra 500us to settle signals and pass debouncer
               IF (pulse500us_i = '1') THEN
                  state_r     <= STATE_CHECK_HIGH;
               END IF;

            WHEN STATE_CHECK_HIGH =>
               -- Check for high fault in any line on the corresponding channel

               -- REQ START: 49
               IF (testchan_r = '0') THEN
                  -- Ch1
                  EvalCh1High: FOR n IN input_ch1_i'RIGHT to input_ch1_i'LEFT LOOP
                     IF (input_ch1_i(N) = '0') THEN
                        fault_ch1_r(N) <= '1';
                     END IF;
                  END LOOP;
               ELSE
                  -- Ch2
                  EvalCh2High: FOR n IN input_ch2_i'RIGHT to input_ch2_i'LEFT LOOP
                     IF (input_ch2_i(N) = '0') THEN
                        fault_ch2_r(N) <= '1';
                     END IF;
                  END LOOP;
               END IF;
               -- REQ END: 49

               state_r <= STATE_DRIVE_LOW;

            WHEN STATE_DRIVE_LOW =>  -- REQ: 48
               -- Drive LOW (HIGH is already driven) for the corresponding channel
               IF (testchan_r = '1') THEN
                  ch2_test_low_3v_r <= '1'; -- REQ: 15
               ELSE
                  ch1_test_low_3v_r <= '1'; -- REQ: 15
               END IF;

               IF (pulse500us_i = '1') THEN
                  state_r     <= STATE_DELAY_LOW;
               END IF;

            WHEN STATE_DELAY_LOW =>
               -- Wait for extra 500us to settle signals and pass debouncer
               IF (pulse500us_i = '1') THEN
                  state_r     <= STATE_CHECK_LOW;
               END IF;

            WHEN STATE_CHECK_LOW =>
               -- Check for low fault in any line on the corresponding channel
               -- REQ START: 55
               IF (testchan_r = '0') THEN
                  -- Ch1
                  EvalCh1Low: FOR n IN input_ch1_i'RIGHT to input_ch1_i'LEFT LOOP
                     IF (input_ch1_i(N) = '1') THEN
                        fault_ch1_r(N) <= '1';
                     END IF;
                  END LOOP;
               ELSE
                  -- Ch2
                  EvalCh2Low: FOR n IN input_ch2_i'RIGHT to input_ch2_i'LEFT LOOP
                     IF (input_ch2_i(N) = '1') THEN
                        fault_ch2_r(N) <= '1';
                     END IF;
                  END LOOP;
               END IF;
               -- REQ END: 55

               -- Clear all test outputs
               ch1_test_high_3v_r <= '0';
               ch2_test_high_3v_r <= '0';

               state_r <= STATE_DELAY_SETTLE1;

            WHEN STATE_DELAY_SETTLE1 =>
               -- Wait for signal to propagate
               IF (pulse500us_i = '1') THEN
                  state_r <= STATE_DELAY_SETTLE2;
               END IF;

            WHEN STATE_DELAY_SETTLE2 =>
               -- Wait for signal to also pass debouncer
               IF (pulse500us_i = '1') THEN
                  chan_selftest_done_r   <= '1';   --REQ: 190.
                  selftest_in_progress_r <= '0';
                  state_r <= STATE_IDLE;
               END IF;

               ch1_test_low_3v_r <= '0';           -- REQ: 190.
               ch2_test_low_3v_r <= '0';           -- REQ: 190.

            WHEN OTHERS =>                         -- Includes STATE_IDLE state
               IF (pulse500ms_i = '1') THEN
                  state_r     <= STATE_WAITSYNC;
                  testchan_r  <= NOT testchan_r;   -- Alternate testing between CH1 and CH2
               END IF;                                            
               
         END CASE;

         -- REQ START: 176
         IF (force_fault_ch1_i = '1') THEN
            -- Force Channel 1 fault
            fault_ch1_r <= (OTHERS => '1');
         END IF;
         IF (force_fault_ch2_i = '1') THEN
            -- Force Channel 2 fault
            fault_ch2_r <= (OTHERS => '1');
         END IF;
         -- REQ END: 176

      END IF;
   END PROCESS p_selftest;

   -- REQ END: 13

   -- Synchronous fault output
   p_faultgen: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         fault_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         IF ( fault_ch1_r/="00000000000000" OR fault_ch2_r/="000000000" ) THEN --!
            fault_r <= '1';
         END IF;
      END IF;
   END PROCESS p_faultgen;

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------

   fault_o                 <= fault_r;       -- REQ: 16
   fault_ch1_o             <= fault_ch1_r;   -- REQ: 16
   fault_ch2_o             <= fault_ch2_r;   -- REQ: 16

   ch1_test_high_3v_o      <= ch1_test_high_3v_r;
   ch2_test_high_3v_o      <= ch2_test_high_3v_r;
   ch1_test_low_3v_o       <= ch1_test_low_3v_r;
   ch2_test_low_3v_o       <= ch2_test_low_3v_r;
   selftest_in_progress_o  <= selftest_in_progress_r;
   chan_selftest_done_o    <= chan_selftest_done_r;

END beh;




